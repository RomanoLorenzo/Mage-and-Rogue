.PHONY: clean help

PYTHON = python3
FUSESOC = fusesoc

MAGE_CORE = vlsi:polito:mage-dae
MAGE_CFG_HJSON ?= config/dae/cfg_2x2_2x2_full.hjson

### Regtool ###
REGTOOL_SCRIPT = util/regtool.py
REGTOOL_DEST_DIR = ./hw/mage/configuration
REGTOOL_SRC_FILE = ./hw/mage/configuration/mage_regs.hjson
REGTOOL_SW_DEST_DIR = ./sw

re-vendor:
	$(PYTHON) ./util/vendor.py ./vendor/lowrisc_opentitan.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_register_interface.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_common_cells.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_tech_cells_generic.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_axi.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_axi_obi.vendor.hjson -v --update; \
	$(PYTHON) ./util/vendor.py ./vendor/pulp_platform_obi.vendor.hjson -v --update;

mage-gen:
	rm -f \
		hw/mage/execute/pea.sv \
		hw/mage/execute/pe/dae/pe_dae.sv \
		hw/mage/execute/pe/dae/pe_dae_part_gemm_acc.sv \
		hw/mage/packages/agu_pkg.sv \
		hw/mage/packages/xbar_pkg.sv \
		hw/mage/access/age.sv \
		hw/mage/packages/pea_pkg.sv \
		hw/mage/configuration/peripheral_regs.sv \
		hw/mage/dmem_decoder.sv \
		hw/mage_top.sv \
		hw/mage_wrapper.sv \
		hw/mage/configuration/mage_regs.hjson \
		hw/mage/access/agu.sv \
		hw/mage/access/cfg_dispatcher.sv \
		hw/mage/access/k_controller.sv \
		hw/fpga/scripts/generate_sram.tcl \
		sw/mage.h \
		sw/mage_params.h \
		sw/mage.c \
		sw/mage_cva6.h
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute --tpl-sv hw/mage/execute/pea.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/dae --tpl-sv hw/mage/execute/pe/dae/pe_dae.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/dae --tpl-sv hw/mage/execute/pe/dae/pe_dae_part_gemm_acc.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/agu_pkg.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/xbar_pkg.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/age.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/pea_pkg.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/peripheral_regs.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage --tpl-sv hw/mage/dmem_decoder.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_top.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_wrapper.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/mage_regs.hjson.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/agu.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/cfg_dispatcher.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/access --tpl-sv hw/mage/access/k_controller.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/fpga/scripts/ --tpl-sv hw/fpga/scripts/generate_sram.tcl.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.h.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_params.h.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.c.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_cva6.h.tpl
	util/format-verible;
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h
	util/format-verible;

rogue-gen:
	rm -f \
		hw/mage/stream/streaming_interface.sv \
		hw/mage/packages/stream_intf_pkg.sv \
		hw/mage/execute/pea.sv \
		hw/mage/packages/pea_pkg.sv \
		hw/mage/execute/pe/streaming/pe_s_*.sv \
		hw/mage/execute/pe/streaming/fu/fu_s_*.sv \
		hw/mage/configuration/peripheral_regs.sv \
		hw/mage_top.sv \
		hw/mage_wrapper.sv \
		hw/mage/configuration/mage_regs.hjson \
		mage-stream.core \
		sw/mage.h \
		sw/mage_params.h \
		sw/mage.c \
		sw/mage_cva6.h
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/stream --tpl-sv hw/mage/stream/streaming_interface.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/stream_intf_pkg.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute --tpl-sv hw/mage/execute/pea.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/packages --tpl-sv hw/mage/packages/pea_pkg.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/streaming --pe-sv hw/mage/execute/pe/streaming/pe_s.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/execute/pe/streaming/fu --fu-sv hw/mage/execute/pe/streaming/fu/fu_s.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/peripheral_regs.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_top.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw --tpl-sv hw/mage_wrapper.sv.tpl
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/mage_regs.hjson.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.h.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_params.h.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.c.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_cva6.h.tpl
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir . --tpl-sv mage-stream.core.tpl
	util/format-verible;
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h


mage-gen-sw:
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.h.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_params.h.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.c.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_cva6.h.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/mage_regs.hjson.tpl 
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h

rogue-gen-sw:
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage.h.tpl 
	$(PYTHON) util/mage-gen.py  --mage_cfg $(MAGE_CFG_HJSON) --outdir sw/ --tpl-sv sw/mage_params.h.tpl 
	$(PYTHON) util/mage-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir hw/mage/configuration --tpl-sv hw/mage/configuration/mage_regs.hjson.tpl 
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h

verible:
	util/format-verible;

### Spells (kernel configurations, see sw/spells/) ###
# APP names the kernel; its spell lives in sw/spells/<dae|streaming>/$(APP),
# the arch being taken from the directory of MAGE_CFG_HJSON.
SPELL_ARCH = $(notdir $(patsubst %/,%,$(dir $(MAGE_CFG_HJSON))))
SPELL_DIR ?= sw/spells/$(SPELL_ARCH)/$(APP)

