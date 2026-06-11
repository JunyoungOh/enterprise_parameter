#!/usr/bin/env bash
# Deprecated: use `budget reset`. Kept for backwards compatibility.
src="$0"
while [ -L "$src" ]; do
  d="$(cd "$(dirname "$src")" && pwd)"
  src="$(readlink "$src")"
  case "$src" in /*) ;; *) src="$d/$src" ;; esac
done
HERE="$(cd "$(dirname "$src")" && pwd)"
exec "$HERE/budget" reset "$@"
