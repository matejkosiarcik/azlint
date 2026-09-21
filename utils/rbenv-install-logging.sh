#!/bin/sh

printf '%s\n' "$$" >'./logging-pid.txt'

while true; do
    sleep 60
    printf 'Installing rbenv...\n'
done
