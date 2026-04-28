################################################################################
# Script: 05_routing.tcl
# Purpose: Global and Detail Routing
################################################################################

# --- 1. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 04_cts -to 05_routing
current_block 05_routing

# --- 2. Routing Execution ---
# route_auto manages global routing, track assignment, and detail routing [cite: 920, 323]
################################################################################
# Script: 05_routing.tcl
# Purpose: Global and Detail Routing
################################################################################
source ./common_setup.tcl

# --- 1. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 04_cts -to 05_routing
current_block 05_routing

# --- 2. Routing Execution ---
# route_auto manages global routing, track assignment, and detail routing [cite: 920, 323]
route_auto 
################################################################################
# Script: 05_routing.tcl
# Purpose: Global and Detail Routing
################################################################################
source ./common_setup.tcl

# --- 1. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 04_cts -to 05_routing
current_block 05_routing


# --- 2. Routing Execution ---
# Manages global routing, track assignment, and detail routing [cite: 920, 323]
route_global
check_routes

route_track
route_detail

# Optional: Incremental cleanup for specific DRC or track-pitch violations
# route_detail -incremental true

# --- 3. Validation & Reporting ---
# Verification ensures the router successfully connected all nets
check_routes > reports/routing_drc.rpt 
report_timing -delay_type setup -max_paths 20 > reports/final_routing_timing.rpt
report_design -summary > reports/final_qor_summary.rpt

# --- 4. Save and Close ---
save_block
puts "Routing stage completed for $DESIGN_NAME"
# Optional: Incremental cleanup for specific DRC or track-pitch violations
# route_detail -incremental true


