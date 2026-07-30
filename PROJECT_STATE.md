# PROJECT_STATE

- **Project:** codex-provider-switcher
- **Version:** 0.1.0-alpha
- **Status:** Local release candidate
- **Git:** Local `main`; `origin` configured
- **Remote:** `WHineu/codex-provider-switcher` created as a public empty repository; first push pending
- **Last verified:** 2026-07-30

## Verified

- Provider discovery is dynamic and contains no vendor-specific routing rules.
- Configuration replacement is locked, atomic, validated, and reversible.
- Symbolic-link configuration targets are rejected before path resolution.
- Active-task confirmation runs before a target adapter is started.
- Loopback adapter ownership checks use provider, upstream, instance ID, and PID.
- All 15 offline and lifecycle tests passed in the promoted workspace on 2026-07-30.
- The native macOS app builds, its plist is valid, embedded resources match source, and strict ad-hoc signature verification passes.
- Scans found no personal paths, credentials, task IDs, or vendor hard-coding in release files.

## Before Public Release

1. Review license attribution and the complete public-release diff.
2. Complete the first public `git push -u origin main` only after explicit authorization.
3. Enable Private Vulnerability Reporting before announcing the repository.
