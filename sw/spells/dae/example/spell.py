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
PE_GROUP_0 = 0
AGE_GROUP_0 = 0
BANK_GROUP_0 = 0
PE_GROUP_1 = 1
AGE_GROUP_1 = 1
BANK_GROUP_1 = 1
PE_GROUP_2 = 2
AGE_GROUP_2 = 2
BANK_GROUP_2 = 2
PE_GROUP_3 = 3
AGE_GROUP_3 = 3
BANK_GROUP_3 = 3
PE_ID_0 = 0
AGE_ID_0 = 0
BANK_ID_0 = 0
PE_ID_1 = 1
AGE_ID_1 = 1
BANK_ID_1 = 1
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

#------------------------------#
#           PEA ISA            #
#------------------------------#
# Each PE executes one operation per cycle selected from the ISA below.
# The encoding is a 5-bit binary string written into the PE configuration word.
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
MEM_IN_0 = "0001"
MEM_IN_1 = "0010"
MEM_IN_2 = "0011"
MEM_IN_3 = "0100"
UP         = "0101"
LEFT       = "0110"
RIGHT      = "0111"
DOWN       = "1000"
SELF       = "1001"
# DELAY_OP is always a valid input-mux choice in DAE mode (not gated on
# gemm_computation vs activation_computation in pea_pkg.sv.tpl).
DELAY_OP   = "1010"

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
#             HWLP             #
#------------------------------#
# Hardware loop configuration for up to 4 loop levels.
# Set ilb (initial), flb (final, 0-based so N-1 for N iterations), and li
# (increment) for each loop.  Unused loops stay at [0,0,0].
def defineHwlpConfiguration(mage):
    # Loop 0 runs 8 iterations (0-based final bound = 7), step 1.
    ilb = [0, 0, 0, 0]
    flb = [7, 0, 0, 0]
    li  = [1, 0, 0, 0]
    mage.insertHwlpConfiguration(ilb, flb, li)


#------------------------------#
#  General Configuration Bits  #
#------------------------------#
# ii: Initiation interval (0 = don't set).
# vecMode: vector element width (VEC_MODE_32_BIN for 32-bit, etc.)
def defineGeneralConfiguration(mage):
    # prototype insertGeneralConfiguration(ii, vecMode)
    mage.insertGeneralConfiguration(0, VEC_MODE_32_BIN)

