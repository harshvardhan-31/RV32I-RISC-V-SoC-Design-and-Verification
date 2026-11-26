# ============================================================================
# Makefile for RV32I RISC-V SoC - Phase 2
# ============================================================================

SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator

BUILD_DIR := build/phase2
REPORT_DIR := reports/simulation/phase2

RTL_CORE_SRCS := \
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
	rtl/core/mem_wb_reg.sv \
	rtl/core/cpu_core.sv

TB_MODELS := \
	testbench/models/instruction_memory_model.sv \
	testbench/models/data_memory_bus_model.sv

.PHONY: all help test test_unit test_system lint clean dirs

all: dirs test

help:
	@echo "Available targets:"
	@echo "  make test          - Run all unit and system testbenches"
	@echo "  make test_unit     - Run all unit testbenches"
	@echo "  make test_system   - Run cpu_core system testbench"
	@echo "  make lint          - Run Verilator linting on CPU core"
	@echo "  make clean         - Remove simulation artifacts and build files"

dirs:
	@mkdir -p $(BUILD_DIR) $(REPORT_DIR)

# Unit tests
test_alu: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_alu.vvp testbench/unit/tb_alu.sv rtl/core/alu.sv
	$(VVP) $(BUILD_DIR)/tb_alu.vvp | tee $(REPORT_DIR)/tb_alu.log

test_regfile: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_register_file.vvp testbench/unit/tb_register_file.sv rtl/core/register_file.sv
	$(VVP) $(BUILD_DIR)/tb_register_file.vvp | tee $(REPORT_DIR)/tb_register_file.log

test_decoder: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_instruction_decoder.vvp testbench/unit/tb_instruction_decoder.sv rtl/core/instruction_decoder.sv
	$(VVP) $(BUILD_DIR)/tb_instruction_decoder.vvp | tee $(REPORT_DIR)/tb_instruction_decoder.log

test_imm_gen: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_immediate_generator.vvp testbench/unit/tb_immediate_generator.sv rtl/core/immediate_generator.sv
	$(VVP) $(BUILD_DIR)/tb_immediate_generator.vvp | tee $(REPORT_DIR)/tb_immediate_generator.log

test_control: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_control_unit.vvp testbench/unit/tb_control_unit.sv rtl/core/control_unit.sv
	$(VVP) $(BUILD_DIR)/tb_control_unit.vvp | tee $(REPORT_DIR)/tb_control_unit.log

test_piperegs: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_pipeline_registers.vvp testbench/unit/tb_pipeline_registers.sv rtl/core/if_id_reg.sv rtl/core/id_ex_reg.sv rtl/core/ex_mem_reg.sv rtl/core/mem_wb_reg.sv
	$(VVP) $(BUILD_DIR)/tb_pipeline_registers.vvp | tee $(REPORT_DIR)/tb_pipeline_registers.log

test_lsu: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR)/tb_load_store_unit.vvp testbench/unit/tb_load_store_unit.sv rtl/core/load_store_unit.sv
	$(VVP) $(BUILD_DIR)/tb_load_store_unit.vvp | tee $(REPORT_DIR)/tb_load_store_unit.log

test_unit: test_alu test_regfile test_decoder test_imm_gen test_control test_piperegs test_lsu

# System test
test_system: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/core -o $(BUILD_DIR)/tb_cpu_core.vvp testbench/system/tb_cpu_core.sv $(RTL_CORE_SRCS) $(TB_MODELS)
	$(VVP) $(BUILD_DIR)/tb_cpu_core.vvp | tee $(REPORT_DIR)/tb_cpu_core.log

test: test_unit test_system

lint:
	@bash scripts/lint_phase2.sh

clean:
	rm -rf build/
