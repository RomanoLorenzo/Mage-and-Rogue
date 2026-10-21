#ifndef _MAGE_X_HEEP_
#define _MAGE_X_HEEP_

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

#include <stdint.h>
#include "mage_regs.h"

#define EXT_XBAR_NMASTER 4
#define EXT_XBAR_NSLAVE 1

%if dae_cgra == 1:
#define MAGE_START_ADDRESS        ((uintptr_t)0xF0000000U)
#define MAGE_SIZE                 ((uintptr_t)0x00100000U)
#define MAGE_END_ADDRESS          (MAGE_START_ADDRESS + MAGE_SIZE)
%endif

#define MAGE_PERIPH_START_ADDRESS ((uintptr_t)0x50000000U)
#define MAGE_PERIPH_SIZE          ((uintptr_t)0x00001000U)
#define MAGE_PERIPH_END_ADDRESS   (MAGE_PERIPH_START_ADDRESS + MAGE_PERIPH_SIZE)

// Processing Elements configuration
#define MAGE_PEA_CFG_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_CFG_PE_00_REG_OFFSET)
// Processing Elements constants
#define MAGE_PEA_CONSTANTS_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PEA_CONSTANTS_0_REG_OFFSET)
// Processing Elements rf
#define MAGE_PEA_RF_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PEA_CONSTANTS_0_REG_OFFSET)

%if dae_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                          DAE Mage                          //
//                                                            //
////////////////////////////////////////////////////////////////
#define MAGE_STATUS_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STATUS_REG_OFFSET)
#define MAGE_GEN_CFG_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_GEN_CFG_REG_OFFSET)
#define MAGE_ILB_HWL_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_ILB_HWL_REG_OFFSET)
#define MAGE_BLOCK_SIZE_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_BLOCK_SIZE_REG_OFFSET)
#define MAGE_FLB_HWL_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_FLB_HWL_REG_OFFSET)
#define MAGE_LI_HWL_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_INC_HWL_REG_OFFSET)
#define MAGE_STREAM_XOR_MODE_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STREAM_XOR_MODE_REG_OFFSET)
#define MAGE_STRIDES_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STRIDES_0_REG_OFFSET)
#define MAGE_STRIDE_MODE_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STRIDE_MODE_0_REG_OFFSET)
#define MAGE_ACC_HWLP_SEL_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_ACC_HWLP_SEL_0_REG_OFFSET)
%if kernel_len != 1:
#define MAGE_PKE_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PKE_REG_OFFSET)
#define MAGE_PEA_CONTROL_SNT_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PEA_CONTROL_SNT_REG_OFFSET)
%endif
<%
import math as m
load_age_sel_count = int(m.ceil(((n_age_tot*m.log2(max(n_age_per_stream,4)))*kernel_len)/32))
acc_hwlp_sel_count = int(m.ceil(n_age_tot/8))
%>
#define MAGE_SEL_OUT_PEA_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_OUT_PEA_SEL_REG_OFFSET)
%if load_age_sel_count == 1:
#define MAGE_LOAD_AGE_SEL_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_LOAD_AGE_SEL_REG_OFFSET)
#define MAGE_PEA_DMEM_SEL_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PEA_DMEM_SEL_REG_OFFSET)
%else:
#define MAGE_LOAD_AGE_SEL_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_LOAD_AGE_SEL_0_REG_OFFSET)
#define MAGE_PEA_DMEM_SEL_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_PEA_DMEM_SEL_0_REG_OFFSET)
%endif
#define MAGE_CFG_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_CFG_MAGE_AGE_0_REG_OFFSET)
#define MAGE_MAGE_CFG_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_CFG_MAGE_AGE_0_REG_OFFSET)

#define BANK_SIZE_BYTES       (${num_words * 4}U)
#define MAGE_DATA_BASE        MAGE_START_ADDRESS
#define MAGE_CTRL_BASE        MAGE_PERIPH_START_ADDRESS

#define MAGE_BANK(n)          ((volatile uint32_t *)(MAGE_DATA_BASE + ((uintptr_t)(n) * BANK_SIZE_BYTES)))

/* Control registers */
#define REG_STATUS            (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_STATUS_REG_OFFSET))
#define REG_GEN_CFG           (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_GEN_CFG_REG_OFFSET))
#define REG_ILB_HWL           (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_ILB_HWL_REG_OFFSET))
#define REG_BLOCK_SIZE        (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_BLOCK_SIZE_REG_OFFSET))
#define REG_FLB_HWL           (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_FLB_HWL_REG_OFFSET))
#define REG_INC_HWL           (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_INC_HWL_REG_OFFSET))
#define REG_STREAM_XOR_MODE   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_STREAM_XOR_MODE_REG_OFFSET))

#define REG_STRIDES(i)        (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_STRIDES_0_REG_OFFSET + ((uintptr_t)(i) * 4U)))
#define REG_STRIDE_MODE(i)    (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_STRIDE_MODE_0_REG_OFFSET + ((uintptr_t)(i) * 4U)))

