# --------------------------------------------
# Basic single-cycle RISC-V core constraints
# --------------------------------------------

# Clock definition (100 MHz => 10ns period)
create_clock -name clk -period 10.000 [get_ports clk]

# Add clock uncertainty (jitter + modeling margin)
set_clock_uncertainty 0.500 [get_clocks clk]

# Clock transition (slew) assumption
set_clock_transition 0.100 [get_clocks clk]

# --------------------------------------------
# I/O delays
# (Assume the core is inside a SoC, external env launches/captures)
# --------------------------------------------

set_input_delay  1.000 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 1.000 -clock clk [all_outputs]

# --------------------------------------------
# Drive/load models (optional but recommended)
# --------------------------------------------
# Set input transition on inputs (excluding clk)
set_input_transition 0.100 [remove_from_collection [all_inputs] [get_ports clk]]

# Set output load (cap) for outputs
set_load 0.050 [all_outputs]

# --------------------------------------------
# Design rule constraints (help synthesis)
# --------------------------------------------
set_max_transition 0.250 [current_design]
set_max_fanout     16    [current_design]
set_max_capacitance 0.200 [current_design]

# --------------------------------------------
# Reset is async and not timed:
# --------------------------------------------
set_false_path -from [get_ports resetn]
