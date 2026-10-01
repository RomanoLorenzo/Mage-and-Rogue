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
PEA_ROW_0_OUT_LEFT = "00"
PEA_ROW_0_OUT_RIGHT = "01"
PEA_ROW_1_OUT_LEFT = "10"
PEA_ROW_1_OUT_RIGHT = "11"
PEA_ROW_2_OUT_LEFT = "20"
PEA_ROW_2_OUT_RIGHT = "21"
PEA_ROW_3_OUT_LEFT = "30"
PEA_ROW_3_OUT_RIGHT = "31"
PE_0_0 = "00"
PE_0_1 = "01"
PE_0_2 = "02"
PE_0_3 = "03"
PE_1_0 = "10"
PE_1_1 = "11"
PE_1_2 = "12"
PE_1_3 = "13"
PE_2_0 = "20"
PE_2_1 = "21"
PE_2_2 = "22"
PE_2_3 = "23"
PE_3_0 = "30"
PE_3_1 = "31"
PE_3_2 = "32"
PE_3_3 = "33"
PEA_ROW_0 = 0
PEA_ROW_1 = 1
PEA_ROW_2 = 2
PEA_ROW_3 = 3
PEA_COL_0 = 0
PEA_COL_1 = 1
PEA_COL_2 = 2
PEA_COL_3 = 3
NO_OUTPUT = 4

#------------------------------#
#           PEA ISA            #
#------------------------------#
# Each PE executes one operation per cycle selected from the ISA below.
# The encoding is a 5-bit binary string written into the PE configuration word.
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
CONSTANT   = "0000"
STREAM_IN0 = "0001"
STREAM_IN1 = "0010"
STREAM_IN2 = "0011"
STREAM_IN3 = "0100"
UP         = "0101"
LEFT       = "0110"
RIGHT      = "0111"
DOWN       = "1000"
SELF       = "1001"
RF         = "1010"
# DELAY_OP is only a valid input-mux choice under the activation ISA (the
# opcode table that defines it), even though the delayOpSel config-word
# field itself exists whenever has_delay_pe == 1 (see below).
DELAY_OP   = "1011"

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


