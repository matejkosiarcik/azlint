#!/bin/sh
set -euf
cd "$(dirname "$0")"

castfile="$(mktemp)"
asciinema rec "$castfile" --title 'millipng' --command 'bash demo.sh' --idle-time-limit 2
GIFSICLE_OPTS='-k 16 -O3 --lossy=100' asciicast2gif -t monokai -w 80 -h 15 -s 4 "$castfile" '../demo.gif'
rm -f "$castfile"