#define REG_ACC_HWLP_SEL_0    (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_ACC_HWLP_SEL_0_REG_OFFSET))
%if acc_hwlp_sel_count >= 2:
#define REG_ACC_HWLP_SEL_1    (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_ACC_HWLP_SEL_1_REG_OFFSET))
%endif
%if acc_hwlp_sel_count >= 3:
#define REG_ACC_HWLP_SEL_2    (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_ACC_HWLP_SEL_2_REG_OFFSET))
%endif

#define REG_CFG_PE(r, c)      (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_CFG_PE_00_REG_OFFSET + (((uintptr_t)(r) * ${n_pea_cols}U) + (uintptr_t)(c)) * 4U))

#define REG_OUT_PEA_SEL       (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_OUT_PEA_SEL_REG_OFFSET))
%if load_age_sel_count == 1:
#define REG_LOAD_AGE_SEL(i)   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_LOAD_AGE_SEL_REG_OFFSET + ((uintptr_t)(i) * 4U)))
#define REG_LOAD_AGE_SEL_0    REG_LOAD_AGE_SEL(0)
#define REG_PEA_DMEM_SEL(i)   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_PEA_DMEM_SEL_REG_OFFSET + ((uintptr_t)(i) * 4U)))
#define REG_PEA_DMEM_SEL_0    REG_PEA_DMEM_SEL(0)
%else:
#define REG_LOAD_AGE_SEL(i)   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_LOAD_AGE_SEL_0_REG_OFFSET + ((uintptr_t)(i) * 4U)))
#define REG_LOAD_AGE_SEL_0    REG_LOAD_AGE_SEL(0)
#define REG_LOAD_AGE_SEL_1    REG_LOAD_AGE_SEL(1)
#define REG_PEA_DMEM_SEL(i)   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_PEA_DMEM_SEL_0_REG_OFFSET + ((uintptr_t)(i) * 4U)))
#define REG_PEA_DMEM_SEL_0    REG_PEA_DMEM_SEL(0)
#define REG_PEA_DMEM_SEL_1    REG_PEA_DMEM_SEL(1)
%endif

#define REG_CFG_MAGE_AGE(i)   (*(volatile uint32_t *)(MAGE_CTRL_BASE + MAGE_CFG_MAGE_AGE_0_REG_OFFSET + ((uintptr_t)(i) * 4U)))

%for b in range(n_age_tot):
#define START_MAGE_BANK_${b} (MAGE_START_ADDRESS + (${b * num_words * 4}U))
%endfor
#define MAGE_BANK_ADDR(b) ((uintptr_t)(MAGE_START_ADDRESS) + ((uintptr_t)(b) * (${num_words * 4}U)))

%endif
%if streaming_cgra == 1:
////////////////////////////////////////////////////////////////
//                                                            //
//                       Streaming Mage                       //
//                                                            //
////////////////////////////////////////////////////////////////
// DMA Configurations
#define MAGE_DMA_RNW_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_DMA_RNW_REG_OFFSET)
// Column Result selection
#define MAGE_COL_RES_SEL_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_SEL_OUT_COL_PEA_REG_OFFSET)
// Accumulation values
#define MAGE_ACC_VALUES_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_ACC_VALUE_0_REG_OFFSET)
// Separate column management
#define MAGE_COLS_GROUPING_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_COLS_GROUPING_REG_OFFSET)
// Synch DMAs
#define MAGE_SYNC_DMA_CH_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_SYNC_DMA_CH_REG_OFFSET)     
// Synch DMAs trans
#define MAGE_SYNC_DMA_CH_TRANS_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_SYNC_DMA_CH_TRANS_REG_OFFSET)   
// Trans size DMA 0
#define MAGE_TRANS_SIZE_0_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_DMA_CH_0_REG_OFFSET)       
// Trans size DMA 1
#define MAGE_TRANS_SIZE_1_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_DMA_CH_1_REG_OFFSET)     
// Trans size DMA 2
#define MAGE_TRANS_SIZE_2_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_DMA_CH_2_REG_OFFSET)     
// Trans size DMA 3
#define MAGE_TRANS_SIZE_3_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_DMA_CH_3_REG_OFFSET)    
// Trans size sync DMA 0
#define MAGE_TRANS_SIZE_0_SYNC_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_SYNC_DMA_CH_0_REG_OFFSET)       
// Trans size sync DMA 1
#define MAGE_TRANS_SIZE_1_SYNC_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_SYNC_DMA_CH_1_REG_OFFSET)     
// Trans size sync DMA 2
#define MAGE_TRANS_SIZE_2_SYNC_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_SYNC_DMA_CH_2_REG_OFFSET)     
// Trans size sync DMA 3
#define MAGE_TRANS_SIZE_3_SYNC_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_TRANS_SIZE_SYNC_DMA_CH_3_REG_OFFSET)                                          
%if out_stream_xbar == 1:
// Output xbar
#define MAGE_OUT_XBAR_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STREAM_OUT_XBAR_SEL_REG_OFFSET)
%endif
%if in_stream_xbar == 1:
// Output xbar
#define MAGE_IN_XBAR_START_ADDR (MAGE_PERIPH_START_ADDRESS + MAGE_STREAM_IN_XBAR_SEL_REG_OFFSET)
%endif
%endif

#ifdef __cplusplus
} // extern "C"
#endif // __cplusplus

#endif // _MAGE_X_HEEP_
