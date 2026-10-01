# MageSpellBuilder — generated configuration builder for Mage/Rogue CGRAs
#
# This file is generated from MageSpellBuilder.py.tpl by spell-gen.py.
# Do not edit it directly; edit the template or re-run spell-gen.py.
#
# MageSpellBuilder accumulates all hardware configuration fields for one kernel
# mapping and then serialises them in two formats:
#
#   generateSpell()   — converts every field to its binary bit-string
#                       representation (self.bin* dicts).
#   generateCSpell()  — writes spell.c, a C function that programs the CGRA
#                       by writing packed 32-bit hex values to MMIO registers.
#
# Configuration sections (some only present for dae_cgra or streaming_cgra):
#
#   DAE (Mage):
#     HWLP    — hardware loop bounds (ilb, flb, li) for up to 4 loop levels
#     PKE     — pipelined kernel execution parameters (multi-kernel schedules)
#     General — initiation interval and vector mode
#     Load Streams  — AGE-to-PE routing for data loads (xbar Banks→PEA)
#     Store Streams — PE-to-AGE routing for data stores (xbar PEA→Banks)
#     SelOutPeaCol  — which PEA column feeds each row output port
#     AGU     — Address Generation Unit config per AGE (loop, strides, banks,
#               per-IV stride mode, accumulation HWLP select)
#     IV Constraints — inter-AGE induction-variable constraints
#
#   Streaming (Rogue):
#     SelOutPeaRow  — which PEA row feeds each column output port
#     PEA Acc Values — accumulation reset values per PE
#
#   Common (both):
#     PEA Config  — per-PE: operation opcode, input mux selects, vecMode, enRF,
#                   delay-operand select
#     PEA Constants — per-PE constant register value (used when input = CONSTANT)
#
# PE config word field presence (matches hw/mage/packages/pea_pkg.sv.tpl):
# `vecMode` is present iff format_part == 1 (2 bits for dae_cgra, 3 bits for
# streaming_cgra); `enRF` is present iff streaming_cgra == 1 (5 bits); `delayOpSel`
# is present iff has_delay_pe == 1 (independent of gemm_computation vs
# activation_computation — that flag only changes the opcode table, not the
# word layout). Bit order (MSB->LSB) per mode:
#   dae   + full: [delayOpSel] operation input1 input0
#   dae   + part: [delayOpSel] vecMode operation input1 input0
#   streaming + full: [delayOpSel] enRF operation input1 input0
#   streaming + part: vecMode [delayOpSel] enRF operation input1 input0

<%! import math %>\
import json
from math import log2
import math as m
import re


class MageSpellBuilder:

    def __init__(self):

%if dae_cgra == 1:
        #------------------------------#
        #             HWLP             #
        #------------------------------#
        self.hwlpConfiguration = {}
        #------------------------------#
        #  General Configuration Bits  #
        #------------------------------#
        self.generalConfiguration = {}
        #------------------------------#
        #     PEA Output Selection     #
        #------------------------------#
        self.selPeaColOutputConfiguration = {}
        self.binSelPeaColOutputConfiguration = {}
        #------------------------------#
        #       IVs Constraints        #
        #------------------------------#
        self.ageIvConstraints = {}
        self.ageStrideModes = {}
        self.ageAccHwlpSel = {}
        #------------------------------#
        #  Load Streams Configuration  #
        #------------------------------#
        self.loadStreamConfiguration = {}
        self.binLoadStreamConfiguration = {}
        #------------------------------#
        # Store Streams Configuration  #
        #------------------------------#
        self.storeStreamConfiguration = {}
        self.binStoreStreamConfiguration = {}
        #------------------------------#
        #      AGU Configuration       #
        #------------------------------#
        self.aguConfiguration = {}
        self.binAguConfiguration = {}
%if kernel_len != 1:
        #------------------------------#
        #             PKE              #
        #------------------------------#
        self.pkeConfiguration = {}
%endif
%endif
%if streaming_cgra == 1:
        #------------------------------#
        #   PEs Accumulation Values    #
        #------------------------------#
        self.peaAccValues = {}
        self.binPeaAccValues = {}
        #------------------------------#
        #     PEA Output Selection     #
        #------------------------------#
        self.selPeaRowOutputConfiguration = {}
        self.binSelPeaRowOutputConfiguration = {}
%endif
        #------------------------------#
        #      PEA Configuration       #
        #------------------------------#
        self.peaConfiguration = {}
        self.binPeaConfiguration = {}
        #------------------------------#
        #        PEs Constants         #
        #------------------------------#
        self.peaConstants = {}
        self.binPeaConstants = {}



        #------------------------------#
        #          PEA Params          #
        #------------------------------#
        self.peaRows = ${n_pea_rows}     # number of PE rows
        self.peaCols = ${n_pea_cols}     # number of PE columns
        self.logNumPeaCols = int(log2(self.peaCols))
        self.logNumPeaRows = int(log2(self.peaRows))
        # kernelLength > 1 enables multi-time-step (pipelined kernel execution)
        # where each PE can have a different configuration at each time step.
        self.kernelLength = ${kernel_len}
        self.meshType = "2D"

%if dae_cgra == 1:
        #------------------------------#
        #  Load & Store Stream Params  #
        #------------------------------#
        # A "PE group" is a set of PEs in one PEA column that all receive data
        # from the same stream.  Each group has numBanksPerGroup AGEs.
        self.numPeGroups = ${len(n_age_per_stream_ds)}
        self.numPePerGroup = ${n_age_per_stream}
        self.logNumPePerGroup = int(log2(self.numPePerGroup))
        self.numBankGroups = ${len(n_age_per_stream_ds)}
        self.numBanksPerGroup = ${n_age_per_stream}
        self.logNumBanksPerGroup = int(log2(self.numBanksPerGroup))

        # Per-stream AGE count (may differ across streams).
        self.n_age_per_stream_ds = ${n_age_per_stream_ds}

        # Bits needed to encode the crossbar select for load/store streams.
        # Must match the field width used by peripheral_regs.sv.tpl (note: m.log
        # there is the natural logarithm).
        self.nbitSelLoadStream = ${int(math.ceil(max(math.log(n_age_per_stream), 2)))}
        self.nbitSelStoreStream = ${int(math.ceil(max(math.log(n_age_per_stream), 2)))}

        #------------------------------#
        #          AGU Params          #
        #------------------------------#
        # The AGU supports up to 4 nested hardware loops (loop levels 0–3).
        self.numLoops = 4
        self.logNumLoops = int(log2(self.numLoops))
        self.numStreams = ${len(n_age_per_stream_ds)}
        self.numAgePerStream = ${n_age_per_stream}
        self.numAgeTot = ${n_age_tot}

        # Bit-widths for individual fields packed into the AGU configuration word.
        # AGU word layout (when isActive=1), as decoded by cfg_dispatcher.sv.tpl
        # through the *_LSB/*_MSB localparams of agu_pkg.sv.tpl:
        #   [31]     isActive        (1 bit)
        #   [30:23]  ageIvConstraint (8 bits) — IV constraint value for this AGE
        #   [22:15]  ivConst         (8 bits) — constant offset in the address expr
        #   [14]     isAccStore      (1 bit)  — 1 if this AGE writes accumulation results
        #   [13]     loadNotStore    (1 bit)  — 1 for load, 0 for store
        #   [12:11]  blockSize       (2 bits) — burst transfer block size
        #   [10:9]   startBank       (2 bits) — starting memory bank index
        #   [8:7]    numBanks        (2 bits) — number of banks accessed per transfer
        #   [6:4]    selIvConstraint (3 bits) — which IV constraint to apply
        #   [3:0]    hwlp            (4 bits) — HWLP register-file entry driving this AGE
        self.nbitMageLoopSel = 4
        self.nbitMageIvSel = self.logNumLoops + 1
        self.nbitNumBanks = 2
        self.nbitStartBank = 2
        self.nbitBlockSize = 2
        self.nbitIvConstraintSel = 3
