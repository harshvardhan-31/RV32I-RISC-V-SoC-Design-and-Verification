# ============================================================================
# Script: run_phase2_sim.ps1
# Project: RV32I RISC-V SoC (Phase 2 - Windows PowerShell Simulation Runner)
# Description: Compiles and runs Phase 2 testbenches on Windows using Icarus Verilog.
# ============================================================================

param (
    [string]$TargetTest = "all"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BuildDir = Join-Path $RepoRoot "build\phase2"
$ReportDir = Join-Path $RepoRoot "reports\simulation\phase2"

New-Item -ItemType Directory -Force -Path $BuildDir | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

if (-not (Get-Command iverilog -ErrorAction SilentlyContinue) -or -not (Get-Command vvp -ErrorAction SilentlyContinue)) {
    Write-Host "======================================================================" -ForegroundColor Red
    Write-Host "[ERROR] Icarus Verilog ('iverilog' / 'vvp') is not found in PATH." -ForegroundColor Red
    Write-Host "To install on Windows:" -ForegroundColor Yellow
    Write-Host "  winget install -e --id Bleifuss.IcarusVerilog"
    Write-Host "  OR: choco install icarus-verilog"
    Write-Host "======================================================================"
    exit 1
}

$RtlCore = @(
    "$RepoRoot\rtl\core\pc_unit.sv",
    "$RepoRoot\rtl\core\if_id_reg.sv",
    "$RepoRoot\rtl\core\instruction_decoder.sv",
    "$RepoRoot\rtl\core\immediate_generator.sv",
    "$RepoRoot\rtl\core\control_unit.sv",
    "$RepoRoot\rtl\core\register_file.sv",
    "$RepoRoot\rtl\core\id_ex_reg.sv",
    "$RepoRoot\rtl\core\alu.sv",
    "$RepoRoot\rtl\core\ex_mem_reg.sv",
    "$RepoRoot\rtl\core\load_store_unit.sv",
    "$RepoRoot\rtl\core\mem_wb_reg.sv",
    "$RepoRoot\rtl\core\cpu_core.sv"
)

$TbModels = @(
    "$RepoRoot\testbench\models\instruction_memory_model.sv",
    "$RepoRoot\testbench\models\data_memory_bus_model.sv"
)

Write-Host "Starting Phase 2 Simulations..." -ForegroundColor Cyan

function Run-Test($name, $tb, $srcs) {
    Write-Host "--> Running $name" -ForegroundColor Yellow
    $vvp = "$BuildDir\$name.vvp"
    $log = "$ReportDir\$name.log"
    & iverilog -g2012 -Wall -I "$RepoRoot\rtl\core" -o $vvp $tb $srcs
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Compilation failed for $name" -ForegroundColor Red
        return $false
    }
    & vvp $vvp | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[FAIL] Simulation failed for $name" -ForegroundColor Red
        return $false
    }
    Write-Host "[PASS] $name passed successfully!" -ForegroundColor Green
    return $true
}

if ($TargetTest -eq "all" -or $TargetTest -eq "tb_alu") {
    Run-Test "tb_alu" "$RepoRoot\testbench\unit\tb_alu.sv" @("$RepoRoot\rtl\core\alu.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_register_file") {
    Run-Test "tb_register_file" "$RepoRoot\testbench\unit\tb_register_file.sv" @("$RepoRoot\rtl\core\register_file.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_instruction_decoder") {
    Run-Test "tb_instruction_decoder" "$RepoRoot\testbench\unit\tb_instruction_decoder.sv" @("$RepoRoot\rtl\core\instruction_decoder.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_immediate_generator") {
    Run-Test "tb_immediate_generator" "$RepoRoot\testbench\unit\tb_immediate_generator.sv" @("$RepoRoot\rtl\core\immediate_generator.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_control_unit") {
    Run-Test "tb_control_unit" "$RepoRoot\testbench\unit\tb_control_unit.sv" @("$RepoRoot\rtl\core\control_unit.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_pipeline_registers") {
    Run-Test "tb_pipeline_registers" "$RepoRoot\testbench\unit\tb_pipeline_registers.sv" @(
        "$RepoRoot\rtl\core\if_id_reg.sv",
        "$RepoRoot\rtl\core\id_ex_reg.sv",
        "$RepoRoot\rtl\core\ex_mem_reg.sv",
        "$RepoRoot\rtl\core\mem_wb_reg.sv"
    )
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_load_store_unit") {
    Run-Test "tb_load_store_unit" "$RepoRoot\testbench\unit\tb_load_store_unit.sv" @("$RepoRoot\rtl\core\load_store_unit.sv")
}
if ($TargetTest -eq "all" -or $TargetTest -eq "tb_cpu_core") {
    Run-Test "tb_cpu_core" "$RepoRoot\testbench\system\tb_cpu_core.sv" ($RtlCore + $TbModels)
}
