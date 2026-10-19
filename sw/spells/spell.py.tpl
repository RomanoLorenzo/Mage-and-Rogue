# spell.py — kernel configuration script for Mage/Rogue CGRA
#
# This file is generated from spell.py.tpl by spell-gen.py.
# Fill in the define* functions below to describe the mapping of your kernel
# onto the CGRA, then run:
#
#     python3 spell.py
#
# to produce spell.c, which contains the C function mage_<app>_cfg() that
# programs the hardware via MMIO register writes.
#
# Workflow:
#   1. Edit the define* functions to match your algorithm mapping.
#   2. Run spell.py → generates spell.c.
#   3. Include spell.c in your firmware and call mage_<app>_cfg() before
#      starting the CGRA.

import os

from MageSpellBuilder import *

# Kernel name used for the generated C function mage_<APP_NAME>_cfg(); defaults
# to the name of the directory holding this spell.
SPELL_DIR = os.path.dirname(os.path.abspath(__file__))
APP_NAME = os.path.basename(SPELL_DIR)

#------------------------------#
#       Utils Constants        #
#------------------------------#
# Vector mode: controls how many 8-bit lanes are active inside each PE.
#   VEC_MODE_32 — one 32-bit element per PE (no vectorisation)
#   VEC_MODE_16 — two 16-bit elements packed per PE
#   VEC_MODE_8  — four 8-bit elements packed per PE
# The *_BIN variants are the 2-bit binary encodings written to hardware.
VEC_MODE_8  = 8
VEC_MODE_16 = 16
VEC_MODE_32 = 32
VEC_MODE_8_BIN  = 1   # 01b
VEC_MODE_16_BIN = 2   # 10b
VEC_MODE_32_BIN = 0   # 00b
%for r in range(n_pea_rows):
PEA_ROW_${r}_OUT_LEFT = "${r}0"
PEA_ROW_${r}_OUT_RIGHT = "${r}1"
%endfor
%for r in range(n_streams):
PE_GROUP_${r} = ${r}
AGE_GROUP_${r} = ${r} 
BANK_GROUP_${r} = ${r}
%endfor
%for c in range(n_age_per_stream):
PE_ID_${c} = ${c}
AGE_ID_${c} = ${c}
BANK_ID_${c} = ${c}
%endfor
%for r in range(n_pea_rows):
    %for c in range(n_pea_cols):
PE_${r}_${c} = "${r}${c}"
    %endfor
%endfor
%for r in range(n_pea_rows):
PEA_ROW_${r} = ${r}
%endfor
%for c in range(n_pea_cols):
PEA_COL_${c} = ${c}
%endfor
%if streaming_cgra == 1:
NO_OUTPUT = ${n_pea_rows}
%endif

#------------------------------#
#           PEA ISA            #
#------------------------------#
# Each PE executes one operation per cycle selected from the ISA below.
# The encoding is a 5-bit binary string written into the PE configuration word.
%if activation_computation == 1:
NOP       = "00000"
ABS       = "00001"
ADD       = "00010"
SUB       = "00011"
MUL       = "00100"
LSH       = "00101"
ARSH      = "00110"
LRSH      = "00111"
MAX       = "01000"
MIN       = "01001"
DIV       = "01010"
REM       = "01011"
ACC       = "01100"
MAXS      = "01101"
SHACC     = "01110"
SGNSEL    = "01111"
ABSDIV    = "10000"
ABSMIN    = "10001"
ABSREM    = "10010"
ADDPOW    = "10011"
SUBPOW    = "10100"
SGNCSUB   = "10101"
CADDMUL   = "10110"
ADDCMUL   = "10111"
CMULADD   = "11000"
CADDDIV   = "11001"
MULCARSH  = "11010"
CLSHSUB   = "11011"
BPSEL     = "11100"
CMULADD_PW = "11101"
CLIP      = "11110"
%elif gemm_computation == 1:
NOP       = "00000"
MUL       = "00001"
SUB       = "00010"
LSH       = "00011"
LRSH      = "00100"
ARSH      = "00101"
MAX       = "00110"
MIN       = "00111"
ABS       = "01000"
ACC       = "01001"
ADD       = "01010"
FW_A      = "01011"
FW_B      = "01100"
MULH      = "01101"
%endif

