#!/bin/bash

# 2048 Game Console - Complete Build and Run Script
# This script sets up the entire project from scratch

echo "🎮 2048 Game Console Build Script"
echo "================================="

# Get script directory
SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in WSL
if grep -qi microsoft /proc/version; then
    print_status "Detected WSL environment"
    WSL_ENV=true
else
    print_warning "Not running in WSL - adjust Vivado paths if needed"
    WSL_ENV=false
fi

# Step 1: Check prerequisites
print_status "Checking prerequisites..."

# Check if Vivado is available
if [ "$WSL_ENV" = true ]; then
    VIVADO_PATH="/mnt/d/Vivado/2024.2/bin/vivado.bat"
    if [ ! -f "$VIVADO_PATH" ]; then
        print_error "Vivado not found at $VIVADO_PATH"
        print_error "Please install Xilinx Vivado 2024.2 or update the path in this script"
        exit 1
    fi
else
    if ! command -v vivado &> /dev/null; then
        print_error "Vivado not found in PATH"
        exit 1
    fi
fi

print_success "Vivado found"

# Step 2: Create project if it doesn't exist
if [ ! -f "project/mygameconsole.xpr" ]; then
    print_status "Creating new Vivado project..."
    
    if [ "$WSL_ENV" = true ]; then
        SETUP_TCL_WIN=$(wslpath -w "$SCRIPT_DIR/setup_project.tcl")
        cmd.exe /mnt/d/Vivado/2024.2/bin/vivado.bat -mode tcl -source "$SETUP_TCL_WIN" -quiet
    else
        vivado -mode tcl -source setup_project.tcl -quiet
    fi
    
    if [ -f "project/mygameconsole.xpr" ]; then
        print_success "Project created successfully"
    else
        print_error "Failed to create project"
        exit 1
    fi
else
    print_status "Project already exists"
fi

# Step 3: Build the project
print_status "Building project..."

case "${1:-build}" in
    "setup")
        print_success "Project setup complete!"
        echo
        echo "📋 Next steps:"
        echo "1. Review and adjust constraint files (src/io.xdc) for your FPGA board"
        echo "2. Run './run_project.sh build' to synthesize"
        echo "3. Run './run_project.sh program' to program the FPGA"
        ;;
        
    "build")
        print_status "Running synthesis..."
        ./vivado/vivado.sh
        if [ $? -eq 0 ]; then
            print_success "Synthesis completed successfully!"
            echo
            echo "📋 Next steps:"
            echo "1. Run './run_project.sh implement' to run implementation"
            echo "2. Run './run_project.sh bitstream' to generate bitstream"
        else
            print_error "Synthesis failed"
            exit 1
        fi
        ;;
        
    "implement")
        print_status "Running implementation..."
        # Update build.tcl to run implementation
        sed -i 's/# reset_run impl_1/reset_run impl_1/' vivado/build.tcl
        sed -i 's/# launch_runs impl_1/launch_runs impl_1/' vivado/build.tcl
        sed -i 's/# wait_on_run impl_1/wait_on_run impl_1/' vivado/build.tcl
        ./vivado/vivado.sh
        print_success "Implementation completed!"
        ;;
        
    "bitstream")
        print_status "Generating bitstream..."
        # Update build.tcl to generate bitstream
        sed -i 's/# reset_run impl_1/reset_run impl_1/' vivado/build.tcl
        sed -i 's/# launch_runs impl_1 -to_step write_bitstream/launch_runs impl_1 -to_step write_bitstream/' vivado/build.tcl
        sed -i 's/# wait_on_run impl_1/wait_on_run impl_1/' vivado/build.tcl
        ./vivado/vivado.sh
        print_success "Bitstream generated!"
        echo
        echo "🎯 Bitstream file location:"
        echo "   build/temp_project.runs/impl_1/game_console.bit"
        ;;
        
    "clean")
        print_status "Cleaning build files..."
        ./vivado/vivado.sh clean
        rm -rf project/
        print_success "Clean completed!"
        ;;
        
    "test")
        print_status "Running testbench..."
        cd src/test
        if command -v iverilog &> /dev/null; then
            iverilog -o tb_enhanced_2048 tb_enhanced_2048.v ../game_console.v ../game_2048_main.v ../game_2048_core.v ../display/*.v ../keyboard/*.v ../memory/*.v ../music/*.v
            ./tb_enhanced_2048
            print_success "Testbench completed!"
        else
            print_warning "Icarus Verilog not found - please run simulation in Vivado"
        fi
        cd ../..
        ;;
        
    *)
        echo "Usage: $0 {setup|build|implement|bitstream|clean|test}"
        echo
        echo "Commands:"
        echo "  setup     - Create initial project (first run)"
        echo "  build     - Run synthesis only"
        echo "  implement - Run synthesis + implementation"
        echo "  bitstream - Run full flow to generate programming file"
        echo "  clean     - Clean all build files"
        echo "  test      - Run simulation testbench"
        echo
        echo "💡 For first-time setup, run: $0 setup"
        ;;
esac

echo
print_status "Script completed!" 