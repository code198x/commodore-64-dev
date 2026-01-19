#!/bin/bash
#
# c64-video - Capture video from C64 program with input injection
#
# Usage:
#   c64-video program.asm output.mp4 [OPTIONS]
#   c64-video program.prg output.mp4 [OPTIONS]
#
# Options:
#   --wait SECONDS     Wait time before recording (default: 5)
#   --duration SECONDS Recording duration (default: 10)
#   --fps N            Frame rate (default: 50 for PAL)
#   --scale N          Scale factor 1-4 (default: 2)
#   --input SCRIPT     Input script to run after wait
#   --define K=V       Pass define to assembler (can repeat)
#   --joystick PORT    Joystick port 1 or 2 (default: 2)
#
# Input Scripts:
#   Input scripts are shell scripts that receive no arguments.
#   They run in the same X display as the emulator.
#   Use xdotool to send input:
#
#     #!/bin/bash
#     xdotool key Return         # Press key
#     sleep 0.5
#     xdotool key Up Up Up       # Multiple presses
#
#   Joystick mapping (depends on --joystick port):
#     Arrow keys = directions
#     Right Ctrl = fire
#
# Examples:
#   c64-video game.asm gameplay.mp4
#   c64-video game.asm demo.mp4 --wait 3 --duration 20
#   c64-video game.asm demo.mp4 --input scripts/inputs/gameplay-demo.sh
#   c64-video game.asm demo.mp4 --define SCREENSHOT_MODE=1

set -e

# Default values
WAIT_TIME=5
DURATION=10
FPS=50
SCALE=2
DISPLAY_NUM=99
JOYSTICK_PORT=2
INPUT_SCRIPT=""
DEFINES=()

# Parse arguments
INPUT_FILE=""
OUTPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --fps)
            FPS="$2"
            shift 2
            ;;
        --scale)
            SCALE="$2"
            shift 2
            ;;
        --input)
            INPUT_SCRIPT="$2"
            shift 2
            ;;
        --define|-D)
            DEFINES+=("$2")
            shift 2
            ;;
        --joystick)
            JOYSTICK_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: c64-video INPUT OUTPUT [OPTIONS]"
            echo ""
            echo "Capture video from a C64 program with input injection."
            echo ""
            echo "Arguments:"
            echo "  INPUT   .asm or .prg file"
            echo "  OUTPUT  Output video file (mp4, webm, gif)"
            echo ""
            echo "Options:"
            echo "  --wait SECONDS     Wait before recording (default: 5)"
            echo "  --duration SECONDS Recording length (default: 10)"
            echo "  --fps N            Frame rate (default: 50)"
            echo "  --scale N          Scale factor 1-4 (default: 2)"
            echo "  --input SCRIPT     Input script for key injection"
            echo "  --define K=V       Pass define to assembler"
            echo "  --joystick PORT    Joystick port 1 or 2 (default: 2)"
            echo "  -h, --help         Show this help"
            echo ""
            echo "Joystick mapping (arrow keys + Right Ctrl for fire)"
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
    echo "Usage: c64-video INPUT OUTPUT [OPTIONS]"
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

if [[ -n "$INPUT_SCRIPT" ]] && [[ ! -f "$INPUT_SCRIPT" ]]; then
    echo "Error: Input script not found: $INPUT_SCRIPT"
    exit 1
fi

# Determine PRG file to run
PRG_FILE="$INPUT_FILE"
TEMP_PRG=""

# If input is .asm, assemble it first
if [[ "$INPUT_FILE" == *.asm ]]; then
    TEMP_PRG="/tmp/video_$$.prg"

    # Build ACME command with defines
    ACME_CMD=(acme -f cbm -o "$TEMP_PRG")
    for def in "${DEFINES[@]}"; do
        ACME_CMD+=("-D$def")
    done
    ACME_CMD+=("$INPUT_FILE")

    echo "Assembling: ${ACME_CMD[*]}"
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

# Determine output format from extension
OUT_EXT="${OUTPUT_FILE##*.}"
OUT_EXT="${OUT_EXT,,}"