#------------------------------#
#      PEA Configuration       #
#------------------------------#
def definePeaConfigurations(mage):
# Which args are present, in order: input0, input1, operation, [vecMode if
# format_part], [enRF if streaming_cgra], [delayOpSel if has_delay_pe].
    #prototype: insertPeConfiguration(self, peId, input0, input1, operation, delayOpSel)
    # Configurations for PE 00: add the value loaded from MEM_IN_0 to its constant
    mage.insertPeConfiguration(PE_0_0, MEM_IN_0, CONSTANT, ADD, D_UP_OP_NONE)
    # Configurations for PE 01
    mage.insertPeConfiguration(PE_0_1, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 02
    mage.insertPeConfiguration(PE_0_2, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 03
    mage.insertPeConfiguration(PE_0_3, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 10
    mage.insertPeConfiguration(PE_1_0, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 11: multiply its UP neighbour's output by its constant
    mage.insertPeConfiguration(PE_1_1, UP, CONSTANT, MUL, D_UP_OP_NONE)
    # Configurations for PE 12
    mage.insertPeConfiguration(PE_1_2, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 13
    mage.insertPeConfiguration(PE_1_3, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 20
    mage.insertPeConfiguration(PE_2_0, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 21
    mage.insertPeConfiguration(PE_2_1, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 22
    mage.insertPeConfiguration(PE_2_2, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 23
    mage.insertPeConfiguration(PE_2_3, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 30
    mage.insertPeConfiguration(PE_3_0, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 31
    mage.insertPeConfiguration(PE_3_1, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 32
    mage.insertPeConfiguration(PE_3_2, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)
    # Configurations for PE 33
    mage.insertPeConfiguration(PE_3_3, CONSTANT, CONSTANT, NOP, D_UP_OP_NONE)


#------------------------------#
#        PEs Constants         #
#------------------------------#
def definePeaConstants(mage):
    #prototype : insertPeConstant(self, peRow, peCol, constant)
	# Constant for PE 00
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_0, 5)
	# Constant for PE 01
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_1, 0)
	# Constant for PE 02
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_2, 0)
	# Constant for PE 03
    mage.insertPeConstant(PEA_ROW_0, PEA_COL_3, 0)
	# Constant for PE 10
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_0, 0)
	# Constant for PE 11
    mage.insertPeConstant(PEA_ROW_1, PEA_COL_1, 10)
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

#------------------------------#
#  Load Streams Configuration  #
#------------------------------#
# Configures the crossbar between AGEs (that perform SRAM loads) and PEs.
# For each PE in each group, specify which AGE_ID delivers its data.
# PE_GROUP_i corresponds to the i-th stream/column group; PE_ID_j is the
# j-th PE within that group.
def defineLoadStreamConfigurations(mage):
    #prototype : insertLoadStreamConfiguration(self, peGroup, peId, loadAgeId)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 0 in PE Group 0
    mage.insertLoadStreamConfiguration(PE_GROUP_0, PE_ID_0, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 1 in PE Group 0
    mage.insertLoadStreamConfiguration(PE_GROUP_0, PE_ID_1, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 0 in PE Group 1
    mage.insertLoadStreamConfiguration(PE_GROUP_1, PE_ID_0, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 1 in PE Group 1
    mage.insertLoadStreamConfiguration(PE_GROUP_1, PE_ID_1, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 0 in PE Group 2
    mage.insertLoadStreamConfiguration(PE_GROUP_2, PE_ID_0, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 1 in PE Group 2
    mage.insertLoadStreamConfiguration(PE_GROUP_2, PE_ID_1, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 0 in PE Group 3
    mage.insertLoadStreamConfiguration(PE_GROUP_3, PE_ID_0, AGE_ID_0)
    # Configurations for Load Stream (Banks-PEA): decide which AGE performing load to connect to PE Number 1 in PE Group 3
    mage.insertLoadStreamConfiguration(PE_GROUP_3, PE_ID_1, AGE_ID_0)

#------------------------------#
# Store Streams Configuration  #
#------------------------------#
# Configures the crossbar between PEA row outputs and AGEs (that perform SRAM
# stores).  For each bank slot in each group, specify which PE_ID's output
# to write.
def defineStoreStreamConfigurations(mage):
    #prototype : insertStoreStreamConfiguration(self, peGroup, peId, storeAgeId)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 0 of group 0
    mage.insertStoreStreamConfiguration(BANK_GROUP_0, BANK_ID_0, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 1 of group 0
    mage.insertStoreStreamConfiguration(BANK_GROUP_0, BANK_ID_1, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 0 of group 1
    mage.insertStoreStreamConfiguration(BANK_GROUP_1, BANK_ID_0, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 1 of group 1
    mage.insertStoreStreamConfiguration(BANK_GROUP_1, BANK_ID_1, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 0 of group 2
    mage.insertStoreStreamConfiguration(BANK_GROUP_2, BANK_ID_0, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 1 of group 2
    mage.insertStoreStreamConfiguration(BANK_GROUP_2, BANK_ID_1, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 0 of group 3
    mage.insertStoreStreamConfiguration(BANK_GROUP_3, BANK_ID_0, PE_ID_0)
    # Configurations for Store Stream (Banks-PEA): decide which PEA row output (PE_ID_i) to connect to Bank 1 of group 3
    mage.insertStoreStreamConfiguration(BANK_GROUP_3, BANK_ID_1, PE_ID_0)

#------------------------------#
#     PEA Output Selection     #
#------------------------------#
# In DAE mode each PEA row has two output ports (left and right, used to feed
# two separate store AGEs).  This selector chooses which column's result is
# forwarded.  PEA_ROW_r_OUT_LEFT and _RIGHT are the two port identifiers.
def defineSelOutPeaColConfigurations(mage):
    #prototype : insertSelOutPeaColConfiguration(self, peaOutputId, peaSelectedColumn)
	# Decide from which column take the output for PEA Row 0 (both left and right side)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_0_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_0_OUT_RIGHT, PEA_COL_0)
	# Decide from which column take the output for PEA Row 1 (both left and right side)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_1_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_1_OUT_RIGHT, PEA_COL_0)
	# Decide from which column take the output for PEA Row 2 (both left and right side)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_2_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_2_OUT_RIGHT, PEA_COL_0)
	# Decide from which column take the output for PEA Row 3 (both left and right side)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_3_OUT_LEFT, PEA_COL_0)
    mage.insertSelOutPeaColConfiguration(PEA_ROW_3_OUT_RIGHT, PEA_COL_0)

def defineAguConfigurations(mage):
#------------------------------#
#      AGU Configuration       #
#------------------------------#
# Configure each Address Generation Engine (AGE).  The address expression
# follows the pattern: "Array[s0*{0}+s1*{1}+s2*{2}+s3*{3}+const]"
# where {i} are hardware loop induction variables and si are stride values.
# Inactive AGEs (isActive=0) should use "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]".
    #prototype : insertAgeConfiguration(self, streamId, ageId, loopSel, startBank, numBanks, blockSize, loadNotStore, selIvConstraint, isAccStore, isActive, array, strideModes=None, accHwlpSel=0)
	# Configurations for AGU for Stream 0 and Age 0: load AGE, one bank, driven by
	# loop 0, unconstrained (selIvConstraint = 4), linear addressing (default strideModes).
    mage.insertAgeConfiguration(AGE_GROUP_0, AGE_ID_0, 0, 0, 0, 0, 1, 4, 0, 1, "Array[1*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 0 and Age 1: accumulating store AGE.
	# Exercises the new strideModes (tiled addressing on IV0) and accHwlpSel
	# (selects HWLP RF entry 3 for the accumulation reset point) parameters.
    mage.insertAgeConfiguration(AGE_GROUP_0, AGE_ID_1, 0, 0, 0, 0, 0, 0, 1, 1, "Array[1*{0}+0*{1}+0*{2}+0*{3}+0]", strideModes=[1, 0, 0, 0], accHwlpSel=3)
	# Configurations for AGU for Stream 1 and Age 0
    mage.insertAgeConfiguration(AGE_GROUP_1, AGE_ID_0, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 1 and Age 1
    mage.insertAgeConfiguration(AGE_GROUP_1, AGE_ID_1, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 2 and Age 0
    mage.insertAgeConfiguration(AGE_GROUP_2, AGE_ID_0, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 2 and Age 1
    mage.insertAgeConfiguration(AGE_GROUP_2, AGE_ID_1, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 3 and Age 0
    mage.insertAgeConfiguration(AGE_GROUP_3, AGE_ID_0, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")
	# Configurations for AGU for Stream 3 and Age 1
    mage.insertAgeConfiguration(AGE_GROUP_3, AGE_ID_1, 0, 0, 0, 0, 0, 0, 0, 0, "Array[0*{0}+0*{1}+0*{2}+0*{3}+0]")

def defineIvConstraints(mage):
#------------------------------#
#        IV Constraints        #
#------------------------------#
# IV constraints synchronise a store AGE with a load AGE: the store waits
# until the load's induction variable has advanced past a threshold.
# This prevents write-before-read hazards in pipelined kernels.
# Set to 0 for AGEs that require no synchronisation.
    #prototype : insertAgeIvConstraint(self, streamId, ageId, ivConstraint)
	# IV Constraint for AGE in Group 0 of Id 0
    mage.insertAgeIvConstraint(AGE_GROUP_0, AGE_ID_0, 0)
	# IV Constraint for AGE in Group 0 of Id 1
    mage.insertAgeIvConstraint(AGE_GROUP_0, AGE_ID_1, 0)
	# IV Constraint for AGE in Group 1 of Id 0
    mage.insertAgeIvConstraint(AGE_GROUP_1, AGE_ID_0, 0)
	# IV Constraint for AGE in Group 1 of Id 1
    mage.insertAgeIvConstraint(AGE_GROUP_1, AGE_ID_1, 0)
	# IV Constraint for AGE in Group 2 of Id 0
    mage.insertAgeIvConstraint(AGE_GROUP_2, AGE_ID_0, 0)
	# IV Constraint for AGE in Group 2 of Id 1
    mage.insertAgeIvConstraint(AGE_GROUP_2, AGE_ID_1, 0)
	# IV Constraint for AGE in Group 3 of Id 0
    mage.insertAgeIvConstraint(AGE_GROUP_3, AGE_ID_0, 0)
	# IV Constraint for AGE in Group 3 of Id 1
    mage.insertAgeIvConstraint(AGE_GROUP_3, AGE_ID_1, 0)

def main():

    mage = MageSpellBuilder()
    defineHwlpConfiguration(mage)
    defineGeneralConfiguration(mage)
    defineLoadStreamConfigurations(mage)
    defineStoreStreamConfigurations(mage)
    defineSelOutPeaColConfigurations(mage)
    defineAguConfigurations(mage)
    defineIvConstraints(mage)
    definePeaConstants(mage)
    definePeaConfigurations(mage)

    mage.generateSpell()
    mage.generateCSpell(APP_NAME, os.path.join(SPELL_DIR, "spell.c"))

if __name__ == "__main__":
    main()