%endif

        #------------------------------#
        # PEA Output Selection Params  #
        #------------------------------#
%if dae_cgra == 1:
        # Bits of each OUT_PEA_SEL field: must match the field width used by
        # peripheral_regs.sv.tpl (m.log there is the natural logarithm), which
        # is 2 bits for any array with up to 7 columns, not log2(n_pea_cols).
        self.nbitSelOutPeaRow = ${int(math.ceil(max(math.log(n_pea_cols), 2)))}
%endif


        #------------------------------#
        #  Data Struct Initialization  #
        #------------------------------#

        # insert in self.peaConfiguration each PE
        for k in range(self.kernelLength):
            if k not in self.peaConfiguration:
                self.peaConfiguration[k] = {}
                for i in range(self.peaRows):
                    for j in range(self.peaCols):
                        peId = str(i) + str(j)
                        if peId not in self.peaConfiguration[k]:
                            self.peaConfiguration[k][peId] = {}

        # insert in self.peaConstants each PE
        for i in range(self.peaRows):
            for j in range(self.peaCols):
                if i not in self.peaConstants:
                    self.peaConstants[i] = {}
                if j not in self.peaConstants[i]:
                    self.peaConstants[i][j] = {}

%if dae_cgra == 1:
        # initializing self.loadStreamConfiguration
        for k in range(self.kernelLength):
            if k not in self.loadStreamConfiguration:
                self.loadStreamConfiguration[k] = {}
            for i in range(len(self.n_age_per_stream_ds)):
                if i not in self.loadStreamConfiguration[k]:
                    self.loadStreamConfiguration[k][i] = {}
                for j in range(self.n_age_per_stream_ds[i]):
                    if j not in self.loadStreamConfiguration[k][i]:
                        self.loadStreamConfiguration[k][i][j] = {"cfg": []}

        # initializing self.storeStreamConfiguration
        for k in range(self.kernelLength):
            if k not in self.storeStreamConfiguration:
                self.storeStreamConfiguration[k] = {}
            for i in range(len(self.n_age_per_stream_ds)):
                if i not in self.storeStreamConfiguration[k]:
                    self.storeStreamConfiguration[k][i] = {}
                for j in range(self.n_age_per_stream_ds[i]):
                    if j not in self.storeStreamConfiguration[k][i]:
                        self.storeStreamConfiguration[k][i][j] = {}

        # initializing self.selPeaColOutputConfiguration
        for i in range(self.kernelLength):
            if i not in self.selPeaColOutputConfiguration:
                self.selPeaColOutputConfiguration[i] = {}
                for j in range(self.peaRows):
                    for k in range(2):
                        peaOutputId = str(j) + str(k)
                        if peaOutputId not in self.selPeaColOutputConfiguration[i]:
                            self.selPeaColOutputConfiguration[i][peaOutputId] = {}

        # initializing self.aguConfiguration
        for i in range(self.kernelLength):
            if i not in self.aguConfiguration:
                self.aguConfiguration[i] = {}
                for j in range(len(self.n_age_per_stream_ds)):
                    if j not in self.aguConfiguration[i]:
                        self.aguConfiguration[i][j] = {}
                        for k in range(self.n_age_per_stream_ds[j]):
                            if k not in self.aguConfiguration[i][j]:
                                self.aguConfiguration[i][j][k] = {}
%endif
%if streaming_cgra == 1:
        # initializing self.selPeaRowOutputConfiguration
        for j in range(self.peaCols):
            peaOutputId = str(j)
            if peaOutputId not in self.selPeaRowOutputConfiguration:
                self.selPeaRowOutputConfiguration[j]= {}
        

        # insert in self.peaAccValues each PE
        for i in range(self.peaRows):
            for j in range(self.peaCols):
                if i not in self.peaAccValues:
                    self.peaAccValues[i] = {}
                if j not in self.peaAccValues[i]:
                    self.peaAccValues[i][j] = {}
%endif

    #--------------------------------------------------------------#
    #                   Configuration Functions                    #
    #--------------------------------------------------------------#
%if dae_cgra == 1:
    def insertHwlpConfiguration(self, ilb, flb, li):
        """Set the 4-level hardware loop bounds.

        Each argument is a list of 4 integers, one per loop level (0–3).
        Index i is hardware loop i, the same i used by {i} in the AGE address
        DSL; loop 0 is the innermost loop. Each value must fit in 8 bits.
        Hardware loops count from ilb[i] to flb[i] inclusive with step li[i].
        The FLB convention is 0-based, so FLB = N-1 for a loop of N iterations.

        Args:
            ilb: Initial loop bounds  [ilb0, ilb1, ilb2, ilb3]
            flb: Final loop bounds    [flb0, flb1, flb2, flb3]
            li:  Loop increments      [li0,  li1,  li2,  li3]
        """
        self.hwlpConfiguration = {
            "ilb": ilb,
            "flb": flb,
            "li": li
        }
%if kernel_len != 1:
    def insertPkeConfiguration(self, pSize, kSize, eSize, lenDfg):
        """Configure pipelined kernel execution (multi-kernel schedules).

        Args:
            pSize:  prologue size in time steps
            kSize:  kernel (steady-state) size in time steps
            eSize:  epilogue size in time steps
            lenDfg: total length of the DFG (pSize + kSize + eSize)
        """
        self.pkeConfiguration = {
            "pSize": pSize,
            "kSize": kSize,
            "eSize": eSize,
            "lenDfg": lenDfg
        }

    def insertGeneralConfiguration(self, ii, vecMode, snt_agu, snt_pea, snt_pea_sel_out, snt_pea_load_stream, snt_pea_stream_stream):
        """General CGRA config for multi-kernel (kernel_len > 1) schedules.

        Args:
            ii:                   Initiation interval in cycles
            vecMode:              Vector mode binary encoding (VEC_MODE_*_BIN)
            snt_agu:              Schedule-no-time flag for AGU config
            snt_pea:              Schedule-no-time flag for PEA config
            snt_pea_sel_out:      Schedule-no-time flag for output selection
            snt_pea_load_stream:  Schedule-no-time flag for load stream config
            snt_pea_stream_stream: Schedule-no-time flag for stream-stream config
        """
        self.generalConfiguration = {
            "ii": ii,
            "vecMode": vecMode,
            "snt_agu": snt_agu,
            "snt_pea": snt_pea,
            "snt_pea_sel_out": snt_pea_sel_out,
            "snt_pea_load_stream": snt_pea_load_stream,
            "snt_pea_stream_stream": snt_pea_stream_stream
        }
