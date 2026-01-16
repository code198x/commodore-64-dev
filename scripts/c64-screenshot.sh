#!/bin/bash
#
# c64-screenshot - Capture screenshot from C64 program using VICE's native screenshot
#
# Usage:
#   c64-screenshot program.asm output.png [OPTIONS]
#
# Options:
#   --cycles N     CPU cycles before capture (default: 5000000, ~5 seconds)
#   --define K=V   Pass -D flag to assembler (e.g., --define SCREENSHOT_MODE=1)
#   --keybuf S     Inject keystrokes into keyboard buffer (deprecated, use --define)
#
# Requires ROMs in /usr/share/vice/C64/ or mounted to /roms
#
# Examples:
#   c64-screenshot game.asm screenshot.png
#   c64-screenshot game.asm screenshot.png --define SCREENSHOT_MODE=1
#   c64-screenshot game.asm screenshot.png --define SCREENSHOT_MODE=1 --cycles 7000000

set -e

# Default values
CYCLES=5000000
DISPLAY_NUM=99
KEYBUF=""
DEFINES=()

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --cycles)
            CYCLES="$2"
            shift 2
            ;;
        --keybuf)
            KEYBUF="$2"
            shift 2
            ;;
        --define|-D)
            DEFINES+=("$2")
            shift 2
            ;;
        -h|--help)
            echo "Usage: c64-screenshot INPUT OUTPUT [OPTIONS]"
            echo ""
            echo "Capture a screenshot from a C64 program."
            echo "INPUT can be .asm (will be assembled) or .prg (used directly)."
            echo ""
            echo "Arguments:"
            echo "  INPUT   .asm or .prg file"
            echo "  OUTPUT  Output PNG file path"
            echo ""
            echo "Options:"
            echo "  --cycles N     CPU cycles before capture (default: 5000000)"
            echo "  --define K=V   Pass define to assembler (e.g., SCREENSHOT_MODE=1)"
            echo "  --keybuf S     Inject keystrokes (deprecated)"
            echo "  -h, --help     Show this help"
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
    echo "Usage: c64-screenshot INPUT OUTPUT [OPTIONS]"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# Determine PRG file to run
PRG_FILE="$INPUT_FILE"
TEMP_PRG=""

# If input is .asm, assemble it first
if [[ "$INPUT_FILE" == *.asm ]]; then
    TEMP_PRG="/tmp/screenshot_$$.prg"

    # Build ACME command with defines
    ACME_CMD=(acme -f cbm -o "$TEMP_PRG")
    for def in "${DEFINES[@]}"; do
        ACME_CMD+=("-D$def")
    done
    ACME_CMD+=("$INPUT_FILE")

    # Assemble
    if ! "${ACME_CMD[@]}"; then
        echo "Error: Assembly failed"
        exit 1
    fi

    PRG_FILE="$TEMP_PRG"
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
    [[ -n "$TEMP_PRG" ]] && rm -f "$TEMP_PRG"
}
trap cleanup EXIT

# Build VICE command
VICE_CMD=(x64sc -limitcycles "$CYCLES" -exitscreenshot "$OUTPUT_FILE" -autostartprgmode 1 +sound)

# Add keybuf if specified (deprecated)
if [[ -n "$KEYBUF" ]]; then
    VICE_CMD+=(-keybuf "$KEYBUF")
fi

VICE_CMD+=("$PRG_FILE")

# Run VICE with native screenshot (sound disabled for headless)
# VICE exits with code 1 when using -limitcycles, so ignore exit code
"${VICE_CMD[@]}" >/dev/null 2>&1 || true

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
