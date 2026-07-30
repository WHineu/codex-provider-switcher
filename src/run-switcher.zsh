#!/bin/zsh

set -eu

readonly SCRIPT_DIR="${0:A:h}"
typeset candidate
typeset -a candidates
candidates=(
  /opt/homebrew/bin/python3
  /usr/local/bin/python3
  /Library/Frameworks/Python.framework/Versions/3.11/bin/python3
  /usr/bin/python3
)

if command -v python3 >/dev/null 2>&1; then
  candidates=("$(command -v python3)" "${candidates[@]}")
fi

for candidate in "${candidates[@]}"; do
  if [[ -x "$candidate" ]] && "$candidate" -c 'import tomllib' >/dev/null 2>&1; then
    exec "$candidate" "${SCRIPT_DIR}/provider_switcher.py" "$@"
  fi
done

print -u2 -- "Python 3.11 or newer is required."
exit 127