%endif

    def insertGeneralConfiguration(self, ii, vecMode):
        """General CGRA config for single-kernel (kernel_len == 1) schedules.

        Args:
            ii:      Initiation interval in cycles (0 = not set)
            vecMode: Vector mode binary encoding (VEC_MODE_32_BIN=0,
                     VEC_MODE_16_BIN=2, VEC_MODE_8_BIN=1)
        """
        self.generalConfiguration = {
            "ii": ii,
            "vecMode": vecMode
        }
%endif

    def insertPeConstant(self, peRow, peCol, constant):
        """Set the constant register value for a PE.

        This value is used when a PE's input mux selects CONSTANT (encoding
        "0000"). It can be an integer literal or a C macro name (string) that
        will be emitted verbatim in spell.c.

        Args:
            peRow:    Row index of the PE (0-based).
            peCol:    Column index of the PE (0-based).
            constant: Integer value or C identifier string.
        """
        self.peaConstants[peRow][peCol] = constant

%if streaming_cgra == 1:
    def insertPeAccValue(self, peRow, peCol, accValue):
        """Set the accumulation reset value for a PE (streaming mode only).

        When a PE uses the ACC operation its internal accumulator is reset to
        this value at the start of each DMA transfer. Use an integer literal or
        a C macro name (string) that will be emitted verbatim in spell.c.

        Args:
            peRow:    Row index (0-based).
            peCol:    Column index (0-based).
            accValue: Reset value (integer or C identifier string).
        """
        self.peaAccValues[peRow][peCol] = accValue
%endif

%if kernel_len != 1:
%if dae_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation):
        %endif
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode):
        %endif
    %endif
%endif
%if streaming_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, enRF, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, enRF):
        %endif
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, enRF, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, enRF):
        %endif
    %endif
%endif
%else:
%if dae_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, input0, input1, operation, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, input0, input1, operation):
        %endif
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, input0, input1, operation, vecMode, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, input0, input1, operation, vecMode):
        %endif
    %endif
%endif
%if streaming_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, input0, input1, operation, enRF, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, input0, input1, operation, enRF):
        %endif
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    def insertPeConfiguration(self, peId, input0, input1, operation, vecMode, enRF, delayOpSel):
        %else:
    def insertPeConfiguration(self, peId, input0, input1, operation, vecMode, enRF):
        %endif
    %endif
%endif
%endif
%if format_part == 1:
<%
    vecmode_width = 2 if dae_cgra == 1 else 3
%>
        if (vecMode == 16):
            vm = format(2, 'b').zfill(${vecmode_width})
        elif (vecMode == 8):
            vm = format(1, 'b').zfill(${vecmode_width})
        else:
            vm = format(0, 'b').zfill(${vecmode_width})
%endif
%if kernel_len != 1:
        if (time == "all"):
            peIdxRange = range(0, self.kernelLength)
        elif (time == "range"):
            peIdxRange = range(rangeInit, rangeFinal)
        else:
            peIdxRange = [time]
        for i in peIdxRange:
            self.peaConfiguration[i][peId] = {}
            self.peaConfiguration[i][peId]["input0"] = input0
            self.peaConfiguration[i][peId]["input1"] = input1
            self.peaConfiguration[i][peId]["operation"] = operation
    %if format_part == 1:
            self.peaConfiguration[i][peId]["vecMode"] = vm
    %endif
    %if streaming_cgra == 1:
            self.peaConfiguration[i][peId]["enRF"] = enRF
    %endif
    %if has_delay_pe == 1:
            self.peaConfiguration[i][peId]["delayOpSel"] = delayOpSel
    %endif
%else:
        self.peaConfiguration[0][peId] = {}
        self.peaConfiguration[0][peId]["input0"] = input0
        self.peaConfiguration[0][peId]["input1"] = input1
        self.peaConfiguration[0][peId]["operation"] = operation
    %if format_part == 1:
        self.peaConfiguration[0][peId]["vecMode"] = vm
    %endif
    %if streaming_cgra == 1:
        self.peaConfiguration[0][peId]["enRF"] = enRF
    %endif
    %if has_delay_pe == 1:
        self.peaConfiguration[0][peId]["delayOpSel"] = delayOpSel
    %endif
%endif

%if dae_cgra == 1:
    %if kernel_len != 1:
    def insertLoadStreamConfiguration(self, time, rangeInit, rangeFinal, peGroup, peId, loadAgeId):
    %else:
    def insertLoadStreamConfiguration(self, peGroup, peId, loadAgeId):
    %endif
%if kernel_len != 1:
        if (time == "all"):
            for i in range(0, self.kernelLength):
                self.loadStreamConfiguration[i][peGroup][peId] = {
                    "cfg": loadAgeId
                }
        elif (time == "range"):
            for i in range(rangeInit, rangeFinal):
                self.loadStreamConfiguration[i][peGroup][peId] = {
                    "cfg": loadAgeId
                }
        else:
            self.loadStreamConfiguration[time][peGroup][peId] = {
                "cfg": loadAgeId
            }
%else:
        self.loadStreamConfiguration[0][peGroup][peId] = {
            "cfg": loadAgeId
        }
%endif

    %if kernel_len != 1:
    def insertStoreStreamConfiguration(self, time, rangeInit, rangeFinal, peGroup, peId, StoreAgeId):
    %else:
    def insertStoreStreamConfiguration(self, peGroup, peId, StoreAgeId):
    %endif
%if kernel_len != 1:
        if (time == "all"):
            for i in range(0, self.kernelLength):
                self.storeStreamConfiguration[i][peGroup][peId] = {
                    "cfg": StoreAgeId
                }
        elif (time == "range"):
            for i in range(rangeInit, rangeFinal):
                self.storeStreamConfiguration[i][peGroup][peId] = {
                    "cfg": StoreAgeId
                }
        else:
            self.storeStreamConfiguration[time][peGroup][peId] = {
                "cfg": StoreAgeId
            }
%else:
        self.storeStreamConfiguration[0][peGroup][peId] = {
            "cfg": StoreAgeId
        }
%endif

    %if kernel_len != 1:
    def insertSelOutPeaColConfiguration(self, time, rangeInit, rangeFinal, peaOutputId, peaSelectedColumn):
    %else:
    def insertSelOutPeaColConfiguration(self, peaOutputId, peaSelectedColumn):
    %endif

%if kernel_len != 1:
        if (time == "all"):
            for i in range(0, self.kernelLength):
                self.selPeaColOutputConfiguration[i][peaOutputId] = {
                    "cfg": peaSelectedColumn
                }
        elif (time == "range"):
            for i in range(rangeInit, rangeFinal):
                self.selPeaColOutputConfiguration[i][peaOutputId] = {
                    "cfg": peaSelectedColumn
                }
        else:
            self.selPeaColOutputConfiguration[time][peaOutputId] = {
                "cfg": peaSelectedColumn
            }
%else:
        self.selPeaColOutputConfiguration[0][peaOutputId] = {
            "cfg": peaSelectedColumn
        }
%endif
%endif
%if streaming_cgra == 1:
    def insertSelOutPeaRowConfiguration(self, peaOutputId, peaSelectedRow):
        if (peaSelectedRow == 0):
            cfg = format(0, 'b').zfill(8)
        else:
            cfg = format(peaSelectedRow, 'b').zfill(8)

        self.selPeaRowOutputConfiguration[peaOutputId] = {
            "cfg": cfg
        }