#------------------------------#
#      PEA Configuration       #
#------------------------------#
def definePeaConfigurations(mage):
# Which args are present, in order: input0, input1, operation, [vecMode if
# format_part], [enRF if streaming_cgra], [delayOpSel if has_delay_pe].
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, vecMode, enRF, delayOpSel)
    # Configurations for PE 00
    mage.insertPeConfiguration(PE_0_0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 01
    mage.insertPeConfiguration(PE_0_1, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 02
    mage.insertPeConfiguration(PE_0_2, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 03
    mage.insertPeConfiguration(PE_0_3, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 10
    mage.insertPeConfiguration(PE_1_0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 11
    mage.insertPeConfiguration(PE_1_1, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 12
    mage.insertPeConfiguration(PE_1_2, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 13
    mage.insertPeConfiguration(PE_1_3, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 20
    mage.insertPeConfiguration(PE_2_0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 21
    mage.insertPeConfiguration(PE_2_1, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 22
    mage.insertPeConfiguration(PE_2_2, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 23
    mage.insertPeConfiguration(PE_2_3, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 30
    mage.insertPeConfiguration(PE_3_0, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 31
    mage.insertPeConfiguration(PE_3_1, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 32
    mage.insertPeConfiguration(PE_3_2, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)
    # Configurations for PE 33
    mage.insertPeConfiguration(PE_3_3, CONSTANT, CONSTANT, NOP, VEC_MODE_32, 0, D_UP_OP_NONE)

#------------------------------#
#     PEA Output Selection     #
#------------------------------#
# In streaming mode each PEA column has one output port.  This selector
# chooses which row's result is forwarded to the DMA output stream.
# NO_OUTPUT (= n_pea_rows) disables the output for that column.
def defineSelOutPeaRowConfigurations(mage):
    #prototype : insertSelOutPeaRowConfiguration(self, peaOutputId, peaSelectedRow)
	# Decide from which row take the output for PEA Col 0
    mage.insertSelOutPeaRowConfiguration("0", NO_OUTPUT)
	# Decide from which row take the output for PEA Col 1
    mage.insertSelOutPeaRowConfiguration("1", NO_OUTPUT)
	# Decide from which row take the output for PEA Col 2
    mage.insertSelOutPeaRowConfiguration("2", NO_OUTPUT)
	# Decide from which row take the output for PEA Col 3
    mage.insertSelOutPeaRowConfiguration("3", NO_OUTPUT)

#------------------------------#
#   PEs Accumulation Values    #
#------------------------------#
# For PEs using the ACC operation: initial value loaded into the accumulator
# at the start of each DMA transfer.  0 for standard sum-accumulation.
def definePeaAccValues(mage):
    #prototype : insertPeAccValue(self, peRow, peCol, accValue)
	# Accumulation Value for PE 00
    mage.insertPeAccValue(PEA_ROW_0, PEA_COL_0, 0)
	# Accumulation Value for PE 01
    mage.insertPeAccValue(PEA_ROW_0, PEA_COL_1, 0)
	# Accumulation Value for PE 02
    mage.insertPeAccValue(PEA_ROW_0, PEA_COL_2, 0)
	# Accumulation Value for PE 03
    mage.insertPeAccValue(PEA_ROW_0, PEA_COL_3, 0)
	# Accumulation Value for PE 10
    mage.insertPeAccValue(PEA_ROW_1, PEA_COL_0, 0)
	# Accumulation Value for PE 11
    mage.insertPeAccValue(PEA_ROW_1, PEA_COL_1, 0)
	# Accumulation Value for PE 12
    mage.insertPeAccValue(PEA_ROW_1, PEA_COL_2, 0)
	# Accumulation Value for PE 13
    mage.insertPeAccValue(PEA_ROW_1, PEA_COL_3, 0)
	# Accumulation Value for PE 20
    mage.insertPeAccValue(PEA_ROW_2, PEA_COL_0, 0)
	# Accumulation Value for PE 21
    mage.insertPeAccValue(PEA_ROW_2, PEA_COL_1, 0)
	# Accumulation Value for PE 22
    mage.insertPeAccValue(PEA_ROW_2, PEA_COL_2, 0)
	# Accumulation Value for PE 23
    mage.insertPeAccValue(PEA_ROW_2, PEA_COL_3, 0)
	# Accumulation Value for PE 30
    mage.insertPeAccValue(PEA_ROW_3, PEA_COL_0, 0)
	# Accumulation Value for PE 31
    mage.insertPeAccValue(PEA_ROW_3, PEA_COL_1, 0)
	# Accumulation Value for PE 32
    mage.insertPeAccValue(PEA_ROW_3, PEA_COL_2, 0)
	# Accumulation Value for PE 33
    mage.insertPeAccValue(PEA_ROW_3, PEA_COL_3, 0)

#------------------------------#
#        PEs Constants         #
#------------------------------#
def definePeaConstants(mage):
    #prototype : insertPeConstant(self, peRow, peCol, constant)
	# Constant for PE 00
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_0, 0)
	# Constant for PE 01
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_1, 0)
	# Constant for PE 02
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_2, 0)
	# Constant for PE 03
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_3, 0)
	# Constant for PE 10
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_0, 0)
	# Constant for PE 11
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_1, 0)
	# Constant for PE 12
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_2, 0)
	# Constant for PE 13
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_3, 0)
	# Constant for PE 20
    mage.insertPeConstant(PEA_ROW_2, PEA_COL_0, 0)
	# Constant for PE 21
    mage.insertPeConstant(PEA_ROW_2, PEA_COL_1, 0)
	# Constant for PE 22
    mage.insertPeConstant(PEA_ROW_2, PEA_COL_2, 0)
	# Constant for PE 23
    mage.insertPeConstant(PEA_ROW_2, PEA_COL_3, 0)
	# Constant for PE 30
    mage.insertPeConstant(PEA_ROW_3, PEA_COL_0, 0)
	# Constant for PE 31
    mage.insertPeConstant(PEA_ROW_3, PEA_COL_1, 0)
	# Constant for PE 32
    mage.insertPeConstant(PEA_ROW_3, PEA_COL_2, 0)
	# Constant for PE 33
    mage.insertPeConstant(PEA_ROW_3, PEA_COL_3, 0)



def main():

    mage = MageSpellBuilder()
    defineSelOutPeaRowConfigurations(mage)
    definePeaAccValues(mage)
    definePeaConstants(mage)
    definePeaConfigurations(mage)

    mage.generateSpell()
    mage.generateCSpell(APP_NAME, os.path.join(SPELL_DIR, "spell.c"))

if __name__ == "__main__":
    main()
