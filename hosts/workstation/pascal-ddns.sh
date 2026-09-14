#!/bin/sh
export PATH=/run/current-system/sw/bin:/run/wrappers/bin
sleep "$(od -An -N2 -tu2 /dev/urandom | awk -v max=291 '{ gsub(/[[:space:]]/, "", $0); print $0 - max * int($0 / max) }')"
ip a | curl -fsS -X POST http://pascal08.svr.pascal-lab.net:8788/api/v1/report \
  -H 'Authorization: Bearer REDACTED' \
  -H 'Content-Type: text/plain; charset=utf-8' \
  --data-binary @- >/dev/null
