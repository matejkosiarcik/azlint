#!/bin/sh

printf '%s\n' "$$" >'./logging-pid.txt'

while true; do
    sleep 30
    printf '%s - Installing rbenv...\n' "$(date +'%Y-%m-%d_%H-%M-%S')"
done
