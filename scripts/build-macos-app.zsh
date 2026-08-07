#!/bin/zsh

set -eu

readonly ROOT="${0:A:h:h}"
readonly BUILD_DIR="${ROOT}/build"
readonly APP="${BUILD_DIR}/Codex Provider Switcher Preview.app"
readonly CONTENTS="${APP}/Contents"

/bin/rm -rf -- "$APP"
/bin/mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

/usr/bin/clang \
  -fobjc-arc \
  -framework Cocoa \
  -mmacosx-version-min=13.0 \
  "${ROOT}/src/macos-app/main.m" \
  -o "${CONTENTS}/MacOS/CodexProviderSwitcher"

/bin/cp "${ROOT}/src/macos-app/Info.plist" "${CONTENTS}/Info.plist"
/bin/cp "${ROOT}/src/provider_switcher.py" "${CONTENTS}/Resources/provider_switcher.py"
/bin/cp "${ROOT}/src/http11_gateway.py" "${CONTENTS}/Resources/http11_gateway.py"
/bin/cp "${ROOT}/src/run-switcher.zsh" "${CONTENTS}/Resources/run-switcher.zsh"
/bin/chmod 755 "${CONTENTS}/MacOS/CodexProviderSwitcher" "${CONTENTS}/Resources/run-switcher.zsh"
/bin/chmod 644 "${CONTENTS}/Info.plist" "${CONTENTS}/Resources/provider_switcher.py" "${CONTENTS}/Resources/http11_gateway.py"

/usr/bin/plutil -lint "${CONTENTS}/Info.plist"
/usr/bin/codesign --force --deep --sign - "$APP"
/usr/bin/codesign --verify --deep --strict "$APP"

print -- "$APP"