#------------------------------#
#  PEA Interconnection Scheme  #
#------------------------------#
# Each PE has two input mux selects (input0, input1), each encoded as a 4-bit
# binary string.  The mux options are:
#
#   Streaming mode (Rogue):
#     CONSTANT    — use the PE's constant register
#     STREAM_IN0..N — data arriving from DMA stream input N
#     UP/LEFT/RIGHT/DOWN — data from the neighbouring PE in that direction
#     SELF        — feedback from this PE's own output register
#     RF          — data from the PE's local register file
#     DELAY_OP    — delayed operand (activation mode only)
#
#   DAE mode (Mage):
#     CONSTANT    — use the PE's constant register
#     MEM_IN_0..N — data loaded from internal SRAM bank N by an AGE
#     UP/LEFT/RIGHT/DOWN — neighbouring PE
#     SELF        — own output feedback
%if  streaming_cgra == 1:
CONSTANT   = "0000"
  %for i in range(n_pe_in_stream):
STREAM_IN${i} = "${'{:04b}'.format(i+1)}"
  %endfor
UP         = "${'{:04b}'.format(n_pe_in_stream+1)}"
LEFT       = "${'{:04b}'.format(n_pe_in_stream+2)}"
RIGHT      = "${'{:04b}'.format(n_pe_in_stream+3)}"
DOWN       = "${'{:04b}'.format(n_pe_in_stream+4)}"
SELF       = "${'{:04b}'.format(n_pe_in_stream+5)}"
RF         = "${'{:04b}'.format(n_pe_in_stream+6)}"
  %if activation_computation == 1:
# DELAY_OP is only a valid input-mux choice under the activation ISA (the
# opcode table that defines it), even though the delayOpSel config-word
# field itself exists whenever has_delay_pe == 1 (see below).
DELAY_OP   = "${'{:04b}'.format(n_pe_in_stream+7)}"
  %endif
%elif dae_cgra == 1:
CONSTANT   = "0000"
  %for i in range(n_pe_in_mem):
MEM_IN_${i} = "${'{:04b}'.format(i+1)}"
  %endfor
UP         = "${'{:04b}'.format(n_pe_in_mem+1)}"
LEFT       = "${'{:04b}'.format(n_pe_in_mem+2)}"
RIGHT      = "${'{:04b}'.format(n_pe_in_mem+3)}"
DOWN       = "${'{:04b}'.format(n_pe_in_mem+4)}"
SELF       = "${'{:04b}'.format(n_pe_in_mem+5)}"
# DELAY_OP is always a valid input-mux choice in DAE mode (not gated on
# gemm_computation vs activation_computation in pea_pkg.sv.tpl).
DELAY_OP   = "${'{:04b}'.format(n_pe_in_mem+6)}"
%endif

%if has_delay_pe == 1:
#------------------------------#
#        Delay Operands        #
#------------------------------#
# When a PE's input mux selects DELAY_OP, these 4-bit constants specify which
# neighbouring PE output to delay and which of that PE's internal operands
# (result / input A / input B) to capture.
# Encoding (MSB->LSB): [operand(2)] [direction(2)]
#   directions: UP=00, LEFT=01, RIGHT=10, DOWN=11
#   operands:   NONE=00, RES=01, A=10, B=11
D_UP_OP_NONE     = "0000"
D_UP_OP_RES      = "0100"
D_UP_OP_A        = "1000"
D_UP_OP_B        = "1100"
D_LEFT_OP_NONE   = "0001"
D_LEFT_OP_RES    = "0101"
D_LEFT_OP_A      = "1001"
D_LEFT_OP_B      = "1101"
D_RIGHT_OP_NONE  = "0010"
D_RIGHT_OP_RES   = "0110"
D_RIGHT_OP_A     = "1010"
D_RIGHT_OP_B     = "1110"
D_DOWN_OP_NONE   = "0011"
D_DOWN_OP_RES    = "0111"
D_DOWN_OP_A      = "1011"
D_DOWN_OP_B      = "1111"
%endif

