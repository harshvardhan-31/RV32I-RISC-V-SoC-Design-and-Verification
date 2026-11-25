# Development Roadmap

Progress is measured only by completed acceptance criteria with evidence.

## Phase 1 — Project Foundation and Architecture
Status: In progress

Acceptance criteria:
- [ ] Scope and assumptions documented
- [ ] 22-module inventory
- [ ] Memory map and bus protocol proposed
- [ ] Verification plan
- [ ] Repository structure and tool templates
- [ ] Open TBD decisions reviewed

## Phase 2 — RV32I Pipelined Processor
Status: Not started

Acceptance criteria:
- [ ] RTL for all CPU modules
- [ ] Unit testbenches for ALU, register file, decoder, immediate generator, control
- [ ] Simple programs run without hazards (NOPs inserted)

## Phase 3 — Hazard Detection and Forwarding
Status: Not started

Acceptance criteria:
- [ ] hazard_unit and forwarding_unit RTL
- [ ] Load-use, RAW and control-hazard tests pass without NOPs

## Phase 4 — Memory Subsystem and Peripheral Integration
Status: Not started

Acceptance criteria:
- [ ] Memories, bus, decoder RTL
- [ ] UART, SPI, timer, interrupt controller RTL
- [ ] Peripheral directed tests

## Phase 5 — Verification and Validation
Status: Not started

Acceptance criteria:
- [ ] Full RV32I directed suite
- [ ] Random regression vs reference ISS
- [ ] Coverage report
- [ ] Assertions

## Phase 6 — Synthesis and Physical Design
Status: Not started

Acceptance criteria:
- [ ] PDK chosen; SDC finalized
- [ ] Yosys netlist and reports
- [ ] OpenROAD flow to routed design
- [ ] STA, DRC, LVS logs; GDSII

## Phase 7 — Optimization and Final Documentation
Status: Not started

Acceptance criteria:
- [ ] Timing/area improvements backed by before/after reports
- [ ] Final report and diagrams
- [ ] Release tag

