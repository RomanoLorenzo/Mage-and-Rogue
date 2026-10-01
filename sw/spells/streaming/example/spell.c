uint32_t *mage_pea             = (int32_t *)(MAGE_PEA_CFG_START_ADDR);
uint32_t *mage_sel_out_pea     = (int32_t *)(MAGE_COL_RES_SEL_START_ADDR);
uint32_t *mage_pe_acc_values   = (int32_t *)(MAGE_ACC_VALUES_START_ADDR);
uint32_t *mage_pea_constants   = (int32_t *)(MAGE_PEA_CONSTANTS_START_ADDR);

void mage_example_cfg(){

	//Mage Selection of Column Output Configuration
	uint32_t selOutPeaConfig[1] = {0x64646464};
	mage_sel_out_pea[0] = selOutPeaConfig[0];


	//Mage PEA Accumulation Values


	//Mage PEA Constants


	//PEA Configuration
}