%if dae_cgra == 1:
#------------------------------#
#             HWLP             #
#------------------------------#
# Hardware loop configuration for up to 4 loop levels.
# Index i of each list is hardware loop i, the same i used by {i} in the AGE
# address expressions; loop 0 is the innermost loop.
# Set ilb (initial), flb (final, 0-based so N-1 for N iterations), and li
# (increment) for each loop, all 8-bit values.  Unused loops stay at [0,0,0].
def defineHwlpConfiguration(mage):
    ilb = [0, 0, 0, 0]
    flb = [0, 0, 0, 0]
    li  = [0, 0, 0, 0]
    mage.insertHwlpConfiguration(ilb, flb, li)

%if kernel_len != 1:
#------------------------------#
#             PKE              #
#------------------------------#
# Pipelined Kernel Execution (PKE) — only for multi-kernel schedules.
# Specifies the prologue, steady-state, and epilogue lengths of the DFG.
def definePkeConfiguration(mage):
    mage.insertPkeConfiguration(0, 0, 0, 0, 0)
%endif

#------------------------------#
#  General Configuration Bits  #
#------------------------------#
# ii: Initiation interval (0 = don't set).
# vecMode: vector element width (VEC_MODE_32_BIN for 32-bit, etc.)
def defineGeneralConfiguration(mage):
%if kernel_len != 1:
    # prototype insertGeneralConfiguration(ii, vecMode, snt_agu, snt_pea, snt_pea_sel_out, snt_pea_load_stream, snt_pea_stream_stream)
    mage.insertGeneralConfiguration(0, VEC_MODE_32_BIN, 0, 0, 0, 0, 0)
%else:
    # prototype insertGeneralConfiguration(ii, vecMode)
    mage.insertGeneralConfiguration(0, VEC_MODE_32_BIN)
%endif
%endif

#------------------------------#
#      PEA Configuration       #
#------------------------------#
def definePeaConfigurations(mage):
# Which args are present, in order: input0, input1, operation, [vecMode if
# format_part], [enRF if streaming_cgra], [delayOpSel if has_delay_pe].
%if kernel_len != 1:
%if dae_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP)
        %endif
                %endfor
            %endfor
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, VEC_MODE_32)
        %endif
                %endfor
            %endfor
    %endif
%endif
%if streaming_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, enRF, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, enRF)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, 0, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, 0)
        %endif
                %endfor
            %endfor
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, enRF, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, time, rangeInit, rangeFinal, input0, input1, operation, vecMode, enRF)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, "all", 0, 0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0)
        %endif
                %endfor
            %endfor
    %endif
%endif
%else:
%if dae_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP)
        %endif
                %endfor
            %endfor
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, vecMode, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, vecMode)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, VEC_MODE_32, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, VEC_MODE_32)
        %endif
                %endfor
            %endfor
    %endif
%endif
%if streaming_cgra == 1:
    %if format_full == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, enRF, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, enRF)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, 0, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, 0)
        %endif
                %endfor
            %endfor
    %endif
    %if format_part == 1:
        %if has_delay_pe == 1:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, vecMode, enRF, delayOpSel)
        %else:
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, vecMode, enRF)
        %endif
            %for r in range(n_pea_rows):
                %for c in range(n_pea_cols):
    # Configurations for PE ${r}${c}
        %if has_delay_pe == 1:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
        %else:
    mage.insertPeConfiguration(PE_${r}_${c}, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0)
        %endif
                %endfor
            %endfor
    %endif
%endif
%endif

