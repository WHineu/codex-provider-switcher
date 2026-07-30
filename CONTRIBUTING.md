# Contributing

## Principles

- Keep the switching core provider-neutral.
- Do not add real API keys, private URLs, personal paths, task IDs, or user data.
- Prefer declarative adapter fields over executable hooks.
- Preserve atomic replacement, rollback, and explicit confirmation behavior.
- Add offline tests for every behavior change.
- Do not claim that a provider is official, equivalent, or stable without
  independently verifiable evidence.

## Development

1. Use Python 3.11 or newer.
2. Run `python3 -m unittest discover -s tests -p 'test_*.py' -v`.
3. Run `zsh scripts/build-macos-app.zsh` for macOS UI changes.
4. Inspect the diff for credentials, personal paths, generated files, and
   provider-specific assumptions.

## Adding compatibility behavior

Start with an issue describing the protocol difference and a redacted example.
Extend a built-in adapter or propose a typed adapter. Do not add arbitrary
shell commands to `adapters.toml`.

## Pull requests

Describe the problem, security impact, tests, compatibility limits, and manual
verification performed. Keep unrelated refactors out of the same change.
