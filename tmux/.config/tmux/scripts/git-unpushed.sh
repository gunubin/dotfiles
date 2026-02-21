#!/bin/sh
cd "$1" 2>/dev/null || exit 0
CNT=$(git rev-list @{u}..HEAD 2>/dev/null | wc -l | tr -d ' ')
[ "$CNT" -gt 0 ] && printf '↑%s' "$CNT"
