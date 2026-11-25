#!/usr/bin/env bash
# TEMPLATE — usage: scripts/run_sim.sh <testbench_name>
# Requires Icarus Verilog (version TBD). Will fail until RTL and testbenches exist.
set -euo pipefail
TB=${1:?testbench name}
mkdir -p build reports/simulation
iverilog -g2012 -o build/$TB.vvp $(find rtl -name "*.sv") testbench/*/$TB.sv
vvp build/$TB.vvp | tee reports/simulation/$TB.log
echo "commit: $(git rev-parse HEAD)  iverilog: $(iverilog -V 2>&1 | head -1)" >> reports/simulation/$TB.log
