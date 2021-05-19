#!/bin/sh
set -euf
cd "$(dirname "$0")"

castfile="$(mktemp)"
asciinema rec "$castfile" --title 'millipng' --command 'bash demo.sh' --idle-time-limit 2
GIFSICLE_OPTS='-k 8 -O3 --lossy=0 --resize-width 800 --no-comments --no-names --no-extensions' asciicast2gif -t monokai -w 62 -h 12 -s 3 "$castfile" '../demo.gif'
# GIFSICLE_OPTS='-k 8 -O3 --lossy=0 --resize-width 800 --dither --no-comments --no-names --no-extensions' asciicast2gif -t monokai -w 61 -h 12 -s 3 "$castfile" '../demo-dither.gif'
rm -f "$castfile"
