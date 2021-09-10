#!/bin/sh
set -euf
cd "$(dirname "$0")"

castfile="$(mktemp)"
asciinema rec "$castfile" --title 'azlint' --command 'bash demo.sh' --idle-time-limit 1.5
GIFSICLE_OPTS='-k 8 -O3 --lossy=80 --resize-width 800 --no-comments --no-names --no-extensions' asciicast2gif -t monokai -w 62 -h 12 -s 4 "$castfile" '../demo.gif'
rm -rf "$castfile"