case "$OUT_EXT" in
    mp4)
        # crop=trunc(iw/2)*2:trunc(ih/2)*2 ensures even dimensions for h264
        FFMPEG_CODEC="-vf crop=trunc(iw/2)*2:trunc(ih/2)*2 -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p"
        ;;
    webm)
        FFMPEG_CODEC="-vf crop=trunc(iw/2)*2:trunc(ih/2)*2 -c:v libvpx-vp9 -crf 30 -b:v 0"
        ;;
    gif)
        FFMPEG_CODEC="-vf fps=25,scale=320:-2:flags=lanczos"
        ;;
    *)
        echo "Warning: Unknown output format '$OUT_EXT', using mp4 settings"
        FFMPEG_CODEC="-vf crop=trunc(iw/2)*2:trunc(ih/2)*2 -c:v libx264 -preset fast -crf 18 -pix_fmt yuv420p"
        ;;
esac

# Calculate window size (C64 PAL: 384x272 visible area, but VICE uses 320x200 by default)
# Use 384x272 for proper PAL with borders
WIDTH=$((384 * SCALE))
HEIGHT=$((272 * SCALE))

# Start virtual framebuffer (add generous padding for window decorations + position offset)
# VICE GTK3 windows can be 720x644 and positioned at ~(80,40), so need ~800x700 minimum
SCREEN_W=$((WIDTH + 300))
SCREEN_H=$((HEIGHT + 300))
Xvfb :${DISPLAY_NUM} -screen 0 ${SCREEN_W}x${SCREEN_H}x24 >/dev/null 2>&1 &
XVFB_PID=$!
sleep 1

# Set display
export DISPLAY=:${DISPLAY_NUM}

# Start window manager (required for xdotool input injection)
openbox >/dev/null 2>&1 &
OPENBOX_PID=$!
sleep 0.5

# Cleanup function
cleanup() {
    kill $VICE_PID 2>/dev/null || true
    kill $OPENBOX_PID 2>/dev/null || true
    kill $XVFB_PID 2>/dev/null || true
    [[ -n "$TEMP_PRG" ]] && rm -f "$TEMP_PRG"
}
trap cleanup EXIT

# Total runtime needed
TOTAL_TIME=$((WAIT_TIME + DURATION + 10))

# Map joystick to keyboard (arrow keys for directions, Right Ctrl for fire)
# VICE uses numpad by default for joystick, but we'll configure arrow keys
JOYSTICK_OPTS=""
if [[ "$JOYSTICK_PORT" == "1" ]]; then
    JOYSTICK_OPTS="-joydev1 5"  # 5 = keyboard (arrow keys)
else
    JOYSTICK_OPTS="-joydev2 5"
fi

# Run VICE with GUI (needed for window capture)
# Note: Don't use -geometry as GTK3 VICE ignores it and may fail to create window
# +VICIIshowstatusbar hides the status bar for cleaner capture
# -sound enables audio, -sounddev pulse outputs to PulseAudio for capture
echo "Starting VICE emulator..."

# Start PulseAudio if not running (needed for audio capture)
pulseaudio --check 2>/dev/null || pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
sleep 1

# Create a null sink for capturing audio output
# VICE outputs to this sink, and we capture from its monitor
pactl load-module module-null-sink sink_name=vice_capture sink_properties=device.description=VICECapture 2>/dev/null || true
sleep 0.5

# Get the monitor source name for capturing
AUDIO_SOURCE="vice_capture.monitor"

# Set VICE to output to our capture sink
export PULSE_SINK=vice_capture

# Create temp file for audio recording
TEMP_AUDIO="/tmp/vice_audio_$$.wav"

timeout ${TOTAL_TIME}s x64sc \
    -sound \
    -sounddev wav \
    -soundarg "$TEMP_AUDIO" \
    -soundrate 48000 \
    +VICIIshowstatusbar \
    -autostartprgmode 1 \
    $JOYSTICK_OPTS \
    "$PRG_FILE" >/dev/null 2>&1 &
VICE_PID=$!

# Wait for VICE to start and create window (GTK3 init takes ~3-4 seconds)
sleep 4

# Move VICE's audio output to our capture sink
# Find VICE's sink input and redirect it
for i in {1..10}; do
    SINK_INPUT=$(pactl list sink-inputs short 2>/dev/null | grep -i "x64\|vice" | head -1 | cut -f1)
    if [[ -n "$SINK_INPUT" ]]; then
        pactl move-sink-input "$SINK_INPUT" vice_capture 2>/dev/null && echo "Redirected VICE audio to capture sink"
        break
    fi
    # If no named match, try to find any sink input
    SINK_INPUT=$(pactl list sink-inputs short 2>/dev/null | head -1 | cut -f1)
    if [[ -n "$SINK_INPUT" ]]; then
        pactl move-sink-input "$SINK_INPUT" vice_capture 2>/dev/null && echo "Redirected audio to capture sink"
        break
    fi
    sleep 0.5
