open_project -read_only -quiet ../project/mygameconsole.xpr

# overwrite
save_project_as temp_project -force -quiet

# update files
remove_files         -quiet [get_files -regexp .*src/.*]
add_files            -quiet ../src
update_compile_order -fileset sources_1 -quiet

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1

reset_run impl_1
launch_runs impl_1
wait_on_run impl_1

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
