# PROJECT_STATE

- **Project:** codex-provider-switcher
- **Version:** 0.2.1-alpha
- **Status:** Published source-only prerelease
- **Last verified:** 2026-08-07

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
- The refined native app completed bidirectional switching between configured custom
  providers, and Codex remained usable after each switch.
- The native interface presents current provider and adapter health in a compact status
  surface with explicit loading, empty, error, confirmation, and result states.
- GitHub Private Vulnerability Reporting is enabled.
- The `v0.2.1-alpha` annotated tag and source-only GitHub prerelease are published
  from the verified commit, with no attached binary assets.
- Scans found no personal paths, credentials, task IDs, private routes, real
  provider configuration, or third-party provider hard-coding in candidate files.

## Release Scope

- The 0.2 line is a provider-neutral, local-first, source-only alpha prerelease.
- Public artifacts contain source, tests, build scripts, reserved-domain fixtures,
  and redacted documentation only.
- No unnotarized binary is distributed as a public release asset.
- Manual route claims are limited to the verified built-in OpenAI/adapter-backed cycle.
- Direct custom-provider support is covered by isolated tests; additional real-service
  validation is optional and does not block the current alpha scope.
- Provider availability, pricing, model equivalence, credentials, and account state
  remain outside the project's claims and responsibilities.

## Maintenance Position

1. Maintain the alpha line on a best-effort basis through public Issues and GitHub Private Vulnerability Reporting.
2. Treat additional direct custom-provider real-service validation as optional, non-blocking coverage.
3. Define signing and notarization requirements before any future public binary distribution.
