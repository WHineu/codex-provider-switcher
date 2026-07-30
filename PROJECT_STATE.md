# PROJECT_STATE

- **Project:** codex-provider-switcher
- **Version:** 0.1.0-alpha
- **Status:** Public release candidate
- **Git:** Local `main`; `origin` configured
- **Remote:** `WHineu/codex-provider-switcher` is public and `main` has been pushed
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

## Before Public Announcement

1. Review license attribution and the complete public-release diff.
2. Enable Private Vulnerability Reporting before announcing the repository.
