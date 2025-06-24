# Vivado Project Setup Script for 2048 Game Console
# Run this in Vivado TCL console or via script mode

# Project settings
set project_name "mygameconsole"
set project_dir "./project"
set part_name "xc7a35tcpg236-1"  # Adjust according to your FPGA board

# Create project directory if it doesn't exist
file mkdir $project_dir

# Create the project
create_project $project_name $project_dir -part $part_name -force

# Add source files
add_files -norecurse [glob src/*.v]
add_files -norecurse [glob src/*/*.v]
add_files -norecurse [glob src/*/*/*.v]

# Add constraint files
add_files -fileset constrs_1 -norecurse src/io.xdc
add_files -fileset constrs_1 -norecurse src/music/music_io.xdc

# Set top module
set_property top game_console [current_fileset]

# Generate clock wizard IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -module_name clk_wiz_0

# Configure clock wizard
set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {100.000} \
    CONFIG.CLKOUT1_USED {true} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_USED {true} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {40.000} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {10.000} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {10.000} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {25} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {100} \
    CONFIG.NUM_OUT_PORTS {3} \
    CONFIG.CLKOUT1_JITTER {130.958} \
    CONFIG.CLKOUT2_JITTER {151.636} \
    CONFIG.CLKOUT3_JITTER {175.402} \
    CONFIG.CLKOUT1_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT2_PHASE_ERROR {98.575} \
    CONFIG.CLKOUT3_PHASE_ERROR {98.575}] [get_ips clk_wiz_0]

# Generate IP
generate_target all [get_ips clk_wiz_0]
create_ip_run [get_ips clk_wiz_0]
launch_run clk_wiz_0_synth_1
wait_on_run clk_wiz_0_synth_1

# Update compile order
update_compile_order -fileset sources_1

# Save project
save_project

puts "Project setup complete!"
puts "You can now use vivado/vivado.sh to build the project" 