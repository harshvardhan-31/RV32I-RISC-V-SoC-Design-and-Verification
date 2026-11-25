# Phase 1 Acceptance Checklist

Tick an item only after review. Record reviewer and date.

## Documentation
- [ ] README describes the project and states that no RTL or results exist yet
- [ ] Project scope with in/out of scope and assumptions
- [ ] SoC architecture and hierarchy
- [ ] Pipeline architecture with pipeline register contents
- [ ] RV32I instruction list with formats
- [ ] Memory map and peripheral register proposal
- [ ] 22-module inventory with inputs, outputs, interfaces and status

## Diagrams (docs/diagrams/*.mmd)
- [ ] SoC block diagram
- [ ] Five-stage pipeline
- [ ] Instruction fetch and decode flow
- [ ] Memory and peripheral interconnect
- [ ] RTL-to-GDSII flow

## Planning
- [ ] Verification plan for ALU, register file, decoder, immediate generator, control unit, pipeline registers, hazard unit, forwarding unit, complete processor
- [ ] Synthesis and physical design preparation document
- [ ] Seven-phase roadmap with acceptance criteria

## Decisions required before Phase 2 RTL
- [ ] Reset vector and reset style
- [ ] Instruction/data memory size and latency
- [ ] Register-file same-cycle write/read behaviour
- [ ] Branch resolution stage and flush policy
- [ ] Misaligned access and illegal instruction behaviour
- [ ] Interrupt/trap contract (or explicit deferral)
- [ ] Simulator and version

## Repository
- [ ] Folder structure committed with README in every empty directory
- [ ] .gitignore excludes generated waveforms and build outputs
- [ ] No file claims implementation, simulation or implementation results

Phase 1 sign-off: ______________________  Date: __________
