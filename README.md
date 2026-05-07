# RISC-V SoC Physical Implementation

## An RTL-to-GDSII implementation of a RISC-V core using Synopsys IC Compiler II.

## 🚀 Overview
This project demonstrates a complete physical design flow, transforming a synthesized gate-level netlist of a RISC-V processor into a manufacturing-ready GDSII layout. The design focuses on optimizing PPA while ensuring strict adherence to DRC/LVS requirements for the [TSMC N16 technology] process.

Key Features
Architecture: 32-bit RISC-V (RV32I) Core.

Toolchain: Synopsys ICC2 (Physical Design), Design Compiler (Synthesis), PrimeTime (STA).

Technology: [e.g., TSMC 16nm / Sky130] NDM-based flow.

Highlights: Low-power design techniques, Custom PG-mesh design, automated CTS tree, and congestion-aware routing.

## 🏗 Physical Design Flow
The implementation follows a modular TCL-based approach to ensure reproducibility and design portability.

Stage | Script | Key Tasks
|-----|--------|----------|
01 Setup | 01_setup_design.tcl | Library linking (NDM), PVT corner definition.
02 Floorplan | 02_floorplan.tcl | Macro placement, I/O pin assignment, PG-Mesh creation.
03 Placement | 03_placement.tcl | Global & Detail placement, high-fanout net synthesis.
04 CTS | 04_cts.tcl | Clock tree synthesis, skew minimization ($< 50ps$).
05 Route | 05_routing.tcl | detail routing, DRC/LVS cleanup.
06 Sign-off | 06_finish.tcl | STA, Power analysis, GDSII export.


## 🛠 Setup & Usage
Prerequisites: 
Synopsys Library Compiler, Design Compiler, IC Compiler II.

Access to the [TSMC N16] PDK.

Note:
To maintain NDA compliance and portability, this repo uses environment variables for library paths. Set your PDK path before running.

## 📝 Lessons Learned
Congestion Management: Resolved track-pitch violations (ZRT-026) by implementing routing blockages around high-density macro pins.

PG Connectivity: Solved floating component issues by standardizing connect_pg_net strategies for tie-high/tie-low cells.

Clock Skew: Optimized clock tree by manually balancing levels across symmetrical logic clusters.