done

# Find VICE window (try both "VICE" and "x64" names)
VICE_WINDOW=""
for i in {1..20}; do
    VICE_WINDOW=$(xdotool search --name "VICE" 2>/dev/null | head -1)
    if [[ -z "$VICE_WINDOW" ]]; then
        VICE_WINDOW=$(xdotool search --name "x64" 2>/dev/null | head -1)
    fi
    if [[ -n "$VICE_WINDOW" ]]; then
        echo "Found VICE window: $VICE_WINDOW"
        break
    fi
    sleep 0.5
done

if [[ -z "$VICE_WINDOW" ]]; then
    echo "Warning: Could not find VICE window, input injection may not work"
fi

# Wait for C64 to boot and program to start
echo "Waiting ${WAIT_TIME}s for boot..."
sleep "$WAIT_TIME"

# Run input script if provided
if [[ -n "$INPUT_SCRIPT" ]]; then
    echo "Running input script: $INPUT_SCRIPT"
    # Export window ID for scripts that want it
    export VICE_WINDOW
    bash "$INPUT_SCRIPT"
    sleep 0.5
fi

echo "Recording ${DURATION}s of video..."

# Get window geometry for precise capture
GRAB_X=0
GRAB_Y=0
GRAB_W=$WIDTH
GRAB_H=$HEIGHT

if [[ -n "$VICE_WINDOW" ]]; then
    # Get actual window geometry
    GEOM=$(xdotool getwindowgeometry "$VICE_WINDOW" 2>/dev/null)
    if [[ -n "$GEOM" ]]; then
        # Parse "  Position: X,Y (screen: 0)" and "  Geometry: WxH"
        GRAB_X=$(echo "$GEOM" | grep Position | sed 's/.*Position: \([0-9]*\),.*/\1/')
        GRAB_Y=$(echo "$GEOM" | grep Position | sed 's/.*Position: [0-9]*,\([0-9]*\).*/\1/')
        GEOM_SIZE=$(echo "$GEOM" | grep Geometry | sed 's/.*Geometry: \([0-9]*\)x\([0-9]*\).*/\1x\2/')
        GRAB_W=$(echo "$GEOM_SIZE" | cut -dx -f1)
        GRAB_H=$(echo "$GEOM_SIZE" | cut -dx -f2)
        echo "Window geometry: ${GRAB_W}x${GRAB_H} at ${GRAB_X},${GRAB_Y}"
    fi
fi

# Capture video only (audio is being recorded by VICE to WAV)
TEMP_VIDEO="/tmp/vice_video_$$.mp4"
ffmpeg -y \
    -f x11grab \
    -framerate "$FPS" \
    -video_size "${GRAB_W}x${GRAB_H}" \
    -i ":${DISPLAY_NUM}+${GRAB_X},${GRAB_Y}" \
    -t "$DURATION" \
    $FFMPEG_CODEC \
    "$TEMP_VIDEO" \
    2>/dev/null

# Wait for VICE to finish writing audio
sleep 1
kill $VICE_PID 2>/dev/null || true
sleep 1

# Merge video with VICE's audio recording
if [[ -f "$TEMP_AUDIO" ]] && [[ -s "$TEMP_AUDIO" ]]; then
    echo "Merging video with SID audio..."
    ffmpeg -y \
        -i "$TEMP_VIDEO" \
        -i "$TEMP_AUDIO" \
        -c:v copy \
        -c:a aac -b:a 192k \
        -shortest \
        "$OUTPUT_FILE" \
        2>/dev/null
    rm -f "$TEMP_VIDEO" "$TEMP_AUDIO"
else
    echo "Warning: No audio recorded, using video only"
    mv "$TEMP_VIDEO" "$OUTPUT_FILE"
    rm -f "$TEMP_AUDIO"
fi

# Report result
if [[ -f "$OUTPUT_FILE" ]]; then
    SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
    echo "Video saved: $OUTPUT_FILE ($SIZE)"
else
    echo "Error: Failed to create video"
    exit 1
fi
