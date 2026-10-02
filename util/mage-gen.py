#!/usr/bin/env python3

# Copyright 2020 ETH Zurich and University of Bologna.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0

#Simplified version of occamygen.py https://github.com/pulp-platform/snitch/blob/master/util/occamygen.py

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

# Compile a regex to trim trailing whitespaces on lines.
re_trailws = re.compile(r'[ \t\r]+$', re.MULTILINE)

# Matches the _m<N>_q<M> coeff suffix in PE/FU variant names, e.g. pe_s_full_gemm_m16_q0
_COEFF_RE = re.compile(r'^(.+)_m(\d+)_q(\d+)$')

def string2int(hex_json_string):
    return (hex_json_string.split('x')[1]).split(',')[0]

# Full property table for every known streaming PE variant.
# Keys: fu_module, fu_inst, has_part_vec_mode, has_div_support, div_is_pipelined, description
PE_VARIANT_TABLE = {
    "pe_s_full_gemm": {
        "fu_module": "fu_s_full_gemm",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": False,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32 computation of classic gemm-related operations",
        "bst_lvl":   None,
        "coeff":   False,
    },
    "pe_s_full_gemm_bst_1": {
        "fu_module": "fu_s_full_gemm_bst_1",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": False,
        "has_div_support":   False,
        "bst_lvl":   1,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32 computation of classic gemm-related operations",
        "coeff":   False,
    },
    "pe_s_full_gemm_bst_2": {
        "fu_module": "fu_s_full_gemm_bst_2",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": False,
        "has_div_support":   False,
        "bst_lvl":   2,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32 computation of classic gemm-related operations",
        "coeff":   False,
    },
    "pe_s_part_gemm_mul_bst_1": {
        "fu_module": "fu_s_part_gemm_mul_bst_1",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   1
    },
    "pe_s_part_gemm_mul_bst_0": {
        "fu_module": "fu_s_part_gemm_mul_bst_0",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   0
    },
    "pe_s_part_gemm_add_bst_3": {
        "fu_module": "fu_s_part_gemm_add_bst_3",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 add and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   3
    },
    "pe_s_part_gemm_add_bst_2": {
        "fu_module": "fu_s_part_gemm_add_bst_2",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 add and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   2
    },
    "pe_s_part_mul_act_serdiv_bst_0": {
        "fu_module": "fu_s_part_mul_act_serdiv_bst_0",
        "fu_inst":   "fu_s_part_mul_act_serdiv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 mul, gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   0
    },
    "pe_s_part_mul_act_pipediv_bst_0": {
        "fu_module": "fu_s_part_mul_act_pipediv_bst_0",
        "fu_inst":   "fu_s_part_mul_act_pipediv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  True,
        "description": "PE for streaming mode supporting int32/int16/int8 mul, gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   0
    },
    "pe_s_full_act_serdiv": {
        "fu_module": "fu_s_full_act_serdiv",
        "fu_inst":   "fu_wrapper_div_i",
        "has_part_vec_mode": False,
        "has_div_support":   True,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32 gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_full_act_pipediv": {
        "fu_module": "fu_s_full_act_pipediv",
        "fu_inst":   "fu_wrapper_div_pipe_i",
        "has_part_vec_mode": False,
        "has_div_support":   True,
        "div_is_pipelined":  True,
        "description": "PE for streaming mode supporting int32 gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_gemm_mul": {
        "fu_module": "fu_s_part_gemm_mul",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_gemm_add": {
        "fu_module": "fu_s_part_gemm_add",
        "fu_inst":   "fu_wrapper_i",
        "has_part_vec_mode": True,
        "has_div_support":   False,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 add and int32 gemm-related operations",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_mul_act_serdiv": {
        "fu_module": "fu_s_part_mul_act_serdiv",
        "fu_inst":   "fu_s_part_mul_act_serdiv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 mul, gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_mul_act_pipediv": {
        "fu_module": "fu_s_part_mul_act_pipediv",
        "fu_inst":   "fu_s_part_mul_act_pipediv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  True,
        "description": "PE for streaming mode supporting int32/int16/int8 mul, gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_add_act_serdiv": {
        "fu_module": "fu_s_part_add_act_serdiv",
        "fu_inst":   "fu_s_part_add_act_serdiv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  False,
        "description": "PE for streaming mode supporting int32/int16/int8 add, gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "pe_s_part_add_act_pipediv": {
        "fu_module": "fu_s_part_add_act_pipediv",
        "fu_inst":   "fu_s_part_add_act_pipediv_i",
        "has_part_vec_mode": True,
        "has_div_support":   True,
        "div_is_pipelined":  True,
        "description": "PE for streaming mode supporting int32/int16/int8 add, gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
}


# Full property table for every known streaming FU variant.
# Keys: arith_type ('full'|'part_mul'|'part_add'), divider_type ('none'|'serdiv'|'pipediv'), description
FU_VARIANT_TABLE = {
    "fu_s_full_gemm": {
        "arith_type":    "full",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_full_gemm_bst_1": {
        "arith_type":    "full",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   1,
    },
    "fu_s_full_gemm_bst_2": {
        "arith_type":    "full",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   2,
    },
    "fu_s_part_gemm_mul_bst_1": {
        "arith_type":    "part_mul",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   1
    },
    "fu_s_part_gemm_mul_bst_0": {
        "arith_type":    "part_mul",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   0
    },
    "fu_s_part_gemm_add_bst_3": {
        "arith_type":    "part_add",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 add and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   3
    },
    "fu_s_part_gemm_add_bst_2": {
        "arith_type":    "part_add",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 add and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   2
    },
    "fu_s_part_mul_act_serdiv_bst_0": {
        "arith_type":    "part_mul",
        "divider_type":  "serdiv",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   0
    },
    "fu_s_part_mul_act_pipediv_bst_0": {
        "arith_type":    "part_mul",
        "divider_type":  "pipediv",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   0
    },


    "fu_s_full_act_serdiv": {
        "arith_type":    "full",
        "divider_type":  "serdiv",
        "description": "FU for streaming mode supporting int32 computation of classic gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_full_act_pipediv": {
        "arith_type":    "full",
        "divider_type":  "pipediv",
        "description": "FU for streaming mode supporting int32 computation of classic gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_part_gemm_mul": {
        "arith_type":    "part_mul",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_part_gemm_add": {
        "arith_type":    "part_add",
        "divider_type":  "none",
        "description": "FU for streaming mode supporting int32/int16/int8 add and int32 computation of classic gemm-related operations",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_part_mul_act_serdiv": {
        "arith_type":    "part_mul",
        "divider_type":  "serdiv",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_part_mul_act_pipediv": {
        "arith_type":    "part_mul",
        "divider_type":  "pipediv",
        "description": "FU for streaming mode supporting int32/int16/int8 mul and int32 gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
    "fu_s_part_add_act_serdiv": {
        "arith_type":    "part_add",
        "divider_type":  "serdiv",
        "description": "FU for streaming mode supporting int32/int16/int8 add and int32 gemm-related operations and activations with serial divider",
        "coeff":   False,
        "bst_lvl":   None,
        },
    "fu_s_part_add_act_pipediv": {
        "arith_type":    "part_add",
        "divider_type":  "pipediv",
        "description": "FU for streaming mode supporting int32/int16/int8 add and int32 gemm-related operations and activations with pipelined divider",
        "coeff":   False,
        "bst_lvl":   None,
    },
}


def write_fu_variants(tpl_path, outdir, fu_variant_names, **cfg_kwargs):
    """Render fu_s.sv.tpl once per variant name listed in fu_variant_names."""
    tpl_path = pathlib.Path(tpl_path).absolute()
    if not tpl_path.exists():
        raise FileNotFoundError(f"FU template not found: {tpl_path}")
    tpl = Template(filename=str(tpl_path))
    for name in fu_variant_names:
        cm = _COEFF_RE.match(name)
        if cm:
            base, n_m, n_q = cm.group(1), int(cm.group(2)), int(cm.group(3))
            if base not in FU_VARIANT_TABLE:
                logging.warning(f"Unknown base FU variant '{base}' in '{name}', skipping")
                continue
            props = {**cfg_kwargs, **FU_VARIANT_TABLE[base]}
            props['coeff'] = True
            props['n_m_coeffs'] = n_m
            props['n_q_coeffs'] = n_q
        else:
            if name not in FU_VARIANT_TABLE:
                logging.warning(f"Unknown FU variant '{name}', skipping")
                continue
            props = {**cfg_kwargs, **FU_VARIANT_TABLE[name]}
            props['n_m_coeffs'] = 0
            props['n_q_coeffs'] = 0
        props["name"] = name
        outfile = outdir / f"{name}.sv"
        with open(outfile, "w") as f:
            code = tpl.render_unicode(**props)
            code = re_trailws.sub("", code)
            f.write(code)
        logging.info(f"Generated {outfile}")


def write_pe_variants(tpl_path, outdir, pe_variant_names, **cfg_kwargs):
    """Render pe_s.sv.tpl once per variant name listed in pe_variant_names."""
    tpl_path = pathlib.Path(tpl_path).absolute()
    if not tpl_path.exists():
        raise FileNotFoundError(f"PE template not found: {tpl_path}")
    tpl = Template(filename=str(tpl_path))
    for name in pe_variant_names:
        cm = _COEFF_RE.match(name)
        if cm:
            base, n_m, n_q = cm.group(1), int(cm.group(2)), int(cm.group(3))
            if base not in PE_VARIANT_TABLE:
                logging.warning(f"Unknown base PE variant '{base}' in '{name}', skipping")
                continue
            props = {**cfg_kwargs, **PE_VARIANT_TABLE[base]}
            props['coeff'] = True
            props['n_m_coeffs'] = n_m
            props['n_q_coeffs'] = n_q
            props['fu_module'] = f"{PE_VARIANT_TABLE[base]['fu_module']}_m{n_m}_q{n_q}"
        else:
            if name not in PE_VARIANT_TABLE:
                logging.warning(f"Unknown PE variant '{name}', skipping")
                continue
            props = {**cfg_kwargs, **PE_VARIANT_TABLE[name]}
            props['n_m_coeffs'] = 0
            props['n_q_coeffs'] = 0
        props["name"] = name
        outfile = outdir / f"{name}.sv"
        with open(outfile, "w") as f:
            code = tpl.render_unicode(**props)
            code = re_trailws.sub("", code)
            f.write(code)
        logging.info(f"Generated {outfile}")


def write_template(tpl_path, outdir, outfile, **kwargs):
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

    # It describes how input dma nodes are organized
    # i.e. The elements at position 0 (0) indicates the dma channels connected to fifo 0
    # has to be [N_IN_STREAM[N_DMA_CH_PER_IN_STREAM]]
    #in_stream_dma_ch_placement = [[0], [1], [2], [3]];
    
    # It indicates which PEA columns outputs are to be connected to each output dma node
    # i.e. The elements at position 0 (0, 1) are PEA columns connected to dma channel 0 output 
    # has to be [N_OUT_STREAM[N_PEA_DOUT_PER_OUT_STREAM]]
    #out_stream_pea_dout_placement = [[0, 1], [0, 1], [2, 3], [2, 3]];

    # It describes how PEA inputs coming from DMA must be organized
    # i.e. The elements at position 0 (0, 1) indicates the dma channels that are connected to PEA column 0
    # has to be [N_PEA_COL[N_PE_IN_STREAM]]
    #pea_in_stream_placement = [[0, 1], [1, 0], [2, 3], [3, 2]];

    # has to be [N_PEA_COL][N_IN_MEM]?
    #pea_in_mem_placement = [[0, 1, 4, 5], [0, 1, 4, 5], [2, 3, 6, 7], [2, 3, 6, 7]];

    parser = argparse.ArgumentParser(prog="mage-gen")
    
    parser.add_argument("--config",
                        metavar="file",
                        type=str,
                        required=False,
                        help="X-Heep general configuration")

    parser.add_argument("--outdir",
                        "-of",
                        type=pathlib.Path,
                        required=True,
                        help="Target directory.")

    parser.add_argument("--outfile",
                        "-o",
                        type=pathlib.Path,
                        required=False,
                        help="Target filename, if omitted the template basename is taken.")

    # Parse arguments
    parser.add_argument("--num_words",
                        metavar="",
                        nargs='?',
                        default="1024",
                        help="")

    parser.add_argument("--pkg-sv",
                        metavar="PKG_SV",
                        help="Name of top-level package file (output)")

    parser.add_argument("--tpl-sv",
                        metavar="TPL_SV",
                        help="Name of SystemVerilog template for your module (output)")

    parser.add_argument("--pe-sv",
                        metavar="PE_TPL_SV",
                        help="Mako template for streaming PE modules (pe_s.sv.tpl); "
                             "generates one .sv per entry in pe_variants from the config")

    parser.add_argument("--fu-sv",
                        metavar="FU_TPL_SV",
                        help="Mako template for streaming FU modules (fu_s.sv.tpl); "
                             "generates one .sv per entry in fu_variants from the config")

    
    parser.add_argument(
        "--mage_cfg",
        "-c",
        metavar="FILE",
        type=argparse.FileType("r"),
        required=True,
        help="Configuration file in HJSON format",
    )
    

    args = parser.parse_args()

    if not args.outdir.is_dir():
            exit("Out directory is not a valid path.")

    outdir = args.outdir
    outdir.mkdir(parents=True, exist_ok=True)

    outfile = args.outfile

    # Read HJSON configuration file
    with args.mage_cfg as f:
        try:
            cfg = hjson.load(f, use_decimal=True)
            cfg = JsonRef.replace_refs(cfg)
        except ValueError as exc:
            raise SystemExit(sys.exc_info()[1]) from exc


    def _collect_bst_pes(sp):
        result, level = [], 0
        while f'bst_{level}_pes' in sp:
            result.append(sp[f'bst_{level}_pes'])
            level += 1
        return result

    # dae_params/streaming_params are only meaningful for their own mode: a DAE
    # config need not carry streaming_params, and vice versa. Read both
    # defensively so either section may be entirely absent.
    dae_params = cfg.get('dae_params', {})
    streaming_params = cfg.get('streaming_params', {})

    kwargs = {
        "dae_cgra"                         : cfg['dae_cgra'],
        "streaming_cgra"                   : cfg['streaming_cgra'],

        "format_full"                      : cfg['format_full'],
        "format_part"                      : cfg['format_part'],

        "gemm_computation"                 : cfg['gemm_computation'],
        "activation_computation"           : cfg['activation_computation'],
        "has_delay_pe"                     : cfg['has_delay_pe'],

        "n_pea_rows"                       : cfg['common_params']['n_pea_rows'],
        "n_pea_cols"                       : cfg['common_params']['n_pea_cols'],
        "n_neigh_pe"                       : cfg['common_params']['n_neigh_pe'],
        "pattern_neigh_pe"                 : cfg['common_params']['pattern_neigh_pe'],
        # shared by both modes (e.g. KMEM_SIZE sizing in pea_pkg.sv.tpl), so it
        # lives in common_params rather than dae_params/streaming_params.
        "kernel_len"                       : cfg['common_params']['kernel_len'],

        "n_pe_in_mem"                      : dae_params.get('n_pe_in_mem', 0),
        "n_streams"                        : dae_params.get('n_streams', 0),
        "pea_in_mem_placement"             : dae_params.get('pea_in_mem_placement', []),
        "n_age_per_stream_ds"              : dae_params.get('n_age_per_stream_ds', []),
        "n_age_tot"                        : dae_params.get('n_age_tot', 0),
        "n_age_per_stream"                 : dae_params.get('n_age_per_stream', 0),
        "num_words"                        : dae_params.get('num_words', 1024),
        "acc_pes"                          : dae_params.get('acc_pes', []),

        "n_pe_in_stream"                   : streaming_params.get('n_pe_in_stream', 0),
        "r_fifo_synch_placement_g2"        : streaming_params.get('r_fifo_synch_placement_g2', []),
        "r_fifo_synch_placement_g3"        : streaming_params.get('r_fifo_synch_placement_g3', []),
        "r_fifo_synch_placement_g4"        : streaming_params.get('r_fifo_synch_placement_g4', []),
        "r_fifo_synch_placement_type"      : streaming_params.get('r_fifo_synch_placement_type', "g2"),
        "pea_in_stream_placement"          : streaming_params.get('pea_in_stream_placement', []),
        "n_dma_ch"                         : streaming_params.get('n_dma_ch', 0),
        "n_in_stream"                      : streaming_params.get('n_in_stream', 0),
        "n_dma_ch_per_in_stream"           : streaming_params.get('n_dma_ch_per_in_stream', 0),
        "n_pea_din_per_in_stream"          : streaming_params.get('n_pea_din_per_in_stream', 0),
        "n_out_stream"                     : streaming_params.get('n_out_stream', 0),
        "n_pea_dout_per_out_stream"        : streaming_params.get('n_pea_dout_per_out_stream', 0),
        "n_dma_ch_per_out_stream"          : streaming_params.get('n_dma_ch_per_out_stream', 0),
        "in_stream_xbar"                   : streaming_params.get('in_stream_xbar', 0),
        "out_stream_xbar"                  : streaming_params.get('out_stream_xbar', 0),
        "div_pes"                          : streaming_params.get('div_pes', []),
        "bst_pes"                          : _collect_bst_pes(streaming_params),
        "coeff_pes"                        : streaming_params.get('coeff_pes', []),
        "num_m_coeffs"                     : streaming_params.get('num_m_coeffs', []),
        "num_q_coeffs"                     : streaming_params.get('num_q_coeffs', []),
        "part_add_pes"                     : streaming_params.get('part_add_pes', []),
        "part_mul_pes"                     : streaming_params.get('part_mul_pes', []),
        "is_div_pipe"                      : streaming_params.get('is_div_pipe', 0),
        "in_stream_dma_ch_placement"       : streaming_params.get('in_stream_dma_ch_placement', []),
        "out_stream_pea_dout_placement"    : streaming_params.get('out_stream_pea_dout_placement', []),
        "pe_variants"                      : streaming_params.get('pe_variants', []),
        "fu_variants"                      : streaming_params.get('fu_variants', []),
    }

    ###########
    #   TPL   #
    ###########
    #if args.pkg_sv != None:
        #write_template(args.pkg_sv, outdir, outfile, **kwargs)

    if args.tpl_sv != None:
        write_template(args.tpl_sv, outdir, outfile, **kwargs)

    if args.pe_sv is not None:
        write_pe_variants(args.pe_sv, outdir, kwargs["pe_variants"], **kwargs)

    if args.fu_sv is not None:
        write_fu_variants(args.fu_sv, outdir, kwargs["fu_variants"], **kwargs)

if __name__ == "__main__":
    main()
