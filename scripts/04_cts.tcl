################################################################################
# Script: 04_cts.tcl
# Purpose: Synthesize Clock Trees and Optimize Timing
################################################################################

# --- 1. Design Setup ---
open_lib ${DESIGN_NAME}_lib
copy_block -from 03_placement -to 04_cts
current_block 04_cts

# --- 2. CTS Execution ---
# Synthesizes the clock tree and performs post-CTS timing optimization
clock_opt 

# --- 3. Validation & Reporting ---
# Report Skew (aiming for near-zero) and Insertion Delay [cite: 760]
report_clock_qor > reports/cts_qor.rpt
report_clock_timing -type skew > reports/cts_skew.rpt
report_timing -delay_type setup -max_paths 10 > reports/cts_timing.rpt

# --- 4. Save and Close ---
save_block
puts "CTS stage completed for $DESIGN_NAME"
