# Usage: vivado -mode batch -source tools/run_vivado.tcl
# Optional environment: MIPS_FPGA_PART, MIPS_CLOCK_NS.
# Out-of-context IP validation; no board pinout or bitstream is implied.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root build vivado]
file mkdir $out
set part xc7z020clg400-1
if {[info exists ::env(MIPS_FPGA_PART)]} {set part $::env(MIPS_FPGA_PART)}
set period 20.0
if {[info exists ::env(MIPS_CLOCK_NS)]} {set period $::env(MIPS_CLOCK_NS)}
create_project -force member1_validation [file join $out project] -part $part
set_property target_language VHDL [current_project]
foreach source {rtl/mips32_scan_pkg.vhd rtl/scan_register_bank.vhd rtl/mips32_core.vhd} {
    read_vhdl -vhdl2008 [file join $root $source]
}
set_property top mips32_core [get_filesets sources_1]
add_files -fileset sim_1 [list [file join $root tb tb_mips32_core.vhd] [file join $root tb tb_scan_register_bank.vhd]]
set_property file_type {VHDL 2008} [get_files -of_objects [get_filesets sim_1] -filter {NAME =~ *.vhd}]
set_property xsim.simulate.runtime 100us [get_filesets sim_1]
set_property top tb_mips32_core [get_filesets sim_1]
# Vivado invokes generated .bat files by basename. Explicitly trust only this
# generated simulation directory when Windows disables implicit CWD lookup.
if {$::tcl_platform(platform) eq "windows"} {
    set simdir [file nativename [file join $out project member1_validation.sim sim_1 behav xsim]]
    set ::env(PATH) "$simdir;$::env(PATH)"
}
launch_simulation -simset sim_1 -mode behavioral
close_sim
file copy -force [file join $out project member1_validation.sim sim_1 behav xsim simulate.log] [file join $out core_simulation.log]
foreach chains {4 3} {
    set_property top tb_scan_register_bank [get_filesets sim_1]
    set_property generic "BITS=1024 CHAINS=$chains" [get_filesets sim_1]
    launch_simulation -simset sim_1 -mode behavioral
    close_sim
    file copy -force [file join $out project member1_validation.sim sim_1 behav xsim simulate.log] [file join $out scan_${chains}_simulation.log]
}
# Fail the batch if any self-checking simulation did not reach its PASS report.
foreach name {core scan_4 scan_3} {
    set f [open [file join $out ${name}_simulation.log] r]
    set contents [read $f]
    close $f
    if {![string match *PASS* $contents] || [regexp -nocase {failure:|fatal:} $contents]} {
        error "Simulation $name did not pass; inspect saved log"
    }
}
synth_design -top mips32_core -part $part -mode out_of_context -flatten_hierarchy rebuilt
create_clock -name core_clk -period $period [get_ports clk]
write_checkpoint -force [file join $out core_synth.dcp]
report_utilization -file [file join $out utilization_synth.rpt]
report_timing_summary -file [file join $out timing_synth.rpt]
opt_design
place_design
route_design
write_checkpoint -force [file join $out core_routed.dcp]
report_utilization -file [file join $out utilization_routed.rpt]
report_timing_summary -file [file join $out timing_routed.rpt]
report_drc -file [file join $out drc_routed.rpt]
report_power -file [file join $out power_vectorless.rpt]
set f [open [file join $out run_summary.txt] w]
puts $f "Part: $part\nClock period ns: $period\nMode: out_of_context\nSimulations: core, 1024-bit/4-chain, 1024-bit/3-chain\nImplementation: synthesis, optimization, placement, routing\nPower: vectorless estimate; not measured LBIST power\nNo board pin constraints, external I/O timing constraints, or bitstream."
close $f
puts "MEMBER1_VIVADO_COMPLETE: reports in $out"
close_project
