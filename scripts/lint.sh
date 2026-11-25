#!/usr/bin/env bash
# TEMPLATE — Verilator lint (version TBD).
set -euo pipefail
verilator --lint-only -Wall --top-module rv32i_soc_top $(find rtl -name "*.sv")
