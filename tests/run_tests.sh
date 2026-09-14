#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
nvim --headless -u NONE -c "luafile $SCRIPT_DIR/test_related_files.lua"
