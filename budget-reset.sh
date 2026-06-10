#!/usr/bin/env bash
# Deprecated: use `budget reset`. Kept for backwards compatibility.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/budget" reset "$@"
