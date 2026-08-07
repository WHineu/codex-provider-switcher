# Release Checklist

## Required Alpha Gates

- [x] License and copyright attribution reviewed by the owner.
- [x] Repository name and maintainer contact confirmed.
- [x] All 20 offline and lifecycle tests pass.
- [x] Candidate app launches, lists providers, and completes a built-in OpenAI/adapter-backed route cycle in a fresh manual macOS session.
- [x] The installed `0.2.1-alpha` app completes bidirectional real-provider switching and Codex remains usable after each switch.
- [x] Offline lifecycle tests cover failed-switch rollback without touching real Codex configuration.
- [x] App builds, its plist is valid, packaged resources match source, and strict ad-hoc signature verification passes.
- [x] No real provider configuration, credentials, task IDs, personal paths, compiled caches, or local logs are included.
- [x] Third-party names appear only in compatibility documentation when needed.
- [x] Non-affiliation and third-party terms boundary is clear.
- [x] Public distribution remains source-only; no unnotarized binary release asset is included.
- [x] GitHub Private Vulnerability Reporting is enabled.

## Publication Status

- [x] Review the final 0.2 source changes and public wording.
- [x] Publish `v0.2.0-alpha` as a source-only prerelease with a best-effort maintenance policy.
- [x] Publish `v0.2.1-alpha` as a source-only prerelease without binary assets.
- [ ] Define signing and notarization requirements before any future public binary distribution.

## Deferred Non-Blocking Coverage

- [ ] Manually validate an additional direct custom-provider route before making broader real-service compatibility claims.
