################################################################################
# Script: 02_floorplan.tcl
# Purpose: Define chip boundaries, macro placement, and PG Mesh for RISC-V Top
################################################################################

# --- 1. Variable Definitions ---
set DESIGN_NAME     "riscv_top"
set CORE_UTIL       0.7
set ASPECT_RATIO    1.0
set CORE_OFFSET     {10 10 10 10}

# --- 2. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 01_my_lib -to 02_floorplan
current_block 02_floorplan

# --- 3. Initial Floorplanning ---
# Use flags like -core instead of hardcoded coordinates
initialize_floorplan -core_utilization $CORE_UTIL \
                     -row_core_ratio $ASPECT_RATIO \
                     -core_offset $CORE_OFFSET

# --- 4. Macro Placement (e.g., Register File) ---
# Identify macros dynamically using get_cells
set_fixed_objects [get_cells -filter "is_hard_macro==true"]
place_pins -self -ports [get_ports *]

# --- 5. Power Planning ---
create_net VDD
create_net VSS
connect_pg_net -net VDD [get_pins -hierarchical */VDD]
connect_pg_net -net VSS [get_pins -hierarchical */VSS]
# Connect NMOS and PMOS substrates to power and ground nets 
connect_pg_net -net VDD [get_pins -physical_context */VPP]
connect_pg_net -net VSS [get_pins -physical_context */VBB]

# Define rings and straps
create_pg_ring_pattern core_ring_ptrn -horizontal_layer M8 -horizontal_width {2.0} -horizontal_spacing {1.0} -vertical_layer M9 -vertical_width {2.0} -vertical_spacing {1.0}
set_pg_strategy core_ring -pattern {{name: core_ring_ptrn} {nets: {VDD VSS}} {offset: {2 2}}} -core
compile_pg -strategies core_ring

create_pg_mesh_pattern mesh_pattern -layers {{{vertical_layer: M7} {width: 0.6} {pitch: 20} {offset: 20}} {{horizontal_layer: M6} {width: 0.6} {pitch: 20} {offset: 20}}}
set_pg_strategy M7M6_mesh -pattern {{name: mesh_pattern} {nets: VDD VSS}} -core
compile_pg -strategies M7M6_mesh

create_pg_std_cell_conn_pattern rail_pat -layers {M1}
set_pg_strategy rail_strategy -core -pattern {{name: rail_pat} {nets: {VDD VSS}}}
set_pg_strategy_via_rule rail_via_rule -via_rule {{intersection: all} {via_master: NIL}}
compile_pg -strategies {rail_strategy} -via_rule rail_via_rule

# --- 6. Validation & Save ---
check_pg_connectivity -report pg_conn.rpt
check_pg_drc

save_block
puts "Floorplanning completed for $DESIGN_NAME"
