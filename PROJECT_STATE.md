# PROJECT_STATE

- **Project:** codex-provider-switcher
- **Version:** 0.1.0-alpha
- **Status:** Local release candidate
- **Git:** Local `main`; no remote
- **Remote:** Not created
- **Last verified:** 2026-07-30

## Verified

- Provider discovery is dynamic and contains no vendor-specific routing rules.
- Configuration replacement is locked, atomic, validated, and reversible.
- Symbolic-link configuration targets are rejected before path resolution.
- Active-task confirmation runs before a target adapter is started.
- Loopback adapter ownership checks use provider, upstream, instance ID, and PID.
- All 15 offline and lifecycle tests passed in the source workspace before promotion.
- In the promoted workspace, 11 non-network tests passed; four lifecycle tests were blocked by a sandbox that denied loopback binding, with no assertion failures.
- The native macOS app builds, its plist is valid, embedded resources match source, and strict ad-hoc signature verification passes.
- Scans found no personal paths, credentials, task IDs, or vendor hard-coding in release files.

## Before Public Release

1. Confirm repository name and maintainer security contact.
2. Review license attribution and the complete initial Git diff.
3. Create the public repository only after explicit authorization.
4. Publish source first; do not distribute an unnotarized binary as a public release.
5. Re-run all 15 tests in an environment that permits loopback binding.
