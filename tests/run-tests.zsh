#!/bin/zsh

set -eu

readonly ROOT="${0:A:h:h}"
exec python3 -m unittest discover -s "${ROOT}/tests" -p 'test_*.py' -v
