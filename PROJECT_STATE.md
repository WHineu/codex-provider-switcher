# PROJECT_STATE

- **Project:** codex-provider-switcher
- **Version:** 0.2.0-alpha
- **Status:** Source-only release candidate
- **Last verified:** 2026-08-02

## Verified

- The documentation-backed built-in registry exposes `openai` without creating
  a reserved `[model_providers.openai]` table.
- Custom provider discovery remains dynamic and contains no third-party routing rules.
- The registered built-in `openai` ID rejects custom provider tables and local adapters.
- Configuration replacement is locked, atomic, validated, and reversible.
- Symbolic-link configuration targets are rejected before path resolution.
- Active-task confirmation runs before a target adapter is started.
- Loopback adapter ownership checks use provider, upstream, instance ID, and PID.
- All 20 offline and lifecycle tests pass, including loopback binding,
  built-in/custom switching, adapter lifecycle, and failed-switch rollback.
- The native macOS candidate builds for arm64 and macOS 13+, its plist is valid,
  packaged resources match source, and strict ad-hoc signature verification passes.
- Manual validation covers provider discovery and a complete built-in OpenAI/adapter-backed
  route cycle, including owned-adapter shutdown after returning to the built-in route.
- GitHub Private Vulnerability Reporting is enabled.
- Scans found no personal paths, credentials, task IDs, private routes, real
  provider configuration, or third-party provider hard-coding in candidate files.

## Release Scope

- The 0.2 line is a provider-neutral, local-first, source-only alpha candidate.
- Public artifacts contain source, tests, build scripts, reserved-domain fixtures,
  and redacted documentation only.
- No unnotarized binary is distributed as a public release asset.
- Manual route claims are limited to the verified built-in OpenAI/adapter-backed cycle.
- Direct custom-provider support is covered by isolated tests; additional real-service
  validation is optional and does not block the current alpha scope.
- Provider availability, pricing, model equivalence, credentials, and account state
  remain outside the project's claims and responsibilities.

## Remaining Gates

1. Review the final 0.2 source changes and public wording.
2. Decide whether to create a versioned source release and define its maintenance policy.
3. Define signing and notarization requirements before any future public binary distribution.
