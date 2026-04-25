################################################################################
# Script: 03_placement.tcl
# Purpose: Global and Detail Placement for RISC-V Top
################################################################################

# --- 1. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 02_floorplan -to 03_placement
current_block 03_placement

set_app_options -name place.coarse.fix_hard_macros -value false
set_app_options -name plan.place.auto_create_blockages -value auto
create_placement -buffering_aware_timing_driven -congestion -incremental -effort medium

place_opt
legalize_placement

# Analyse early congestion
report_congestion

# --- 4. Save and Close ---
save_block
puts "Placement stage completed for $DESIGN_NAME"
