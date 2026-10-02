uint32_t *mage_status          = ((int32_t *)(MAGE_STATUS_START_ADDR));
uint32_t *mage_gen_cfg         = ((int32_t *)(MAGE_GEN_CFG_START_ADDR));
uint32_t *mage_hwl_ilb         = ((int32_t *)(MAGE_ILB_HWL_START_ADDR));
uint32_t *mage_hwl_flb         = ((int32_t *)(MAGE_FLB_HWL_START_ADDR));
uint32_t *mage_hwl_li          = ((int32_t *)(MAGE_LI_HWL_START_ADDR));
uint32_t *mage_sel_out_pea     = ((int32_t *)(MAGE_SEL_OUT_PEA_START_ADDR));
uint32_t *mage_load_stream     = ((int32_t *)(MAGE_LOAD_AGE_SEL_ADDR));
uint32_t *mage_store_stream    = ((int32_t *)(MAGE_PEA_DMEM_SEL_ADDR));
uint32_t *mage_agu             = ((int32_t *)(MAGE_CFG_START_ADDR));
uint32_t *mage_age_strides     = ((int32_t *)(MAGE_STRIDES_START_ADDR));
uint32_t *mage_stride_mode     = ((int32_t *)(MAGE_STRIDE_MODE_START_ADDR));
uint32_t *mage_acc_hwlp_sel    = ((int32_t *)(MAGE_ACC_HWLP_SEL_START_ADDR));
uint32_t *mage_pea             = ((int32_t *)(MAGE_PEA_CFG_START_ADDR));
uint32_t *mage_pea_constants   = ((int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR));

void mage_example_cfg(){

	//Mage Hardware Loops configuration bits
	mage_hwl_flb[0] = 0x00000007;
	mage_hwl_li[0] = 0x00000001;


	//Mage AGU Configuration
	mage_agu[0] = 0x80002040;
	mage_agu[1] = 0x80004000;

	//Mage AGU Strides
	mage_age_strides[0] = 0x1;
	mage_age_strides[1] = 0x1;


	//Mage AGU Stride Mode
	mage_stride_mode[0] = 0x0;
	mage_stride_mode[1] = 0x1;


	//Mage AGU Acc Hwlp Sel
	mage_acc_hwlp_sel[0] = 0x30;


	//Mage Load Stream Configuration

	//Mage Store Stream Configuration

	//Mage Selection of Row Output Configuration

	//Mage PEA Constants
	mage_pea_constants[0] = 0x5;
	mage_pea_constants[5] = 0xa;


	//PEA Configuration
	mage_pea[0] = 0xa01;
	mage_pea[5] = 0x105;
}
