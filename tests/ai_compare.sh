#!/bin/sh
# Vergleich der KI-Stärken auf allen Bahnen (parallel). Aufruf aus dem Projektordner:
#   sh tests/ai_compare.sh <godot> <ausgabeordner>
G=$1; OUT=$2
for l in levels/*.tscn; do
  n=$(basename $l .tscn)
  (timeout 1500 $G --headless --fixed-fps 60 --path . --script res://tests/ai_race.gd -- res://$l mix 2>&1 | grep -E "^=== [A-Z]|^  [A-Z]|SCRIPT|Invalid" > $OUT/ai_$n.log) &
done
wait
cat $OUT/ai_*.log
