#############################################################
# Script: design_setup.tcl
# Purpose: Setting up the NDM, library, and design inputs
#############################################################
set TOP riscv

create_lib my_lib \
  -technology <path_to_tech_file>.tf \
  -ref_libs <path_to_ndm_file>.ndm

open_lib my_lib

read_verilog <path_to_netlist>.v

read_sdc <path_to_sdc_file>.sdc

current_design $TOP

link_block

check_design -checks mv_design
