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
# Convert to Windows form (e.g. C:\Users\…)
BUILD_TCL="$SCRIPT_DIR/build.tcl"
BUILD_TCL_WIN=$(wslpath -w "$BUILD_TCL")

# Check for command line arguments
if [ "$1" == "check" ]; then
    # Only display warnings and errors
    cmd.exe /mnt/d/Vivado/2024.2/bin/vivado.bat -mode tcl -source "$BUILD_TCL_WIN" -quiet 2>&1 | grep -i -E '(warning|error)'
    exit 0
elif [ "$1" == "verbose" ]; then
    # Display everything including info
    cmd.exe /mnt/d/Vivado/2024.2/bin/vivado.bat -mode tcl -source "$BUILD_TCL_WIN" -quiet
    exit 0
fi

cmd.exe /mnt/d/Vivado/2024.2/bin/vivado.bat -mode tcl -source "$BUILD_TCL_WIN" -quiet 2>&1 | grep -v '^INFO:'