%endif

%if dae_cgra == 1:
    %if kernel_len != 1:
    def insertAgeConfiguration(self, time, rangeInit, rangeFinal, streamId, ageId, loopSel, startBank, numBanks, blockSize, loadNotStore, selIvConstraint, isAccStore, isActive, array, strideModes=None, accHwlpSel=0):
    %else:
    def insertAgeConfiguration(self, streamId, ageId, loopSel, startBank, numBanks, blockSize, loadNotStore, selIvConstraint, isAccStore, isActive, array, strideModes=None, accHwlpSel=0):
    %endif
        """Configure one Address Generation Engine (AGE).

        An AGE generates a sequence of memory bank addresses driven by the
        hardware loop induction variables.  The address expression is specified
        as a string using the DSL:

            "Array[s0*{iv0} + s1*{iv1} + s2*{iv2} + s3*{iv3} + const]"

        where si are stride coefficients and {ivi} denote loop induction
        variables 0–3.  The parser extracts the strides and the constant offset
        from this string.

        Args:
            time (kernel_len > 1 only): "all" | "range" | integer time index
            rangeInit / rangeFinal:     inclusive range when time == "range"
            streamId:     Stream (group) index this AGE belongs to.
            ageId:        AGE index within the stream.
            loopSel:      Which hardware loop (0–3) drives this AGE's iteration.
            startBank:    First memory bank address (2-bit field).
            numBanks:     Number of banks accessed per loop iteration (2-bit).
            blockSize:    Burst block size per access (2-bit).
            loadNotStore: 1 for a load AGE, 0 for a store AGE.
            selIvConstraint: Which IV constraint register this AGE reads (3-bit).
            isAccStore:   1 if this store AGE writes accumulated PE results.
            isActive:     1 to enable this AGE; 0 to disable (word becomes 0x0).
            array:        Address expression string, e.g.
                          "Array[1*{0}+0*{1}+4*{2}+0*{3}+0]"
            strideModes:  Optional list of 4 ints (one per IV 0-3), each 0 (linear,
                          Si*i) or 1 (tiled, (i>>log2(Si))*(i%Si)). Defaults to all
                          linear ([0,0,0,0]) if omitted. Written to the per-AGE
                          STRIDE_MODE register. In tiled mode the stride written
                          in `array` for that IV is the raw register field, i.e.
                          log2(Si) (0-7), not Si itself.
            accHwlpSel:   4-bit value (0-15) selecting which HWLP register-file
                          entry governs this AGE's accumulation reset point when
                          isAccStore=1 (independent of loopSel, which drives the
                          AGE's own address iteration). Written to the shared
                          ACC_HWLP_SEL register (8 AGEs packed per register).
                          Defaults to 0.
        """
        # Bind each stride to the IV named in its {i}, not to its position in
        # the string; IVs that don't appear get stride 0.
        strides = ["0"] * self.numLoops
        subsIv = []
        for stride, iv in re.findall(r'(\d+)\*\{(\d+)\}', array):
            iv = int(iv)
            if iv >= self.numLoops or iv in subsIv:
                raise ValueError(f"{array}: IV {{{iv}}} is out of range or repeated")
            strides[iv] = stride
            subsIv.append(iv)
        const = re.findall(r'(\d+)\]', array)[0]
        if strideModes is None:
            strideModes = [0, 0, 0, 0]

%if kernel_len != 1:
        if (time == "all"):
            for i in range(0, self.kernelLength):
                self.aguConfiguration[i][streamId][ageId] = {
                    "hwlp": loopSel,
                    "numBanks": numBanks,
                    "blockSize": blockSize,
                    "loadNotStore": loadNotStore,
                    "startBank": startBank,
                    "selIvConstraint": selIvConstraint,
                    "isAccStore": isAccStore,
                    "strides": strides,
                    "subsIv": subsIv,
                    "ivConst": const,
                    "isActive": isActive,
                    "constraint": "none",
                    "strideModes": strideModes,
                    "accHwlpSel": accHwlpSel
                }
        elif (time == "range"):
            for i in range(rangeInit, rangeFinal):
                self.aguConfiguration[i][streamId][ageId] = {
                    "hwlp": loopSel,
                    "numBanks": numBanks,
                    "blockSize": blockSize,
                    "startBank": startBank,
                    "loadNotStore": loadNotStore,
                    "selIvConstraint": selIvConstraint,
                    "isAccStore": isAccStore,
                    "strides": strides,
                    "subsIv": subsIv,
                    "ivConst": const,
                    "isActive": isActive,
                    "constraint": "none",
                    "strideModes": strideModes,
                    "accHwlpSel": accHwlpSel
                }
        else:
            self.aguConfiguration[time][streamId][ageId] = {
                "hwlp": loopSel,
                "numBanks": numBanks,
                "blockSize": blockSize,
                "startBank": startBank,
                "loadNotStore": loadNotStore,
                "selIvConstraint": selIvConstraint,
                "isAccStore": isAccStore,
                "strides": strides,
                "subsIv": subsIv,
                "ivConst": const,
                "isActive": isActive,
                "constraint": "none",
                "strideModes": strideModes,
                "accHwlpSel": accHwlpSel
            }
%else:
        self.aguConfiguration[0][streamId][ageId] = {
               "hwlp": loopSel,
               "numBanks": numBanks,
               "blockSize": blockSize,
               "startBank": startBank,
               "loadNotStore": loadNotStore,
               "selIvConstraint": selIvConstraint,
               "isAccStore": isAccStore,
               "strides": strides,
               "subsIv": subsIv,
               "ivConst": const,
               "isActive": isActive,
               "constraint": "none",
               "strideModes": strideModes,
               "accHwlpSel": accHwlpSel
           }
%endif

    def insertAgeIvConstraint(self, streamId, ageId, ivConstraint):
        """Attach an induction-variable constraint value to an AGE.

        An IV constraint allows one AGE to stall until another AGE's induction
        variable reaches a specific threshold, enabling producer–consumer
        synchronisation inside the CGRA without software intervention.

        Args:
            streamId:     Stream index of the target AGE.
            ageId:        AGE index within the stream.
            ivConstraint: Threshold value (integer); 0 means no constraint.
        """
        self.aguConfiguration[0][streamId][ageId]["constraint"] = ivConstraint
%endif

    #--------------------------------------------------------------#
    #                Generation of C Configurations                #
    #--------------------------------------------------------------#

    def generateSpell(self):
        """Convert all configuration dicts to binary bit-string representations.

        Each self.bin* dict mirrors the corresponding self.* dict but contains
        zero-padded binary strings instead of symbolic values.  The PE
        configuration word layout is described at the top of this file.

        AGU word layout (isActive=1):
            isActive(1) | ageIvConstraint(8) | ivConst(8) | isAccStore(1)
            | loadNotStore(1) | blockSize(2) | startBank(2) | numBanks(2)
            | selIvConstraint(3) | hwlp(4)
        """
        # initialize the dictionaries
        for i in range(self.kernelLength):
            if i not in self.binPeaConfiguration:
                self.binPeaConfiguration[i] = {}
                for j in range(self.peaRows):
                    for k in range(self.peaCols):
                        peId = str(j) + str(k)
                        if peId not in self.binPeaConfiguration[i]:
                            self.binPeaConfiguration[i][peId] = {}

        for j in range(self.peaRows):
            for k in range(self.peaCols):
                if j not in self.binPeaConstants:
                    self.binPeaConstants[j] = {}
                if k not in self.binPeaConstants[j]:
                    self.binPeaConstants[j][k] = {}

