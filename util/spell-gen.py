#!/usr/bin/env python3

# Copyright 2020 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

# Simplified version of occamygen.py https://github.com/pulp-platform/snitch/blob/master/util/occamygen.py
#
# spell-gen.py — Mage/Rogue CGRA spell scaffold generator
#
# Reads an HJSON hardware configuration file and renders one or more Mako
# templates into the target directory. The typical usage is to generate two
# files per kernel:
#
#   1. spell.py      — user-facing configuration script (the "spell").
#                      The user fills in the actual PE operations, routing
#                      choices, AGU addresses, etc., then runs it to produce
#                      spell.c.
#   2. MageSpellBuilder.py — the builder class that matches the exact hardware
#                      parameters encoded in the HJSON config (PEA size, number
#                      of streams, bitwidths, etc.).
#
# The templates use Mako syntax (${expr}, %if, %for, ...) and receive all
# hardware parameters as keyword arguments derived directly from the HJSON file.

import argparse
import hjson
import pathlib
import sys
import re
import logging
from subprocess import run
import csv
from jsonref import JsonRef
from mako.template import Template
import collections
from math import log2
import math

# Trim trailing whitespace from every rendered line so output files are clean.
re_trailws = re.compile(r'[ \t\r]+$', re.MULTILINE)

def string2int(hex_json_string):
    """Parse a hex string of the form '0x...' coming from HJSON."""
    return (hex_json_string.split('x')[1]).split(',')[0]

def write_template(tpl_path, outdir, outfile, **kwargs):
    """Render a single Mako template file and write the result to disk.

    Args:
        tpl_path: Path to the .tpl file.
        outdir:   Directory where the output file is written.
        outfile:  Explicit output path; if None, the template basename
                  (without the .tpl suffix) is used inside outdir.
        **kwargs: Template variables forwarded verbatim to Mako.
    """
    if tpl_path:
        tpl_path = pathlib.Path(tpl_path).absolute()
        if tpl_path.exists():
            tpl = Template(filename=str(tpl_path))
            if outfile == None:
                filename = outdir / tpl_path.with_suffix("").name
            else:
                filename = outfile
            with open(filename, "w") as file:
                code = tpl.render_unicode(**kwargs)
                code = re_trailws.sub("", code)
                file.write(code)
        else:
            raise FileNotFoundError