%if streaming_cgra == 1:
#------------------------------#
#     PEA Output Selection     #
#------------------------------#
# In streaming mode each PEA column has one output port.  This selector
# chooses which row's result is forwarded to the DMA output stream.
# NO_OUTPUT (= n_pea_rows) disables the output for that column.
def defineSelOutPeaRowConfigurations(mage):
    #prototype : insertSelOutPeaRowConfiguration(self, peaOutputId, peaSelectedRow)
    %for c in range(n_pea_cols):
	# Decide from which row take the output for PEA Col ${c}
    mage.insertSelOutPeaRowConfiguration("${c}", NO_OUTPUT)
    %endfor

#------------------------------#
#   PEs Accumulation Values    #
#------------------------------#
# For PEs using the ACC operation: initial value loaded into the accumulator
# at the start of each DMA transfer.  0 for standard sum-accumulation.
def definePeaAccValues(mage):
    #prototype : insertPeAccValue(self, peRow, peCol, accValue)
    %for r in range(n_pea_rows):
        %for c in range(n_pea_cols):
	# Accumulation Value for PE ${r}${c}
    mage.insertPeAccValue(PEA_ROW_${r}, PEA_COL_${c}, 0)
        %endfor
    %endfor
%endif

#------------------------------#
#        PEs Constants         #
#------------------------------#
def definePeaConstants(mage):
    #prototype : insertPeConstant(self, peRow, peCol, constant)
    %for r in range(n_pea_rows):
        %for c in range(n_pea_cols):
	# Constant for PE ${r}${c}
    mage.insertPeConstant(PEA_ROW_${r}, PEA_COL_${c}, 0)
        %endfor
    %endfor

%if dae_cgra == 1:
#------------------------------#
#  Load Streams Configuration  #
#------------------------------#
# Configures the crossbar between AGEs (that perform SRAM loads) and PEs.
# For each PE in each group, specify which AGE_ID delivers its data.
# PE_GROUP_i corresponds to the i-th stream/column group; PE_ID_j is the
# j-th PE within that group.
def defineLoadStreamConfigurations(mage):
%if kernel_len != 1:
    #prototype : insertLoadStreamConfiguration(self, time, rangeInit, rangeFinal, peGroup, peId, loadAgeId)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number ${j} in PE Group ${i}
    mage.insertLoadStreamConfiguration("all", 0, 0, PE_GROUP_${i}, PE_ID_${j}, AGE_ID_0)
        %endfor
    %endfor
%else:
    #prototype : insertLoadStreamConfiguration(self, peGroup, peId, loadAgeId)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number ${j} in PE Group ${i}
    mage.insertLoadStreamConfiguration(PE_GROUP_${i}, PE_ID_${j}, AGE_ID_0)
        %endfor
    %endfor
%endif

#------------------------------#
# Store Streams Configuration  #
#------------------------------#
# Configures the crossbar between PEA row outputs and AGEs (that perform SRAM
# stores).  For each bank slot in each group, specify which PE_ID's output
# to write.
def defineStoreStreamConfigurations(mage):
%if kernel_len != 1:
    #prototype : insertStoreStreamConfiguration(self, time, rangeInit, rangeFinal, peGroup, peId, storeAgeId)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank ${j} of group ${i}
    mage.insertStoreStreamConfiguration("all", 0, 0, BANK_GROUP_${i}, BANK_ID_${j}, PE_ID_0)
        %endfor
    %endfor
%else:
    #prototype : insertStoreStreamConfiguration(self, peGroup, peId, storeAgeId)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank ${j} of group ${i}
    mage.insertStoreStreamConfiguration(BANK_GROUP_${i}, BANK_ID_${j}, PE_ID_0)
        %endfor
    %endfor
%endif

