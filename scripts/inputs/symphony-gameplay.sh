#!/bin/bash
#
# symphony-gameplay.sh - Gameplay demo for SID Symphony
#
# Shows the song selection menu and starts gameplay.
# The game uses Z/X/C keys for the three lanes.
#
# Environment: VICE_WINDOW is set by c64-video.sh
#

echo "Input script starting, window: $VICE_WINDOW"

# Focus the VICE window and send keys directly to it
xdotool windowactivate --sync "$VICE_WINDOW" 2>/dev/null || true
sleep 0.5

# Press space to skip title screen
xdotool key --window "$VICE_WINDOW" space
sleep 2.5

# Now on song selection menu - press space to start the song
# Press multiple times to ensure it registers
xdotool key --window "$VICE_WINDOW" space
sleep 0.3
xdotool key --window "$VICE_WINDOW" space
sleep 0.3
xdotool key --window "$VICE_WINDOW" space
sleep 1

# Now playing - press Z/X/C to hit notes

# First wave of notes
xdotool key z
sleep 0.4
xdotool key x
sleep 0.4
xdotool key c
sleep 0.4

# Second wave
xdotool key x
sleep 0.3
xdotool key z
sleep 0.3
xdotool key x
sleep 0.3
xdotool key c
sleep 0.4

# Third wave - faster
xdotool key z
sleep 0.25
xdotool key z
sleep 0.25
xdotool key x
sleep 0.25
xdotool key c
sleep 0.25

# More gameplay
xdotool key c
sleep 0.3
xdotool key x
sleep 0.3
xdotool key z
sleep 0.3
xdotool key x
sleep 0.3
xdotool key c
sleep 0.3

# Keep playing
xdotool key z
sleep 0.4
xdotool key x
sleep 0.4
xdotool key z
sleep 0.4
xdotool key c
sleep 0.4
xdotool key x
sleep 0.4

# Final burst
xdotool key z
sleep 0.2
xdotool key x
sleep 0.2
xdotool key c
sleep 0.2
xdotool key z
sleep 0.2
xdotool key x
sleep 0.2
xdotool key c
sleep 0.2
