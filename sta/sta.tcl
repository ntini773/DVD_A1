
# ============================================================
# Part C: Static Timing Analysis
# Design: 4-bit unsigned array multiplier
# PDK: SKY130A
# Standard Cell Library: sky130_fd_sc_hd
# Corner: Typical (25 C, 1.80 V)
# ============================================================

# 1. Load SKY130 timing library
set lib "$::env(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

read_liberty $lib

# 2. Load synthesized gate-level netlist
read_verilog synth/mult_array_netlist.v
link_design mult_array

# 3. Configurable clock period (default = 10 ns)
set T 10.0

if {[info exists ::env(STA_PERIOD)]} {
    set T $::env(STA_PERIOD)
}

puts "========================================"
puts " Clock period: $T ns"
puts "========================================"

create_clock -name clk -period $T [get_ports clk]

# 4. Input and output timing constraints
set_input_delay 1.0 -clock clk \
    [delete_from_list [all_inputs] [get_ports clk]]

set_output_delay 1.0 -clock clk [all_outputs]

# 5. Timing summary
puts "\n========== WORST SETUP SLACK =========="
report_worst_slack -max

# 6. Detailed critical path report
set report_file "sta/mult_array_timing.rpt"

if {[info exists ::env(STA_REPORT)]} {
    set report_file $::env(STA_REPORT)
}

report_checks -path_delay max -digits 3 \
    > $report_file

puts "\nTiming report saved to: $report_file"
puts "========================================"