def main():

    # Placement arrays (documented here for reference; actual values come from
    # the HJSON config file and are forwarded to the templates as kwargs):
    #
    # in_stream_dma_ch_placement  [N_IN_STREAM][N_DMA_CH_PER_IN_STREAM]
    #   Which DMA channels feed each input FIFO.
    #   e.g. [[0], [1], [2], [3]] → FIFO_0 ← DMA_ch0, FIFO_1 ← DMA_ch1, …
    #
    # out_stream_pea_dout_placement  [N_OUT_STREAM][N_PEA_DOUT_PER_OUT_STREAM]
    #   Which PEA column outputs feed each output DMA channel.
    #   e.g. [[0,1],[0,1],[2,3],[2,3]]
    #
    # pea_in_stream_placement  [N_PEA_COL][N_PE_IN_STREAM]
    #   Which DMA channel indices are routed to each PEA column's stream inputs.
    #   e.g. [[0,1],[1,0],[2,3],[3,2]]
    #
    # pea_in_mem_placement  [N_PEA_COL][N_IN_MEM]
    #   (DAE mode) Which memory bank indices are routed to each PEA column.
    #   e.g. [[0,1,4,5],[0,1,4,5],[2,3,6,7],[2,3,6,7]]

    parser = argparse.ArgumentParser(prog="spell-gen")
    
    parser.add_argument("--config",
                        metavar="file",
                        type=str,
                        required=False,
                        help="X-Heep general configuration")

    parser.add_argument("--outdir",
                        "-of",
                        type=pathlib.Path,
                        required=True,
                        help="Target directory where generated files are written.")

    parser.add_argument("--outfile",
                        "-o",
                        type=pathlib.Path,
                        required=False,
                        help="Explicit output filename. If omitted, the template "
                             "basename (without .tpl) is used inside --outdir.")

    parser.add_argument("--num_words",
                        metavar="",
                        nargs='?',
                        default="1024",
                        help="Number of words in the internal memory (unused, "
                             "superseded by the HJSON value).")

    parser.add_argument("--pkg-sv",
                        metavar="PKG_SV",
                        help="(unused) Name of top-level SystemVerilog package file.")

    parser.add_argument("--tpl-sv",
                        metavar="TPL_SV",
                        help="Path to the Mako template file to render "
                             "(e.g. spell.py.tpl or MageSpellBuilder.py.tpl).")

    parser.add_argument(
        "--mage_cfg",
        "-c",
        metavar="FILE",
        type=argparse.FileType("r"),
        required=True,
        help="HJSON hardware configuration file (config/dae/ or config/streaming/).",
    )

    args = parser.parse_args()

    if not args.outdir.is_dir():
            exit("Out directory is not a valid path.")

    outdir = args.outdir
    outdir.mkdir(parents=True, exist_ok=True)

    outfile = args.outfile

    # Load the HJSON config. JsonRef.replace_refs resolves any $ref cross-references
    # inside the file so the resulting dict is fully expanded.
    with args.mage_cfg as f:
        try:
            cfg = hjson.load(f, use_decimal=True)
            cfg = JsonRef.replace_refs(cfg)
        except ValueError as exc:
            raise SystemExit(sys.exc_info()[1]) from exc

    # Fail with a clear message rather than a raw KeyError — don't guess a
    # default, since has_delay_pe changes the PE config word's bit layout.
    if 'has_delay_pe' not in cfg:
        raise SystemExit(
            f"{args.mage_cfg.name}: missing top-level 'has_delay_pe' field.")

    # dae_params/streaming_params are only meaningful for their own mode: a DAE
    # config need not carry streaming_params, and vice versa. Read both via
    # .get() with defaults, matching util/mage-gen.py's own handling.
    dae_params = cfg.get('dae_params', {})
    streaming_params = cfg.get('streaming_params', {})

    # Build the keyword-argument dict that is forwarded verbatim to the Mako
    # templates. Every template variable must appear here.
    #
    # Top-level mode flags:
    #   dae_cgra          — 1 for Mage (Decoupled Access-Execute), 0 for Rogue
    #   streaming_cgra    — 1 for Rogue (streaming DMA), 0 for Mage
    #   format_full       — 1: PE config word has no per-PE vecMode bits (global)
    #   format_part       — 1: PE config word carries a 2-bit per-PE vecMode field
    #   gemm_computation  — 1: PEA ISA variant tuned for GEMM (MUL-ACC heavy)
    #   activation_computation — 1: PEA ISA with activation functions + delay ops
    kwargs = {
        # ---- Mode flags ----
        "dae_cgra"                         : cfg['dae_cgra'],
        "streaming_cgra"                   : cfg['streaming_cgra'],

        "format_full"                      : cfg['format_full'],
        "format_part"                      : cfg['format_part'],

        "gemm_computation"                 : cfg['gemm_computation'],
        "activation_computation"           : cfg['activation_computation'],
        # has_delay_pe: 1 if PEs expose a delay-operand input (delayOpSel field
        # in the PE config word); gates the delay-operand builder methods.
        "has_delay_pe"                     : cfg['has_delay_pe'],

        # ---- PEA (Processing Element Array) geometry ----
        "n_pea_rows"                       : cfg['common_params']['n_pea_rows'],
        "n_pea_cols"                       : cfg['common_params']['n_pea_cols'],
        # n_neigh_pe: number of neighbours each PE can read from (UP/LEFT/RIGHT/DOWN)
        "n_neigh_pe"                       : cfg['common_params']['n_neigh_pe'],
        "pattern_neigh_pe"                 : cfg['common_params']['pattern_neigh_pe'],

        # ---- DAE-specific parameters (Mage) ----
        # kernel_len: number of time steps in a multi-kernel schedule (1 = single)
        "kernel_len"                       : cfg['common_params']['kernel_len'],
        # n_pe_in_mem: how many memory bank data buses feed each PEA column
        "n_pe_in_mem"                      : dae_params.get('n_pe_in_mem', 0),
        # pea_in_mem_placement: [n_pea_cols][n_pe_in_mem] routing matrix
        "pea_in_mem_placement"             : dae_params.get('pea_in_mem_placement', []),
        # n_age_tot: total number of Address Generation Engines across all streams
        "n_age_tot"                        : dae_params.get('n_age_tot', 0),
        "n_streams"                        : dae_params.get('n_streams', 0),
        # n_age_per_stream: number of AGEs per stream (uniform)
        "n_age_per_stream"                 : dae_params.get('n_age_per_stream', 0),
        # n_age_per_stream_ds: per-stream AGE count as a list (can be non-uniform)
        "n_age_per_stream_ds"              : dae_params.get('n_age_per_stream_ds', []),
        "num_words"                        : dae_params.get('num_words', 1024),
        "acc_pes"                          : dae_params.get('acc_pes', []),

        # ---- Streaming-specific parameters (Rogue) ----
        # n_pe_in_stream: number of DMA stream inputs routed into each PEA column
        "n_pe_in_stream"                   : streaming_params.get('n_pe_in_stream', 0),
        "pea_in_stream_placement"          : streaming_params.get('pea_in_stream_placement', []),
        # r_fifo_synch_placement_type selects which of the _g2/_g3/_g4 tables
        # below is active, based on how many-way the output-side FIFO
        # synchronization groups are for this hardware instance.
        "r_fifo_synch_placement_type"      : streaming_params.get('r_fifo_synch_placement_type', "g2"),
        "r_fifo_synch_placement_g2"        : streaming_params.get('r_fifo_synch_placement_g2', []),
        "r_fifo_synch_placement_g3"        : streaming_params.get('r_fifo_synch_placement_g3', []),
        "r_fifo_synch_placement_g4"        : streaming_params.get('r_fifo_synch_placement_g4', []),
        "n_dma_ch"                         : streaming_params.get('n_dma_ch', 0),
        "n_in_stream"                      : streaming_params.get('n_in_stream', 0),
        "n_dma_ch_per_in_stream"           : streaming_params.get('n_dma_ch_per_in_stream', 0),
        "n_pea_din_per_in_stream"          : streaming_params.get('n_pea_din_per_in_stream', 0),
        "n_out_stream"                     : streaming_params.get('n_out_stream', 0),
        "n_pea_dout_per_out_stream"        : streaming_params.get('n_pea_dout_per_out_stream', 0),
        "n_dma_ch_per_out_stream"          : streaming_params.get('n_dma_ch_per_out_stream', 0),
        # in_stream_xbar / out_stream_xbar: 1 if a crossbar switch is present
        "in_stream_xbar"                   : streaming_params.get('in_stream_xbar', 0),
        "out_stream_xbar"                  : streaming_params.get('out_stream_xbar', 0),
        # div_pes: list of PE flat indices that contain a divider functional unit
        "div_pes"                          : streaming_params.get('div_pes', []),
        # is_div_pipe: 1 if the divider is pipelined (affects II)
        "is_div_pipe"                      : streaming_params.get('is_div_pipe', 0),
        "in_stream_dma_ch_placement"       : streaming_params.get('in_stream_dma_ch_placement', []),
        "out_stream_pea_dout_placement"    : streaming_params.get('out_stream_pea_dout_placement', []),
        # part_add_pes / part_mul_pes: flat PE indices whose partitioned-format
        # functional unit only supports ADD or only MUL, respectively (as
        # opposed to the full op set). Absent from DAE configs since this is
        # a streaming-PE-variant concept.
        "part_add_pes"                     : streaming_params.get('part_add_pes', []),
        "part_mul_pes"                     : streaming_params.get('part_mul_pes', []),
        # pe_variants / fu_variants: names of the streaming PE/FU RTL modules
        # instantiated for this hardware build (selects op set, burst level,
        # activation-coefficient quantization, etc.) — informational for the
        # spell generator, since the spell-visible config bits are already
        # captured by div_pes/part_add_pes/part_mul_pes/has_delay_pe above.
        "pe_variants"                      : streaming_params.get('pe_variants', []),
        "fu_variants"                      : streaming_params.get('fu_variants', []),
    }

    # Render the requested template. The --pkg-sv path is reserved for future
    # SystemVerilog package generation and is currently unused.
    if args.tpl_sv != None:
        write_template(args.tpl_sv, outdir, outfile, **kwargs)

if __name__ == "__main__":
    main()
