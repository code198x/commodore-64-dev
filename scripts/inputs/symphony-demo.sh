#!/bin/bash
#
# symphony-demo.sh - Demo input for SID Symphony
#
# Skips title screen, selects a song, and starts gameplay.
#
# Environment: VICE_WINDOW is set by c64-video.sh
#

# Focus the VICE window first
xdotool windowactivate --sync "$VICE_WINDOW"
sleep 0.3

# Press space to skip title screen
xdotool key space
sleep 1

# We're now in song selection menu
# Press space again to start the selected song
xdotool key space
sleep 0.5