%if streaming_cgra == 1:
        for j in range(self.peaCols):
            peaOutputId = str(j)
            if peaOutputId not in self.binSelPeaRowOutputConfiguration:
                self.binSelPeaRowOutputConfiguration[peaOutputId] = {}

        for j in range(self.peaRows):
            for k in range(self.peaCols):
                if j not in self.binPeaAccValues:
                    self.binPeaAccValues[j] = {}
                if k not in self.binPeaAccValues[j]:
                    self.binPeaAccValues[j][k] = {}
%endif
%if dae_cgra == 1:
            if i not in self.binSelPeaColOutputConfiguration:
                self.binSelPeaColOutputConfiguration[i] = {}
                for j in range(self.peaRows):
                    for k in range(2):
                        peaOutputId = str(j) + str(k)
                        if peaOutputId not in self.binSelPeaColOutputConfiguration[i]:
                            self.binSelPeaColOutputConfiguration[i][peaOutputId] = {}

            if i not in self.binAguConfiguration:
                self.binAguConfiguration[i] = {}
                self.ageIvConstraints[i] = {}
                self.ageStrideModes[i] = {}
                self.ageAccHwlpSel[i] = {}
                for j in range(len(self.n_age_per_stream_ds)):
                    if j not in self.binAguConfiguration[i]:
                        self.binAguConfiguration[i][j] = {}
                        self.ageIvConstraints[i][j] = {}
                        self.ageStrideModes[i][j] = {}
                        self.ageAccHwlpSel[i][j] = {}
                        for k in range(self.n_age_per_stream_ds[j]):
                            if k not in self.binAguConfiguration[i][j]:
                                self.binAguConfiguration[i][j][k] = {}
                                self.ageIvConstraints[i][j][k] = {}
                                self.ageStrideModes[i][j][k] = {}
                                self.ageAccHwlpSel[i][j][k] = {}

            if i not in self.binLoadStreamConfiguration:
                self.binLoadStreamConfiguration[i] = {}
                for j in range(len(self.n_age_per_stream_ds)):
                    if j not in self.binLoadStreamConfiguration[i]:
                        self.binLoadStreamConfiguration[i][j] = {}
                        for k in range(self.n_age_per_stream_ds[j]):
                            if k not in self.binLoadStreamConfiguration[i][j]:
                                self.binLoadStreamConfiguration[i][j][k] = ""

            if i not in self.binStoreStreamConfiguration:
                self.binStoreStreamConfiguration[i] = {}
                for j in range(len(self.n_age_per_stream_ds)):
                    if j not in self.binStoreStreamConfiguration[i]:
                        self.binStoreStreamConfiguration[i][j] = {}
                        for k in range(self.n_age_per_stream_ds[j]):
                            if k not in self.binStoreStreamConfiguration[i][j]:
                                self.binStoreStreamConfiguration[i][j][k] = {}
%endif

        for j in range(self.peaRows):
            for k in range(self.peaCols):
                self.binPeaConstants[j][k] = self.peaConstants[j][k]

%if dae_cgra == 1:
    %if format_full == 1:
        for i in range(self.kernelLength):
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    peId = str(j) + str(k)
                    binPe = ""
    %if has_delay_pe == 1:
                    binPe += str(self.peaConfiguration[i][peId]["delayOpSel"])
    %endif
                    binPe += str(self.peaConfiguration[i][peId]["operation"])
                    binPe += str(self.peaConfiguration[i][peId]["input1"])
                    binPe += str(self.peaConfiguration[i][peId]["input0"])
                    self.binPeaConfiguration[i][peId] = binPe
    %endif
    %if format_part == 1:
        for i in range(self.kernelLength):
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    peId = str(j) + str(k)
                    binPe = ""
    %if has_delay_pe == 1:
                    binPe += str(self.peaConfiguration[i][peId]["delayOpSel"])
    %endif
                    binPe += str(self.peaConfiguration[i][peId]["vecMode"])
                    binPe += str(self.peaConfiguration[i][peId]["operation"])
                    binPe += str(self.peaConfiguration[i][peId]["input1"])
                    binPe += str(self.peaConfiguration[i][peId]["input0"])
                    self.binPeaConfiguration[i][peId] = binPe
    %endif
%endif

%if streaming_cgra == 1:
    %if format_full == 1:
        for i in range(self.kernelLength):
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    peId = str(j) + str(k)
                    binPe = ""
    %if has_delay_pe == 1:
                    binPe += str(self.peaConfiguration[i][peId]["delayOpSel"])
    %endif
                    binPe += format(int(str(self.peaConfiguration[i][peId]["enRF"]), 2), 'b').zfill(5)
                    binPe += str(self.peaConfiguration[i][peId]["operation"])
                    binPe += str(self.peaConfiguration[i][peId]["input1"])
                    binPe += str(self.peaConfiguration[i][peId]["input0"])
                    self.binPeaConfiguration[i][peId] = binPe
    %endif
    %if format_part == 1:
        for i in range(self.kernelLength):
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    peId = str(j) + str(k)
                    binPe = str(self.peaConfiguration[i][peId]["vecMode"])
    %if has_delay_pe == 1:
                    binPe += str(self.peaConfiguration[i][peId]["delayOpSel"])
    %endif
                    binPe += format(int(str(self.peaConfiguration[i][peId]["enRF"]), 2), 'b').zfill(5)
                    binPe += str(self.peaConfiguration[i][peId]["operation"])
                    binPe += str(self.peaConfiguration[i][peId]["input1"])
                    binPe += str(self.peaConfiguration[i][peId]["input0"])
                    self.binPeaConfiguration[i][peId] = binPe
    %endif
%endif

<%
    # Same field widths as pea_pkg.sv.tpl.
    if streaming_cgra == 1:
        n_inputs_pe = n_pe_in_stream + n_neigh_pe + 4
    else:
        n_inputs_pe = n_neigh_pe + n_pe_in_mem + 3
    pe_word_bits = 2 * max(1, math.ceil(math.log2(n_inputs_pe))) + 5
    if format_part == 1:
        pe_word_bits += 2 if dae_cgra == 1 else 3
    if streaming_cgra == 1:
        pe_word_bits += 5
    if has_delay_pe == 1:
        pe_word_bits += math.ceil(math.log2(n_neigh_pe)) + 2
%>\
        # Every field is a fixed-width bit string; a wrong-width argument would
        # silently shift the other fields of the PE word.
        for i in range(self.kernelLength):
            for peId, binPe in self.binPeaConfiguration[i].items():
                if len(binPe) != ${pe_word_bits}:
                    raise ValueError(f"PE {peId}: configuration word is {len(binPe)} bits, expected ${pe_word_bits}; "
                                     "check the width of each insertPeConfiguration argument")

%if streaming_cgra == 1:
        for j in range(self.peaRows):
            for k in range(self.peaCols):
                self.binPeaAccValues[j][k] = self.peaAccValues[j][k]
%endif

