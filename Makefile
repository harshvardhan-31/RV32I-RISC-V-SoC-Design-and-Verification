# ============================================================================
# Makefile for RV32I RISC-V SoC (Phase 2 & Phase 3)
# ============================================================================

SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator

BUILD_DIR_P2 := build/phase2
BUILD_DIR_P3 := build/phase3
REPORT_DIR_P2 := reports/simulation/phase2
REPORT_DIR_P3 := reports/simulation/phase3

RTL_CORE_P2 := \
	rtl/core/pc_unit.sv \
	rtl/core/if_id_reg.sv \
	rtl/core/instruction_decoder.sv \
	rtl/core/immediate_generator.sv \
	rtl/core/control_unit.sv \
	rtl/core/register_file.sv \
	rtl/core/id_ex_reg.sv \
	rtl/core/alu.sv \
	rtl/core/ex_mem_reg.sv \
	rtl/core/load_store_unit.sv \
	rtl/core/mem_wb_reg.sv

RTL_CORE_P3 := \
	$(RTL_CORE_P2) \
	rtl/core/hazard_unit.sv \
	rtl/core/forwarding_unit.sv \
	rtl/core/cpu_core.sv

TB_MODELS := \
	testbench/models/instruction_memory_model.sv \
	testbench/models/data_memory_bus_model.sv

.PHONY: all help test test_unit test_system test_phase3 test_hazard_unit test_forwarding_unit test_hazard_integration test_cpu_forwarding lint lint_phase3 clean dirs

all: dirs test test_phase3

help:
	@echo "Available targets:"
	@echo "  make test               - Run all Phase 2 testbenches"
	@echo "  make test_phase3        - Run all Phase 3 unit & integration testbenches"
	@echo "  make test_hazard_unit   - Run hazard_unit testbench"
	@echo "  make test_forwarding_unit - Run forwarding_unit testbench"
	@echo "  make test_hazard_integration - Run hazard integration system testbench"
	@echo "  make test_cpu_forwarding - Run CPU forwarding system testbench"
	@echo "  make lint               - Run Verilator linting on Phase 2 & Phase 3"
	@echo "  make clean              - Remove simulation artifacts and build files"

dirs:
	@mkdir -p $(BUILD_DIR_P2) $(BUILD_DIR_P3) $(REPORT_DIR_P2) $(REPORT_DIR_P3) sim_out

# Phase 2 Unit tests
test_alu: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_alu.vvp testbench/unit/tb_alu.sv rtl/core/alu.sv
	$(VVP) $(BUILD_DIR_P2)/tb_alu.vvp | tee $(REPORT_DIR_P2)/tb_alu.log

test_regfile: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_register_file.vvp testbench/unit/tb_register_file.sv rtl/core/register_file.sv
	$(VVP) $(BUILD_DIR_P2)/tb_register_file.vvp | tee $(REPORT_DIR_P2)/tb_register_file.log

test_decoder: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_instruction_decoder.vvp testbench/unit/tb_instruction_decoder.sv rtl/core/instruction_decoder.sv
	$(VVP) $(BUILD_DIR_P2)/tb_instruction_decoder.vvp | tee $(REPORT_DIR_P2)/tb_instruction_decoder.log

test_imm_gen: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_immediate_generator.vvp testbench/unit/tb_immediate_generator.sv rtl/core/immediate_generator.sv
	$(VVP) $(BUILD_DIR_P2)/tb_immediate_generator.vvp | tee $(REPORT_DIR_P2)/tb_immediate_generator.log

test_control: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_control_unit.vvp testbench/unit/tb_control_unit.sv rtl/core/control_unit.sv
	$(VVP) $(BUILD_DIR_P2)/tb_control_unit.vvp | tee $(REPORT_DIR_P2)/tb_control_unit.log

test_piperegs: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_pipeline_registers.vvp testbench/unit/tb_pipeline_registers.sv rtl/core/if_id_reg.sv rtl/core/id_ex_reg.sv rtl/core/ex_mem_reg.sv rtl/core/mem_wb_reg.sv
	$(VVP) $(BUILD_DIR_P2)/tb_pipeline_registers.vvp | tee $(REPORT_DIR_P2)/tb_pipeline_registers.log

test_lsu: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P2)/tb_load_store_unit.vvp testbench/unit/tb_load_store_unit.sv rtl/core/load_store_unit.sv
	$(VVP) $(BUILD_DIR_P2)/tb_load_store_unit.vvp | tee $(REPORT_DIR_P2)/tb_load_store_unit.log

test_unit: test_alu test_regfile test_decoder test_imm_gen test_control test_piperegs test_lsu

# Phase 2 System test
test_system: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/core -o $(BUILD_DIR_P2)/tb_cpu_core.vvp testbench/system/tb_cpu_core.sv $(RTL_CORE_P3) $(TB_MODELS)
	$(VVP) $(BUILD_DIR_P2)/tb_cpu_core.vvp | tee $(REPORT_DIR_P2)/tb_cpu_core.log

test: test_unit test_system

# Phase 3 Unit Tests
test_hazard_unit: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P3)/tb_hazard_unit.vvp testbench/unit/tb_hazard_unit.sv rtl/core/hazard_unit.sv
	$(VVP) $(BUILD_DIR_P3)/tb_hazard_unit.vvp | tee $(REPORT_DIR_P3)/tb_hazard_unit.log

test_forwarding_unit: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P3)/tb_forwarding_unit.vvp testbench/unit/tb_forwarding_unit.sv rtl/core/forwarding_unit.sv
	$(VVP) $(BUILD_DIR_P3)/tb_forwarding_unit.vvp | tee $(REPORT_DIR_P3)/tb_forwarding_unit.log

# Phase 3 System Tests
test_hazard_integration: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/core -o $(BUILD_DIR_P3)/tb_hazard_integration.vvp testbench/system/tb_hazard_integration.sv $(RTL_CORE_P3) $(TB_MODELS)
	$(VVP) $(BUILD_DIR_P3)/tb_hazard_integration.vvp | tee $(REPORT_DIR_P3)/tb_hazard_integration.log

test_cpu_forwarding: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/core -o $(BUILD_DIR_P3)/tb_cpu_forwarding.vvp testbench/system/tb_cpu_forwarding.sv $(RTL_CORE_P3) $(TB_MODELS)
	$(VVP) $(BUILD_DIR_P3)/tb_cpu_forwarding.vvp | tee $(REPORT_DIR_P3)/tb_cpu_forwarding.log

test_phase3: test_hazard_unit test_forwarding_unit test_hazard_integration test_cpu_forwarding

lint:
	@bash scripts/lint_phase2.sh

lint_phase3:
	@bash scripts/lint_phase3.sh

clean:
	rm -rf build/ sim_out/
