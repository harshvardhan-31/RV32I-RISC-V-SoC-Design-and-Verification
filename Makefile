# ============================================================================
# Makefile for RV32I RISC-V SoC (Phase 2, Phase 3 & Phase 4)
# ============================================================================

SHELL := /bin/bash
IVERILOG ?= iverilog
VVP ?= vvp
VERILATOR ?= verilator

BUILD_DIR_P2 := build/phase2
BUILD_DIR_P3 := build/phase3
BUILD_DIR_P4 := build/phase4
REPORT_DIR_P2 := reports/simulation/phase2
REPORT_DIR_P3 := reports/simulation/phase3
REPORT_DIR_P4 := reports/simulation/phase4

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

RTL_P4_MEM := \
	rtl/memory/instruction_memory.sv \
	rtl/memory/data_memory.sv

RTL_P4_BUS := \
	rtl/bus/bus_interconnect.sv

RTL_P4_PERIPH := \
	rtl/peripherals/uart_controller.sv \
	rtl/peripherals/spi_master.sv \
	rtl/peripherals/timer.sv \
	rtl/peripherals/interrupt_controller.sv

RTL_P4_ALL := \
	$(RTL_CORE_P3) \
	$(RTL_P4_MEM) \
	$(RTL_P4_BUS) \
	$(RTL_P4_PERIPH) \
	rtl/top/rv32i_soc_top.sv

TB_MODELS := \
	testbench/models/instruction_memory_model.sv \
	testbench/models/data_memory_bus_model.sv

.PHONY: all help test test_unit test_system test_phase3 test_phase4 \
        test_hazard_unit test_forwarding_unit test_hazard_integration test_cpu_forwarding \
        test_imem test_dmem test_bus test_uart test_spi test_timer test_intc \
        test_soc_bus test_soc_top lint lint_phase3 lint_phase4 firmware clean dirs

all: dirs test test_phase3 test_phase4

help:
	@echo "Available targets:"
	@echo "  make test               - Run all Phase 2 testbenches"
	@echo "  make test_phase3        - Run all Phase 3 unit & integration testbenches"
	@echo "  make test_phase4        - Run all Phase 4 unit & system testbenches"
	@echo "  make test_soc_top       - Run Phase 4 full SoC top testbench"
	@echo "  make lint_phase4        - Run Verilator linting on Phase 4 RTL"
	@echo "  make firmware           - Compile assembly programs into hex"
	@echo "  make clean              - Remove simulation artifacts and build files"

dirs:
	@mkdir -p $(BUILD_DIR_P2) $(BUILD_DIR_P3) $(BUILD_DIR_P4) $(REPORT_DIR_P2) $(REPORT_DIR_P3) $(REPORT_DIR_P4) sim_out

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

# Phase 4 Unit Tests
test_imem: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_instruction_memory.vvp testbench/unit/tb_instruction_memory.sv rtl/memory/instruction_memory.sv
	$(VVP) $(BUILD_DIR_P4)/tb_instruction_memory.vvp | tee $(REPORT_DIR_P4)/tb_instruction_memory.log

test_dmem: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_data_memory.vvp testbench/unit/tb_data_memory.sv rtl/memory/data_memory.sv
	$(VVP) $(BUILD_DIR_P4)/tb_data_memory.vvp | tee $(REPORT_DIR_P4)/tb_data_memory.log

test_bus: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_bus_interconnect.vvp testbench/unit/tb_bus_interconnect.sv rtl/bus/bus_interconnect.sv
	$(VVP) $(BUILD_DIR_P4)/tb_bus_interconnect.vvp | tee $(REPORT_DIR_P4)/tb_bus_interconnect.log

test_uart: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_uart_controller.vvp testbench/unit/tb_uart_controller.sv rtl/peripherals/uart_controller.sv
	$(VVP) $(BUILD_DIR_P4)/tb_uart_controller.vvp | tee $(REPORT_DIR_P4)/tb_uart_controller.log

test_spi: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_spi_master.vvp testbench/unit/tb_spi_master.sv rtl/peripherals/spi_master.sv
	$(VVP) $(BUILD_DIR_P4)/tb_spi_master.vvp | tee $(REPORT_DIR_P4)/tb_spi_master.log

test_timer: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_timer.vvp testbench/unit/tb_timer.sv rtl/peripherals/timer.sv
	$(VVP) $(BUILD_DIR_P4)/tb_timer.vvp | tee $(REPORT_DIR_P4)/tb_timer.log

test_intc: dirs
	$(IVERILOG) -g2012 -Wall -o $(BUILD_DIR_P4)/tb_interrupt_controller.vvp testbench/unit/tb_interrupt_controller.sv rtl/peripherals/interrupt_controller.sv
	$(VVP) $(BUILD_DIR_P4)/tb_interrupt_controller.vvp | tee $(REPORT_DIR_P4)/tb_interrupt_controller.log

test_unit_phase4: test_imem test_dmem test_bus test_uart test_spi test_timer test_intc

# Phase 4 System Tests
test_soc_bus: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/memory -I rtl/bus -I rtl/peripherals \
		-o $(BUILD_DIR_P4)/tb_soc_bus_integration.vvp \
		testbench/system/tb_soc_bus_integration.sv $(RTL_P4_MEM) $(RTL_P4_BUS) $(RTL_P4_PERIPH)
	$(VVP) $(BUILD_DIR_P4)/tb_soc_bus_integration.vvp | tee $(REPORT_DIR_P4)/tb_soc_bus_integration.log

test_soc_top: dirs
	$(IVERILOG) -g2012 -Wall -I rtl/core -I rtl/memory -I rtl/bus -I rtl/peripherals -I rtl/top \
		-o $(BUILD_DIR_P4)/tb_rv32i_soc_top.vvp \
		testbench/system/tb_rv32i_soc_top.sv $(RTL_P4_ALL)
	$(VVP) $(BUILD_DIR_P4)/tb_rv32i_soc_top.vvp | tee $(REPORT_DIR_P4)/tb_rv32i_soc_top.log

test_phase4: test_unit_phase4 test_soc_bus test_soc_top

lint:
	@bash scripts/lint_phase2.sh

lint_phase3:
	@bash scripts/lint_phase3.sh

lint_phase4:
	@bash scripts/lint_phase4.sh

firmware:
	@bash scripts/build_firmware.sh

clean:
	rm -rf build/ sim_out/
