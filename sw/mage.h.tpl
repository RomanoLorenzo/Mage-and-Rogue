#ifndef _MAGE_H_
#define _MAGE_H_
// MAGE_CFG_HJSON = ${mage_cfg_file}
#define MAGE_CFG_HJSON "${mage_cfg_file}"

#include <stdint.h>

#include "mage_params.h"
#include "mage_regs.h"

%if streaming_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                       Streaming Mage                       //
//                                                            //
////////////////////////////////////////////////////////////////
// number of 32-bit registers used to store PE accumulation values
#define PEA_ACC_VALUES_SIZE ${n_pea_rows}
%endif

#ifdef __cplusplus
extern "C"
{
#endif

void write_mage_register(uint32_t p_val, uintptr_t p_addr, uint32_t p_mask, uint8_t p_sel);

////////////////////////////////////////////////////////////////
//                    PE Instructions & Muxes                 //
////////////////////////////////////////////////////////////////
#define MAGE_PE_OP_NOP   0x00U
#define MAGE_PE_OP_MUL   0x01U
#define MAGE_PE_OP_SUB   0x02U
#define MAGE_PE_OP_LSH   0x03U
#define MAGE_PE_OP_LRSH  0x04U
#define MAGE_PE_OP_ARSH  0x05U
#define MAGE_PE_OP_MAX   0x06U
#define MAGE_PE_OP_MIN   0x07U
#define MAGE_PE_OP_ABS   0x08U
#define MAGE_PE_OP_ACC   0x09U
#define MAGE_PE_OP_ADD   0x0AU
#define MAGE_PE_OP_FW_A  0x0BU
#define MAGE_PE_OP_FW_B  0x0CU
#define MAGE_PE_OP_MULH  0x0DU

#define MAGE_PE_MUX_CONST      0x0U
%for i in range(n_pe_in_mem):
#define MAGE_PE_MUX_MEM_IN_${i}   ${hex(i+1)}U
%endfor
<% idx = n_pe_in_mem + 1 %>
%for neigh in pattern_neigh_pe:
#define MAGE_PE_MUX_${neigh}   ${hex(idx)}U
<% idx += 1 %>
%endfor
#define MAGE_PE_MUX_SELF       ${hex(idx)}U
<% idx += 1 %>
#define MAGE_PE_MUX_DELAY_OP   ${hex(idx)}U

#define MAGE_BUILD_PE_CFG(op, mux_a, mux_b) \
  (((uint32_t)(op) << 8) | ((uint32_t)(mux_b) << 4) | ((uint32_t)(mux_a) << 0))

// Delay unit selection modes
#define MAGE_D_PE_OP_NONE  0x0U
#define MAGE_D_PE_RES      0x1U
#define MAGE_D_PE_OP_A     0x2U
#define MAGE_D_PE_OP_B     0x3U
#define MAGE_D_DELAY_OP    0x4U
#define MAGE_D_PE_INPUT    0x5U

// Delay pipeline depth
#define MAGE_DELAY_DEPTH_1 0x0U
#define MAGE_DELAY_DEPTH_2 0x1U
#define MAGE_DELAY_DEPTH_3 0x2U
#define MAGE_DELAY_DEPTH_4 0x3U

// Delay neighbour selectors
%for i, neigh in enumerate(pattern_neigh_pe):
#define MAGE_D_${neigh}    ${hex(i)}U
%endfor

/**
 * @brief Enhanced builder macro for PE configuration with decoupled delay channels and depth.
 */
#define MAGE_BUILD_PE_CFG_EXT(op, mux_a, mux_b, d_fu, d_op, d_fwd, d_in_pe, depth) \
  (((uint32_t)(mux_a) & 0xFU) | \
   (((uint32_t)(mux_b) & 0xFU) << 4) | \
   (((uint32_t)(op) & 0x1FU) << 8) | \
   (((uint32_t)(d_fu) & 0x7U) << 13) | \
   (((uint32_t)(d_op) & 0x7U) << 16) | \
   (((uint32_t)(d_fwd) & 0x7U) << 19) | \
   (((uint32_t)(d_in_pe) & 0xFU) << 22) | \
   (((uint32_t)(depth) & 0x3U) << 26))



/**
 * @brief Sets the PEA configuration.
 * 
 * @param mage_pea_cfg The PEA configuration array that contains the configuration for each PE.
 */
void mage_set_pea_cfg(uint32_t mage_pea_cfg[MAGE_PEA_ROWS][MAGE_PEA_COLS][KMEM_SIZE]);

/**
 * @brief Sets the configuration for a specific PE.
 * 
 * @param pe_cfg The PE configuration value.
 * @param pe_row The row index of the PE.
 * @param pe_col The column index of the PE.
 * @param time The time instant for configuration pe_cfg.
 */
void mage_set_pe_cfg(uint32_t pe_cfg, uint8_t pe_row, uint8_t pe_col, uint8_t time);

/**
 * @brief Sets the constants for each PE.
 * 
 * @param pea_constants The PEA constants array.
 */
void mage_set_pea_constants(uint32_t pea_constants[MAGE_PEA_ROWS][MAGE_PEA_COLS]);

/**
 * @brief Sets a specific constant for a PE.
 * 
 * @param pea_constant The constant value.
 * @param reg The register index.
 */
void mage_set_pe_constant(uint32_t pea_constant, uint8_t row, uint8_t col);

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                          DAE Mage                          //
//                                                            //
////////////////////////////////////////////////////////////////

/**
 * @brief Starts Mage.
 */
void mage_start(void);

/**
 * @brief Checks if Mage has finished its operation.
 * 
 * @return uint32_t Returns 1 if finished, 0 otherwise.
 */
uint32_t is_mage_finished(void);

/**
 * @brief Waits until Mage has finished its operation.
 */
void mage_wait_done(void);

/**
 * @brief Sets the Iteration Interval (II).
 * 
 * @param ii The II to set.
 */
void mage_set_ii(uint8_t ii);

/**
 * @brief Sets Static/Time-multiplexed mode for AGE-PEA-OutSelectors-Xbars (from LSBs to MSBs)
 * 
 * @param snt The 4 bits to set the mode for the 4 components.
 */
void mage_set_snt(uint32_t snt);

/**
 * @brief Sets information related to accumulationmode.
 * 
 * @param mode Vector mode for the accumulation (8, 16, 32 bits)
 */
void mage_set_acc_mode(uint32_t mode);

/**
 * @brief Sets the blocksize for the address map of Mage SpM.
 * 
 * @param blocksize The blocksize to set.
 */
void mage_set_address_map_blocksize(uint32_t blocksize);

/**
 * @brief Sets CPU XOR-like interleaving access mode for Mage SpM.
 * 
 * @param enable 1 to enable CPU XOR-like mode, 0 to disable.
 */
void mage_set_cpu_xor_mode(uint32_t enable);

/**
 * @brief Sets the general configuration bits for Mage.
 * 
 * @param cfg_bits The configuration bits to set.
 */
void mage_set_general_cfg_bits(uint32_t cfg_bits);

/**
 * @brief Sets per-stream XOR addressing mode for conflict-free NTT.
 * 
 * @param stream_xor_mask Bitmask where bit s enables XOR addressing for Stream s.
 */
void mage_set_stream_xor_mode(uint32_t stream_xor_mask);

%if kernel_len != 1:
/**
 * @brief Sets each PE control mode (static or time-multiplexed).
 * 
 * @param pea_control_snt The PEA control mode. Each bit sets the mode of a PE in row-major order.
 */
void mage_set_pea_control_snt(uint32_t pea_control_snt);
%endif

/**
 * @brief Sets the Initial Loop Bounds (ILB) value for the Hardware Loops.
 * 
 * @param ilb The ILB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_ilb(uint8_t ilb[MAGE_NUM_HWLP]);

/**
 * @brief Sets the Final Loop Bounds (FLB) value for the Hardware Loops.
 * 
 * @param ilb The FLB value to set. Each 8 bits correspond to the ILB value for a different loop from the inner one.
 */
void mage_set_flb(uint8_t flb[MAGE_NUM_HWLP]);


/**
 * @brief Sets the increment values for the Hardware Loops.
 * 
 * @param li The increment values to set. Each 8 bits correspond to the increment value for a different loop from the inner one.
 */
void mage_set_li(uint8_t li[MAGE_NUM_HWLP]);


/**
 * @brief Sets the strides for all Address Generation Engines (AGEs).
 * 
 * @param strides strides to set.
 */
void mage_set_all_age_strides(uint32_t strides[MAGE_N_AGES]);

/**
 * @brief Sets the strides for an Address Generation Engine (AGE).
 *
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param strides strides to set.
 */
void mage_set_age_strides(uint32_t stream_id, uint32_t age_id, uint32_t strides);

/**
 * @brief Sets the per-IV addressing mode for all Address Generation Engines (AGEs).
 *
 * Each IV can use its stride Si in linear mode (Si * i, mode bit 0) or tiled mode
 * ((i >> log2(Si)) * (i % Si), mode bit 1). In tiled mode Si must be a power of two and
 * the corresponding stride field (see mage_set_age_strides) must hold log2(Si) instead of Si.
 *
 * @param modes mode bitmask per AGE: bits [3:0] select the mode for strides S0..S3.
 */
void mage_set_all_age_stride_modes(uint32_t modes[MAGE_N_AGES]);

/**
 * @brief Sets the per-IV addressing mode for an Address Generation Engine (AGE).
 *
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param modes mode bitmask: bits [3:0] select the mode for strides S0..S3
 *              (0 = linear Si * i, 1 = tiled (i >> log2(Si)) * (i % Si)).
 */
void mage_set_age_stride_mode(uint32_t stream_id, uint32_t age_id, uint32_t modes);


%if kernel_len != 1:
/**
 * @brief Sets the Prolog-Kernel-Epilog (PKE) value.
 * 
 * @param p The Prolog value.
 * @param k The Kernel value.
 * @param e The Epilog value.
 * @param len_dfg The length of the DFG.
 */
void mage_set_pke(uint8_t p, uint8_t k, uint8_t e, uint8_t len_dfg);
%endif

/**
 * @brief Sets the MAGE configuration.
 * 
 * @param mage_mage_cfg The MAGE configuration array that contains the configuration for each AGE.
 */
void mage_set_mage_cfg(uint32_t mage_mage_cfg[MAGE_N_STREAMS][MAGE_N_AGE_PER_STREAM][KMEM_SIZE]);

/**
 * @brief Sets the configuration for a specific AGE.
 * 
 * @param age_cfg The AGE configuration value.
 * @param stream_id The stream ID.
 * @param age_id The age ID.
 * @param time_kernel The time instant of the kernel in which the configuration is applied.
 */
void mage_set_age_cfg(uint32_t age_cfg, uint32_t stream_id, uint32_t age_id, uint32_t time_kernel);

/**
 * @brief Sets the selectors for the outputs of PEA.
 * 
 * @param sel_out_pea The selectors array for PEA.
 */
void mage_set_sel_out_pea(uint32_t sel_out_pea[SEL_OUT_PEA_SIZE]);

/**
 * @brief Sets a specific register in the selectors for the output of PEA.
 * 
 * @param sel_out_pea The selectors.
 * @param reg The register index.
 */
void mage_set_sel_out_pea_reg(uint32_t sel_out_pea, uint32_t reg);

/**
 * @brief Sets the Load Stream.
 * 
 * @param load_stream The Load Stream.
 */
void mage_set_load_stream(uint32_t load_stream[LOAD_STREAM_SIZE]);

/**
 * @brief Sets a specific register for the Load Stream.
 * 
 * @param load_stream The Load Stream.
 * @param reg The register index.
 */
void mage_set_load_stream_reg(uint32_t load_stream, uint32_t reg);

/**
 * @brief Sets the Store Stream.
 * 
 * @param store_stream The Store Stream.
 */
void mage_set_store_stream(uint32_t store_stream[STORE_STREAM_SIZE]);

/**
 * @brief Sets a specific register for the Store Stream.
 * 
 * @param store_strean The Store Stream.
 * @param reg The register index.
 */
void mage_set_store_stream_reg(uint32_t store_stream, uint32_t reg);

%endif
%if streaming_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                       Streaming Mage                       //
//                                                            //
////////////////////////////////////////////////////////////////
/**
 * @brief Sets the selector for the outputs of a column of PEA.
 * 
 * @param sel_out The selectors for PEA columns.
 * @param pea_col PEA column.
 */
void mage_set_sel_out_pea_cols(uint8_t sel_out, uint8_t pea_col);

/**
 * @brief Sets the accumulation values for a PE.
 * 
 * @param pe_acc_values The accumulation value.
 * @param pe_row PE row.
 * @param pe_col PE col.
 */
void mage_set_pe_acc_values(uint8_t acc_value, uint8_t pe_row, uint8_t pe_col);

/**
 * @brief Sets the selector for the outputs of PEA.
 * 
 * @param sel_out The selectors for PEA output.
 */
void mage_set_sel_out_xbar(uint8_t sel_out);

/**
 * @brief Sets the configuration for Mage DMA channel.
 * 
 * @param n_dma_ch Number of the DMA channel.
 * @param cfg DMA channel configuration.
 */
void mage_set_dma_rnw(uint8_t n_dma_ch, uint8_t cfg);

%endif
#ifdef __cplusplus
}
#endif

#endif // MAGE_H_