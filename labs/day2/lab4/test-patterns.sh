#!/usr/bin/env bash
# Prove each EventBridge pattern matches the events it should — using the real
# EventBridge matching engine (aws events test-event-pattern), no deployment needed.
#   ./test-patterns.sh
set -euo pipefail
cd "$(dirname "$0")"
printf '%-34s' "event \\ pattern"
for p in patterns/*.json; do printf '%-14s' "$(basename "$p" .json | cut -c1-12)"; done; echo
for e in tests/events/*.json; do
  printf '%-34s' "$(basename "$e")"
  for p in patterns/*.json; do
    r=$(aws events test-event-pattern --event-pattern "file://$p" --event "file://$e" --query Result --output text)
    [[ "$r" == "True" ]] && printf '%-14s' "  ●" || printf '%-14s' "  ·"
  done
  echo
done
