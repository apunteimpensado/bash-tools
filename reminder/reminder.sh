#!/bin/bash

duration=${1:-540}  # Use first argument or default to 10
sleep $duration && notify-send "Timer Complete" "$duration second timer finished."