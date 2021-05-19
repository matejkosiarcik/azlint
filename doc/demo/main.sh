#!/bin/sh
set -euf
cd "$(dirname "$0")"

castfile="$(mktemp)"
asciinema rec "$castfile" --title 'millipng' --command 'bash demo.sh' --idle-time-limit 1.5

gifdir="$(mktemp -d)"
GIFSICLE_OPTS='-k 8 -O3 --lossy=0 --resize-width 800 --no-comments --no-names --no-extensions' asciicast2gif -t monokai -w 62 -h 12 -s 4 "$castfile" "$gifdir/normal.gif"
GIFSICLE_OPTS='-k 8 -O3 --lossy=0 --resize-width 800 --dither --no-comments --no-names --no-extensions' asciicast2gif -t monokai -w 61 -h 12 -s 4 "$castfile" "$gifdir/dither.gif"

if [ "$(wc -c <"$gifdir/dither.gif")" -lt "$(wc -c <"$gifdir/normal.gif")" ]; then
    printf 'dither is smaller\n' >&2
    cp "$gifdir/dither.gif" '../demo.gif'
else
    printf 'no-dither is smaller\n' >&2
    cp "$gifdir/normal.gif" '../demo.gif'
fi

rm -rf "$castfile" "$gifdir"