# Regenerates MageSpellBuilder.py for MAGE_CFG_HJSON; creates the spell.py
# scaffold only if the kernel doesn't have one yet (it is hand-written).
spell-gen:
	@test -n "$(APP)" || (echo "Usage: make spell-gen APP=<kernel> MAGE_CFG_HJSON=config/<dae|streaming>/<cfg>.hjson" && exit 1)
	mkdir -p $(SPELL_DIR)
	$(PYTHON) util/spell-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir $(SPELL_DIR) --tpl-sv sw/spells/MageSpellBuilder.py.tpl
	@if [ -e $(SPELL_DIR)/spell.py ]; then \
		echo "$(SPELL_DIR)/spell.py already exists, not overwriting it"; \
	else \
		$(PYTHON) util/spell-gen.py --mage_cfg $(MAGE_CFG_HJSON) --outdir $(SPELL_DIR) --tpl-sv sw/spells/spell.py.tpl; \
	fi

# Runs spell.py, producing spell.c next to it.
spell-run:
	@test -n "$(APP)" || (echo "Usage: make spell-run APP=<kernel> MAGE_CFG_HJSON=config/<dae|streaming>/<cfg>.hjson" && exit 1)
	$(PYTHON) $(SPELL_DIR)/spell.py

verilator-sim:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=verilator $(FUSESOC_FLAGS) --setup --build $(MAGE_CORE)  2>&1 | tee buildsim.log

questasim-sim:
	$(FUSESOC) --cores-root . run --no-export --target=sim --tool=modelsim $(FUSESOC_FLAGS) --setup --build $(MAGE_CORE) 2>&1 | tee buildsim.log

synthesis:
	$(FUSESOC) --cores-root . run --no-export --target=syn $(FUSESOC_FLAGS_SYN) --setup $(MAGE_CORE) ${FUSESOC_PARAM} 2>&1 | tee builddesigncompiler.log

regtool:
	$(PYTHON) $(REGTOOL_SCRIPT) -r -t $(REGTOOL_DEST_DIR) $(REGTOOL_SRC_FILE)
	$(PYTHON) $(REGTOOL_SCRIPT) -D $(REGTOOL_SRC_FILE) > $(REGTOOL_SW_DEST_DIR)/mage_regs.h

run-verilator:
	cd ./build/vlsi_polito_mage/sim-verilator;\
	make Vmage_wrapper;\
	./Vmage_wrapper;\

run-synthesis:
	cd ./build/vlsi_polito_mage/syn-design_compiler;\
	make -f Makefile;\

run-power-analysis:
	cd ./build/vlsi_polito_mage/power-analysis;\
	pt_shell -file  ../../../scripts/power_analysis/pwr_script.tcl\

waves:
	gtkwave ./build/vlsi_polito_mage/sim-verilator/waveform.vcd

clean-build:
	rm -rf build buildsim.log builddesigncompiler.log verilator_build.log

clean-synthesis:
	rm -rf build/vlsi_polito_mage/syn-design_compiler buildsim.log builddesigncompiler.log

flist:
	rm -f Flist.mage && \
	rm -f Bender.lock && \
	bender --local script verilator > Flist.mage && \
	rm -f Bender.lock

vericheck-lite: flist
	verilator --lint-only -Wno-fatal --error-limit 0 waivers.vlt -f Flist.mage --top-module mage_axi_wrapper 2>&1 | tee verilator_lint.log
	@if grep -qi "%Error" verilator_lint.log; then \
		grep -niT --color=always "%Error" verilator_lint.log; \
		echo "\n[FATAL] Erros found:" \
		exit 1; \
	else \
		echo "\n[SUCCESS] No errors detected by Verilator. You can suppress warnings using waivers.vlt"; \
	fi

VERILATOR_BUILD_DIR = build/verilator_check
TB_MAGE_AXI = $(abspath tb/tb_mage_axi_wrapper.cpp)

vericheck: flist
	@mkdir -p $(VERILATOR_BUILD_DIR)
	verilator --cc --exe --build -j $$(nproc) \
		--Mdir $(VERILATOR_BUILD_DIR) \
		-Wno-fatal -Wno-UNOPTFLAT --error-limit 0 \
		waivers.vlt -f Flist.mage --top-module mage_axi_wrapper \
		$(TB_MAGE_AXI) 2>&1 | tee verilator_build.log
	@echo "\n[INFO] Running compiled Verilator simulation executable..."
	./$(VERILATOR_BUILD_DIR)/Vmage_axi_wrapper
	@echo "\n[SUCCESS] Verilator full C++ compilation and simulation check PASSED!"

clean-repo: clean-build clean-synthesis
	rm -rf .bender
	git clean -fdX -- ':!doc/doc.pdf' ':!vendor/*.hjson'