%if dae_cgra == 1:
        
        # Xbar Banks-PEA Configuration
        for i in range(self.kernelLength):
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    self.binLoadStreamConfiguration[i][j][k] += str(format(int(
                        self.loadStreamConfiguration[i][j][k]["cfg"]), 'b').zfill(self.nbitSelLoadStream))

        # Xbar PEA-Banks Configuration
        for i in range(self.kernelLength):
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    self.binStoreStreamConfiguration[i][j][k] = format(int(
                        self.storeStreamConfiguration[i][j][k]["cfg"]), 'b').zfill(self.nbitSelStoreStream)

        
        # Selection of PEA output Configuration
        for i in range(self.kernelLength):
            for j in range(self.peaRows):
                for k in range(2):
                    peaOutputId = str(j) + str(k)
                    self.binSelPeaColOutputConfiguration[i][peaOutputId] = format(int(
                        self.selPeaColOutputConfiguration[i][peaOutputId]["cfg"]), 'b').zfill(self.nbitSelOutPeaRow)
%endif
%if streaming_cgra == 1:                    
        for j in range(self.peaCols):
            peaOutputId = str(j)
            self.binSelPeaRowOutputConfiguration[peaOutputId] = format(int(
                self.selPeaRowOutputConfiguration[peaOutputId]["cfg"]), 'b').zfill(8)
%endif
%if dae_cgra == 1:
        # AGU Configuration
        for i in range(self.kernelLength):
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    hwlp = format(int(self.aguConfiguration[i][j][k]["hwlp"]), 'b').zfill(
                        self.nbitMageLoopSel)
                    numBanks = format(int(self.aguConfiguration[i][j][k]["numBanks"]), 'b').zfill(
                        self.nbitNumBanks)
                    blockSize = format(int(self.aguConfiguration[i][j][k]["blockSize"]), 'b').zfill(
                        self.nbitBlockSize)
                    startBank = format(int(self.aguConfiguration[i][j][k]["startBank"]), 'b').zfill(
                        self.nbitStartBank)
                    selIvConstraint = format(int(self.aguConfiguration[i][j][k]["selIvConstraint"]), 'b').zfill(
                        self.nbitIvConstraintSel)
                    loadNotStore = format(
                        int(self.aguConfiguration[i][j][k]["loadNotStore"]), 'b').zfill(1)
                    isAccStore = format(
                        int(self.aguConfiguration[i][j][k]["isAccStore"]), 'b').zfill(1)
                    isActive = format(
                        int(self.aguConfiguration[i][j][k]["isActive"]), 'b').zfill(1)
                    ivConst = ""
                    strides = ""
                    ageIvConstraint = ""
                    for l in range(len(self.aguConfiguration[i][j][k]["strides"]) - 1, -1, -1):
                        strides += format(int(self.aguConfiguration[i][j][k]["strides"][l]), 'b').zfill(8)
                    ivConst = format(int(self.aguConfiguration[i][j][k]["ivConst"]), 'b').zfill(8)
                    constraint = self.aguConfiguration[i][j][k]["constraint"]
                    ageIvConstraint = format(0 if constraint == "none" else int(constraint), 'b').zfill(8)
                    strideModes = self.aguConfiguration[i][j][k]["strideModes"]
                    strideModeBits = ""
                    for l in range(len(strideModes) - 1, -1, -1):
                        strideModeBits += str(int(strideModes[l]))
                    accHwlpSelBits = format(int(self.aguConfiguration[i][j][k]["accHwlpSel"]), 'b').zfill(4)
                    if (isActive == "1"):
                        self.binAguConfiguration[i][j][k] = isActive + ageIvConstraint + ivConst + isAccStore + loadNotStore + blockSize + startBank + numBanks + selIvConstraint + hwlp
                        # zfill never truncates: a field that overflows its width
                        # would silently shift every other field.
                        ageName = f"AGE (stream {j}, id {k})"
                        if len(self.binAguConfiguration[i][j][k]) != 32:
                            raise ValueError(f"{ageName}: a configuration field exceeds its bit width "
                                             f"(word is {len(self.binAguConfiguration[i][j][k])} bits)")
                        if len(strides) != 32:
                            raise ValueError(f"{ageName}: every stride must fit in 8 bits")
                        if len(strideModeBits) != 4 or set(strideModeBits) - {"0", "1"}:
                            raise ValueError(f"{ageName}: strideModes must be 4 values, each 0 or 1")
                        for l in range(4):
                            if strideModes[l] == 1 and int(self.aguConfiguration[i][j][k]["strides"][l]) > 7:
                                raise ValueError(f"{ageName}: IV {l} is in tiled mode, so its stride field "
                                                 "holds log2(Si) and must be in 0..7")
                        if len(accHwlpSelBits) != 4:
                            raise ValueError(f"{ageName}: accHwlpSel must be in 0..15")
                        self.ageIvConstraints[i][j][k] = strides
                        self.ageStrideModes[i][j][k] = strideModeBits
                        self.ageAccHwlpSel[i][j][k] = accHwlpSelBits
                    else:
                        self.binAguConfiguration[i][j][k] = "0"
                        self.ageIvConstraints[i][j][k] = "none"
                        self.ageStrideModes[i][j][k] = "none"
                        self.ageAccHwlpSel[i][j][k] = "none"
%endif

%if dae_cgra == 1:
    def _writePackedFields(self, f, regName, varName, fields, width):
        """Pack fixed-width bit-string fields LSB-first into 32-bit words and
        emit the corresponding register writes (skipped if all zero)."""
        value = 0
        for idx, field in enumerate(fields):
            if len(field) > width:
                raise ValueError(f"{varName}: field {idx} = 0b{field} does not fit in {width} bits")
            value |= int(field, 2) << (idx * width)
        if value == 0:
            return
        numWords = m.ceil(len(fields) * width / 32)
        words = [hex((value >> (32 * w)) & 0xFFFFFFFF) for w in range(numWords)]
        f.write(f"\tuint32_t {varName}[{numWords}] = {{" + ", ".join(words) + "};\n")
        for w in range(numWords):
            f.write(f"\t{regName}[{w}] = {varName}[{w}];\n")
        f.write("\n")

%endif
    def generateCSpell(self, appName, outPath="./spell.c"):
        """Write spell.c — a C function that programs the CGRA via MMIO writes.

        The generated function is named  mage_<appName>_cfg()  and contains:
          1. Pointer declarations to each CGRA register file base address.
          2. For DAE mode: HWLP, PKE, general config, AGU config, AGU strides,
             AGU stride mode, AGU accumulation HWLP select, load-stream xbar,
             store-stream xbar, PEA output select writes.
          3. For streaming mode: output-row select, accumulation values writes.
          4. Common: PE constant registers, PE configuration registers.

        Configuration words are packed MSB-first into 32-bit words before
        being written; non-zero entries are emitted, zero entries are skipped
        (the hardware reset value is already 0).

        Args:
            appName: Kernel name embedded in the generated C function name
                     (e.g. "matmul" → function mage_matmul_cfg).
            outPath: Path of the generated C file.
        """
        with open(outPath, 'w') as f:
%if dae_cgra == 1:
            #------------------------------#
            #          Variables           #
            #------------------------------#
            f.write("uint32_t *mage_status          = ((int32_t *)(MAGE_STATUS_START_ADDR));\n")
            f.write("uint32_t *mage_gen_cfg         = ((int32_t *)(MAGE_GEN_CFG_START_ADDR));\n")
            f.write("uint32_t *mage_hwl_ilb         = ((int32_t *)(MAGE_ILB_HWL_START_ADDR));\n")
            f.write("uint32_t *mage_hwl_flb         = ((int32_t *)(MAGE_FLB_HWL_START_ADDR));\n")
            f.write("uint32_t *mage_hwl_li          = ((int32_t *)(MAGE_LI_HWL_START_ADDR));\n")
    %if kernel_len != 1:
            f.write("uint32_t *mage_pke             = ((int32_t *)(MAGE_PKE_START_ADDR));\n")
    %endif            
            f.write("uint32_t *mage_sel_out_pea     = ((int32_t *)(MAGE_SEL_OUT_PEA_START_ADDR));\n")
            f.write("uint32_t *mage_load_stream     = ((int32_t *)(MAGE_LOAD_AGE_SEL_ADDR));\n")
            f.write("uint32_t *mage_store_stream    = ((int32_t *)(MAGE_PEA_DMEM_SEL_ADDR));\n")
            f.write("uint32_t *mage_agu             = ((int32_t *)(MAGE_CFG_START_ADDR));\n")
            f.write("uint32_t *mage_age_strides     = ((int32_t *)(MAGE_STRIDES_START_ADDR));\n")
            f.write("uint32_t *mage_stride_mode     = ((int32_t *)(MAGE_STRIDE_MODE_START_ADDR));\n")
            f.write("uint32_t *mage_acc_hwlp_sel    = ((int32_t *)(MAGE_ACC_HWLP_SEL_START_ADDR));\n")
            f.write("uint32_t *mage_pea             = ((int32_t *)(MAGE_PEA_CFG_START_ADDR));\n")
            f.write("uint32_t *mage_pea_constants   = ((int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR));\n\n")
%endif
%if streaming_cgra == 1:
            #------------------------------#
            #          Variables           #
            #------------------------------#
            f.write("uint32_t *mage_pea             = (int32_t *)(MAGE_PEA_CFG_START_ADDR);\n")
            f.write("uint32_t *mage_sel_out_pea     = (int32_t *)(MAGE_COL_RES_SEL_START_ADDR);\n")
            f.write("uint32_t *mage_pe_acc_values   = (int32_t *)(MAGE_ACC_VALUES_START_ADDR);\n")
            f.write("uint32_t *mage_pea_constants   = (int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR);\n\n")
%endif
            #------------------------------#
            #         Kernel Name          #
            #------------------------------#
            f.write("void" + " mage_" + appName + "_cfg(){\n")
%if dae_cgra == 1:
            #------------------------------#
            #  General Configuration Bits  #
            #------------------------------#
            if (int(str(self.generalConfiguration["ii"]), 10) != 0):
                iiStr = "\tuint32_t ii = " + hex(int(str(self.generalConfiguration["ii"]), 10)) + ";\n"
                f.write(iiStr)
                f.write("\t*mage_gen_cfg |= ii;\n")
    %if format_part == 1:
            if (int(str(self.generalConfiguration["vecMode"]), 10) != 0):
                vecModeStr = "\tuint32_t vecMode = " + hex(int(str(self.generalConfiguration["vecMode"]), 10)) + ";\n"
                f.write(vecModeStr)
                f.write("\t*mage_gen_cfg |= vecMode << 9;\n")
    %endif
    %if kernel_len != 1:
            aguSnrStr = "\tuint32_t agu_snt = " + hex(int(str(self.generalConfiguration["agu_snt"]), 10)) + ";\n"
            f.write(aguSnrStr)
            f.write("\t*mage_agu_snt |= agu_snt << 4;\n")
            peaSntStr = "\tuint32_t pea_snt = " + hex(int(str(self.generalConfiguration["pea_snt"]), 10)) + ";\n"
            f.write(peaSntStr)
            f.write("\t*mage_pea_snt |= pea_snt << 5;\n")
            selOutPeaSntStr = "\tuint32_t sel_out_pea_snt = " + hex(int(str(self.generalConfiguration["sel_out_pea_snt"]), 10)) + ";\n"
            f.write(selOutPeaSntStr)
            f.write("\t*mage_sel_out_pea_snt |= sel_out_pea_snt << 6;\n")
            loadStreamSntStr = "\tuint32_t load_stream_snt = " + hex(int(str(self.generalConfiguration["load_stream_snt"]), 10)) + ";\n"
            f.write(loadStreamSntStr)
            f.write("\t*mage_load_stream_snt |= load_stream_snt << 7;\n")
            streamStreamSntStr = "\tuint32_t stream_stream_snt = " + hex(int(str(self.generalConfiguration["stream_stream_snt"]), 10)) + ";\n"
            f.write(streamStreamSntStr)
            f.write("\t*mage_stream_stream_snt |= stream_stream_snt << 8;\n")
    %endif
            #------------------------------#
            #             HWLP             #
            #------------------------------#
            f.write("\n\t//Mage Hardware Loops configuration bits\n")
            # Loop i lives in bits [8*i+7:8*i] of each register (ILB_i/FLB_i/INC_i
            # in mage_regs.hjson), loop 0 being the innermost one in hwlp.sv.
            for arr_name in ["ilb", "flb", "li"]:
                values = [int(self.hwlpConfiguration[arr_name][i]) for i in range(4)]
                for i, v in enumerate(values):
                    if not 0 <= v <= 0xFF:
                        raise ValueError(f"{arr_name}[{i}] = {v} does not fit in 8 bits")
                word = sum(v << (8 * i) for i, v in enumerate(values))
                if word != 0:
                    f.write(f"\tmage_hwl_{arr_name}[0] = {word:#010x};\n")
            f.write("\n")

            #------------------------------#
            #             PKE              #
            #------------------------------#

%if kernel_len != 1:
            pSizeStr = "\tuint32_t p = " + hex(int(str(self.pkeConfiguration["pSize"]), 10)) + ";\n"
            f.write(pSizeStr)

            kSizeStr = "\tuint32_t k = " + hex(int(str(self.pkeConfiguration["kSize"]), 10)) + ";\n"
            f.write(kSizeStr)

            eSizeStr = "\tuint32_t e = " + hex(int(str(self.pkeConfiguration["eSize"]), 10)) + ";\n"
            f.write(eSizeStr)

            lenDfgStr = "\tuint32_t lenDfg = " + hex(int(str(self.pkeConfiguration["lenDfg"]), 10)) + ";\n"
            f.write(lenDfgStr)
            f.write("\t*mage_pke  = p;\n")
            f.write("\t*mage_pke |= k << 4;\n")
            f.write("\t*mage_pke |= e << 8;\n")
            f.write("\t*mage_pke |= lenDfg << 8;\n")
