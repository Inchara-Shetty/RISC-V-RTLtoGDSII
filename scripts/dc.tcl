###############################################################
### Design location
##############################################################
set DESIGN "rv32_singlecycle"
set CURR_DIR ""
set RTL_DIR $CURR_DIR/rtl
set LIB_PATH ""
set SDC_PATH $CURR_DIR/sdc/

##############################################################
### Set target lib
###################################################################

set target_library "$LIB_PATH"
set link_library "* $LIB_PATH"

############### Clock gating ###############################

set_clock_gating_style \
    -positive_edge_logic {integrated} \
    -control_point before \
    -minimum_bitwidth 4
    
###################################################################
### Reading RTL
###################################################################
puts "------------Reading RTL------------"

set rtl_files [glob "$RTL_DIR/*.sv"]

if {[llength $RTL_DIR] == 0} {
        error "No RTL files found in $RTL_DIR"
}

analyze -format sverilog  $rtl_files
elaborate $DESIGN

##################################################################
# Initial check
# ###############################################################
current_design $DESIGN
link
check_design

####################################################################
# READ constraints
# ##################################################################
source $SDC_PATH

####################################################################
### Compile #######################################################

compile_ultra -gate_clock

file mkdir reports
file mkdir netlist

report_clock_gating > reports/clock_gating_$DESIGN.rpt
report_timing > reports/timing_$DESIGN.rpt
report_power > reports/power_$DESIGN.rpt
report_area > reports/area_$DESIGN.rpt

write -hierarchy -format verilog -output netlist/$DESIGN_netlist.v
write_sdc netlist/$DESIGN_synth.sdc
