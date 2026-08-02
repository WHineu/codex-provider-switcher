# Changelog

## Unreleased

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