%endif

            #------------------------------#
            #      AGU Configuration       #
            #------------------------------#
            f.write("\n\t//Mage AGU Configuration\n")
            tmpList = {}
            for j in range(len(self.n_age_per_stream_ds)):
                if j not in tmpList:
                    tmpList[j] = {}
                for k in range(self.n_age_per_stream_ds[j]):
                    if k not in tmpList[j]:
                        tmpList[j][k] = {}
                    for i in range(self.kernelLength):
                        if i not in tmpList[j][k]:
                            tmpList[j][k][i] = self.binAguConfiguration[i][j][k]

            # consider each enty of tmpList as a 32-bit value and convert it to hexadecimal
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    for i in range(self.kernelLength):
                        tmpList[j][k][i] = hex(int(tmpList[j][k][i], 2))

            addr = 0
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    for i in range(self.kernelLength):
                        if tmpList[j][k][i] != "0x0":
                            f.write("\tmage_agu[" + str((addr)*self.kernelLength+i) + "] = " + tmpList[j][k][i] + ";\n")
                    addr += 1

            #------------------------------#
            #          AGE Strides         #
            #------------------------------#
            f.write("\n\t//Mage AGU Strides\n")
            addr = 0
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    if self.ageIvConstraints[0][j][k] != "none":
                        f.write("\tmage_age_strides[" + str(addr) + "] = " + hex(int(self.ageIvConstraints[0][j][k], 2)) + ";\n")
                    addr += 1
            f.write("\n")

            #------------------------------#
            #        AGE Stride Mode       #
            #------------------------------#
            f.write("\n\t//Mage AGU Stride Mode\n")
            addr = 0
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    if self.ageStrideModes[0][j][k] != "none":
                        f.write("\tmage_stride_mode[" + str(addr) + "] = " + hex(int(self.ageStrideModes[0][j][k], 2)) + ";\n")
                    addr += 1
            f.write("\n")

            #------------------------------#
            #       AGE Acc Hwlp Sel       #
            #------------------------------#
            # 8 AGEs are packed per ACC_HWLP_SEL register (4 bits each).
            f.write("\n\t//Mage AGU Acc Hwlp Sel\n")
            addr = 0
            accHwlpSelRegs = {}
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    if self.ageAccHwlpSel[0][j][k] != "none":
                        regIdx = addr // 8
                        shift = (addr % 8) * 4
                        if regIdx not in accHwlpSelRegs:
                            accHwlpSelRegs[regIdx] = 0
                        accHwlpSelRegs[regIdx] |= int(self.ageAccHwlpSel[0][j][k], 2) << shift
                    addr += 1
            for regIdx in sorted(accHwlpSelRegs.keys()):
                if accHwlpSelRegs[regIdx] != 0:
                    f.write("\tmage_acc_hwlp_sel[" + str(regIdx) + "] = " + hex(accHwlpSelRegs[regIdx]) + ";\n")
            f.write("\n")

            #------------------------------#
            #  Load Streams Configuration  #
            #------------------------------#
            # LOAD_AGE_SEL / PEA_DMEM_SEL / OUT_PEA_SEL are read by
            # peripheral_regs.sv.tpl as consecutive fixed-width fields starting
            # from bit 0, field index = s * kernel_len + t.
            f.write("\n\t//Mage Load Stream Configuration\n")
            fields = []
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    for i in range(self.kernelLength):
                        fields.append(self.binLoadStreamConfiguration[i][j][k])
            self._writePackedFields(f, "mage_load_stream", "loadStreamConfig", fields, self.nbitSelLoadStream)

            #------------------------------#
            # Store Streams Configuration  #
            #------------------------------#
            f.write("\n\t//Mage Store Stream Configuration\n")
            fields = []
            for j in range(len(self.n_age_per_stream_ds)):
                for k in range(self.n_age_per_stream_ds[j]):
                    for i in range(self.kernelLength):
                        fields.append(self.binStoreStreamConfiguration[i][j][k])
            self._writePackedFields(f, "mage_store_stream", "storeStreamConfig", fields, self.nbitSelStoreStream)

            #------------------------------#
            #     PEA Output Selection     #
            #------------------------------#
            # Output port s feeds store port/bank s and reads row s % peaRows
            # (pea.sv.tpl), so the left port of row r is s = r and the right
            # port is s = peaRows + r.
            f.write("\n\t//Mage Selection of Row Output Configuration\n")
            fields = []
            for side in range(2):
                for j in range(self.peaRows):
                    for i in range(self.kernelLength):
                        fields.append(self.binSelPeaColOutputConfiguration[i][str(j) + str(side)])
            self._writePackedFields(f, "mage_sel_out_pea", "selOutPeaConfig", fields, self.nbitSelOutPeaRow)

%endif
%if streaming_cgra == 1:
            #------------------------------#
            #     PEA Output Selection     #
            #------------------------------#
            f.write("\n\t//Mage Selection of Column Output Configuration\n")
            fullString = ""
            for j in range(self.peaCols):
                peaOutputId = str(j)
                fullString = self.binSelPeaRowOutputConfiguration[peaOutputId] + fullString

            tmpList = {}
            numConfigSelOutPeaRow = m.ceil((self.kernelLength*self.peaCols*8)/32)
            for i in range(numConfigSelOutPeaRow):
                if i not in tmpList:
                    tmpList[i] = ""
                tmpList[i] = fullString[i*32:(i+1)*32]

            for i in range(numConfigSelOutPeaRow):
                tmpList[i] = hex(int(tmpList[i], 2))

            selOutPeaConfigString = "\tuint32_t selOutPeaConfig[" + str(numConfigSelOutPeaRow) + "] = {"
            for i in range(numConfigSelOutPeaRow - 1, -1, -1):
                if i == 0:
                    selOutPeaConfigString += tmpList[i] + "};\n"
                else:
                    selOutPeaConfigString += tmpList[i] + ", "
            f.write(selOutPeaConfigString)
            for i in range(0, numConfigSelOutPeaRow):
                f.write("\tmage_sel_out_pea[" + str(i) + "] = selOutPeaConfig[" + str(i) + "];\n")
            f.write("\n")

            #------------------------------#
            #   PEs Accumulation Values    #
            #------------------------------#
            f.write("\n\t//Mage PEA Accumulation Values\n")
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    if self.peaAccValues[j][k] != 0:
                        if isinstance(self.peaAccValues[j][k], str):
                            f.write("\tmage_pe_acc_values[" + str(j*self.peaCols+k) + "] = " + self.peaAccValues[j][k] + ";\n")
                        else:
                            f.write("\tmage_pe_acc_values[" + str(j*self.peaCols+k) + "] = " + hex(self.binPeaAccValues[j][k]) + ";\n")
            f.write("\n")
%endif
            
            #------------------------------#
            #        PEs Constants         #
            #------------------------------#
            f.write("\n\t//Mage PEA Constants\n")
            for j in range(self.peaRows):
                for k in range(self.peaCols):
                    if self.peaConstants[j][k] != 0:
                        if isinstance(self.peaConstants[j][k], str):
                            f.write("\tmage_pea_constants[" + str(j*self.peaCols+k) + "] = " + self.peaConstants[j][k] + ";\n")
                        else:
                            f.write("\tmage_pea_constants[" + str(j*self.peaCols+k) + "] = " + hex(self.binPeaConstants[j][k]) + ";\n")
            f.write("\n")

            #------------------------------#
            #      PEA Configuration       #
            #------------------------------#
            f.write("\n\t//PEA Configuration\n")

            for i in range(self.kernelLength):
                for j in range(self.peaRows):
                    for k in range(self.peaCols):
                        peId = str(j) + str(k)
                        if (int(self.binPeaConfiguration[i][peId], 2) != 0):
                            f.write("\tmage_pea[" + str(j*self.peaCols+k) + "] = " + hex(int(self.binPeaConfiguration[i][peId], 2)) + ";\n")

            f.write("}\n")