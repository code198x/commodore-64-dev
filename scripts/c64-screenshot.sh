#!/bin/bash
#
# c64-screenshot - Capture screenshot from C64 program using VICE's native screenshot
#
# Usage:
#   c64-screenshot program.prg output.png [--cycles N]
#
# Options:
#   --cycles N   Number of CPU cycles to run before capture (default: 5000000, ~5 seconds)
#
# Requires ROMs in /usr/share/vice/C64/ or mounted to /roms
#
# Examples:
#   c64-screenshot game.prg screenshot.png
#   c64-screenshot game.prg screenshot.png --cycles 10000000

set -e

# Default values
CYCLES=5000000
DISPLAY_NUM=99

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cycles)
            CYCLES="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: c64-screenshot INPUT OUTPUT [OPTIONS]"
            echo ""
            echo "Capture a screenshot from a C64 program using VICE's native screenshot."
            echo ""
            echo "Arguments:"
            echo "  INPUT   .prg program file"
            echo "  OUTPUT  Output PNG file path"
            echo ""
            echo "Options:"
            echo "  --cycles N   CPU cycles before capture (default: 5000000)"
            echo "  -h, --help   Show this help"
            exit 0
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            elif [[ -z "$OUTPUT_FILE" ]]; then
                OUTPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$INPUT_FILE" ]] || [[ -z "$OUTPUT_FILE" ]]; then
    echo "Error: INPUT and OUTPUT files required"
    echo "Usage: c64-screenshot INPUT.prg OUTPUT.png [--cycles N]"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Copy ROMs if mounted at /roms
if [[ -d /roms ]]; then
    cp /roms/* /usr/share/vice/C64/ 2>/dev/null || true
fi

# Start virtual framebuffer
Xvfb :${DISPLAY_NUM} -screen 0 1024x768x24 >/dev/null 2>&1 &
XVFB_PID=$!
sleep 1

# Set display
export DISPLAY=:${DISPLAY_NUM}

# Cleanup function
cleanup() {
    kill $XVFB_PID 2>/dev/null || true
}
trap cleanup EXIT

# Run VICE with native screenshot (sound disabled for headless)
# VICE exits with code 1 when using -limitcycles, so ignore exit code
x64sc \
    -limitcycles "$CYCLES" \
    -exitscreenshot "$OUTPUT_FILE" \
    -autostartprgmode 1 \
    +sound \
    "$INPUT_FILE" >/dev/null 2>&1 || true

# Check result and scale to 2x
if [[ -f "$OUTPUT_FILE" ]]; then
    # Scale to 2x using nearest neighbor for crisp pixels
    # Use magick if available (IMv7), fallback to convert (IMv6)
    if command -v magick &> /dev/null; then
        magick "$OUTPUT_FILE" -scale 200% "$OUTPUT_FILE"
    else
        convert "$OUTPUT_FILE" -scale 200% "$OUTPUT_FILE"
    fi
    echo "Screenshot saved: $OUTPUT_FILE"
else
    echo "Error: Screenshot not created"
    exit 1
fi
