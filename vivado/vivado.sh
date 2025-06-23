#!/bin/bash

# change cwd to the build folder
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd $SCRIPT_DIR/..

# If "clean" is passed as an argument, perform cleanup
if [ "$1" == "clean" ]; then
    rm -rf build
    echo "Build directory cleaned"
    exit 0
fi

mkdir -p build
cd build

# wsl assumed
BUILD_TCL="$SCRIPT_DIR/build.tcl"

# Convert to Windows form (e.g. C:\Users\…)
BUILD_TCL_WIN=$(wslpath -w "$BUILD_TCL")

cmd.exe /mnt/c/Xilinx/Vivado/2024.1/bin/vivado.bat -mode tcl -source "$BUILD_TCL_WIN" -quiet