#------------------------------#
#     PEA Output Selection     #
#------------------------------#
# In DAE mode each PEA row has two output ports (left and right).  The left
# port of row r drives store port/bank r and the right port drives store
# port/bank ${n_pea_rows} + r (only ports below n_age_tot = ${n_age_tot} exist).  This
# selector chooses which column of the row feeds the port.
def defineSelOutPeaColConfigurations(mage):
%if kernel_len != 1:
    #prototype : insertSelOutPeaColConfiguration(self, time, rangeInit, rangeFinal, peaOutputId, peaSelectedColumn)
    %for r in range(n_pea_rows):
	# Decide from which column take the output for PEA Row ${r} (both left and right side)
    mage.insertSelOutPeaColConfiguration("all", 0, 0, PEA_ROW_${r}_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration("all", 0, 0, PEA_ROW_${r}_OUT_RIGHT, PEA_COL_0)
    %endfor
%else:
    #prototype : insertSelOutPeaColConfiguration(self, peaOutputId, peaSelectedColumn)
    %for r in range(n_pea_rows):
	# Decide from which column take the output for PEA Row ${r} (both left and right side)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_${r}_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_${r}_OUT_RIGHT, PEA_COL_0)
    %endfor
%endif

def defineAguConfigurations(mage):
#------------------------------#
#      AGU Configuration       #
#------------------------------#
# Configure each Address Generation Engine (AGE).  The address expression
# follows the pattern: "Array[s0*{0}+s1*{1}+s2*{2}+s3*{3}+const]"
# where {i} are hardware loop induction variables and si are 8-bit stride
# values.  For an IV in tiled mode (strideModes[i] = 1) si is log2(Si), 0-7.
# Inactive AGEs (isActive=0) should use "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]".
%if kernel_len != 1:
    #prototype : insertAgeConfiguration(self, time, rangeInit, rangeFinal, streamId, ageId, loopSel, startBank, numBanks, blockSize, loadNotStore, selIvConstraint, isAccStore, isActive, array, strideModes=None, accHwlpSel=0)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
	# Configurations for AGU for Stream ${i} and Age ${j}
    mage.insertAgeConfiguration("all", 0, 0, AGE_GROUP_${i}, AGE_ID_${j}, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
        %endfor
    %endfor
%else:
    #prototype : insertAgeConfiguration(self, streamId, ageId, loopSel, startBank, numBanks, blockSize, loadNotStore, selIvConstraint, isAccStore, isActive, array, strideModes=None, accHwlpSel=0)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
	# Configurations for AGU for Stream ${i} and Age ${j}
    mage.insertAgeConfiguration(AGE_GROUP_${i}, AGE_ID_${j}, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
        %endfor
    %endfor
%endif
%endif

%if dae_cgra == 1:
def defineIvConstraints(mage):
#------------------------------#
#        IV Constraints        #
#------------------------------#
# IV constraints synchronise a store AGE with a load AGE: the store waits
# until the load's induction variable has advanced past a threshold.
# This prevents write-before-read hazards in pipelined kernels.
# Set to 0 for AGEs that require no synchronisation.
    #prototype : insertAgeIvConstraint(self, streamId, ageId, ivConstraint)
	%for i in range(len(n_age_per_stream_ds)):
        %for j in range(n_age_per_stream_ds[i]):
	# IV Constraint for AGE in Group ${i} of Id ${j}
    mage.insertAgeIvConstraint(AGE_GROUP_${i}, AGE_ID_${j}, 0)
        %endfor
    %endfor
%endif

def main():

    mage = MageSpellBuilder()
%if dae_cgra == 1:
    defineHwlpConfiguration(mage)
%if kernel_len != 1:
    definePkeConfiguration(mage)
%endif
    defineGeneralConfiguration(mage)
    defineLoadStreamConfigurations(mage)
    defineStoreStreamConfigurations(mage)
    defineSelOutPeaColConfigurations(mage)
    defineAguConfigurations(mage)
    defineIvConstraints(mage)
%endif
%if streaming_cgra == 1:
    defineSelOutPeaRowConfigurations(mage)
    definePeaAccValues(mage)
%endif
    definePeaConstants(mage)
    definePeaConfigurations(mage)

    mage.generateSpell()
    mage.generateCSpell(APP_NAME, os.path.join(SPELL_DIR, "spell.c"))

if __name__ == "__main__":
    main()
