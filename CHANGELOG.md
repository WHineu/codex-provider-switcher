# Changelog

## Unreleased

## 0.2.1 - 2026-08-08

- Promote the validated release candidate to the stable 0.2.1 release without changing provider switching behavior.
- Record successful manual validation of the installed release candidate.

## 0.2.1-rc.1 - 2026-08-07

- Freeze the validated provider switcher feature set for release-candidate testing.
- Record repeated successful manual validation of the installed beta app without changing switching behavior.

## 0.2.1-beta.1 - 2026-08-07

- Add macOS GitHub Actions CI for tests, native app builds, signing checks, and bundled resource verification.
- Promote the repeatedly validated native app line from alpha to beta without changing provider switching behavior.

## 0.2.1-alpha - 2026-08-07

- Refine the native macOS app into a compact, status-first provider switcher.
- Add explicit loading, empty, error, adapter, confirmation, and result states.
- Improve keyboard defaults and accessibility labels without changing the CLI or configuration transaction.
- Validate bidirectional switching with configured providers in a real Codex environment.

## 0.2.0-alpha - 2026-08-02

- Add documentation-backed discovery for the Codex built-in `openai` provider.
- Keep custom provider discovery dynamic under `[model_providers.*]`.
- Reject custom tables and local adapters for the registered built-in `openai` ID.
- Cover built-in/custom switching and adapter shutdown with offline tests.
- Update the native app copy and version for the `0.2.0-alpha` candidate.

## 0.1.0-alpha - Public release candidate

- Dynamically discover configured Codex providers.
- Atomically switch the top-level provider with validation and rollback.
- Add a declarative, loopback-only HTTP/1.1 adapter.
- Verify adapter ownership before stopping its process.
- Add a dynamic native macOS interface and repeatable local build.
- Add offline tests, security guidance, and contribution documentation.
