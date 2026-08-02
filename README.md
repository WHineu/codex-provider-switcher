# Codex Provider Switcher

An unofficial, local-first switcher for the Codex built-in OpenAI provider and
user-configured custom providers. It includes a documentation-backed registry
entry for built-in `openai`, discovers `[model_providers.*]` dynamically,
changes only the top-level `model_provider`, validates the result, and restores
the original file if post-write validation fails.

The latest published version is the source-only
[`v0.2.0-alpha`](https://github.com/WHineu/codex-provider-switcher/releases/tag/v0.2.0-alpha)
prerelease. Release scope, verification, and maintenance status are tracked in
`PROJECT_STATE.md`. This project is not affiliated with or endorsed by OpenAI
or any API provider.

Current verification and release readiness are tracked in `PROJECT_STATE.md`.

## Why it exists

Codex supports a built-in OpenAI provider and multiple custom provider
definitions, but changing the active provider still requires careful
configuration editing and a full Codex restart. This project makes that
operation deterministic and gives custom providers with HTTP/1.1 compatibility
requirements an optional loopback-only adapter.

The core contains no third-party provider names, service URLs, API keys, or
arbitrary command hooks. Custom providers remain user-owned Codex
configuration. The 0.2 registry intentionally includes only built-in `openai`,
verified against published Codex documentation.

## Features

- includes the Codex built-in `openai` provider without creating a reserved
  `[model_providers.openai]` table;
- discovers any custom provider under `[model_providers.*]`;
- rejects custom tables and adapters that try to override a registered built-in provider;
- preserves nested profile settings and unrelated TOML content;
- requires confirmation that active Codex tasks are stopped;
- serializes concurrent writes with a file lock;
- validates TOML before and after an atomic replacement;
- restores the original configuration after a failed write verification;
- optionally manages a declarative HTTP/1.1 loopback adapter;
- verifies adapter ownership with provider, upstream, instance ID, and PID;
- provides a CLI and a dynamically populated native macOS app;
- never reads or stores provider API keys.

## Requirements

- macOS 13 or newer for the native app;
- Python 3.11 or newer with the standard-library `tomllib` module;
- custom Codex providers already configured in `~/.codex/config.toml`, when
  custom routes are needed.

## CLI

```bash
python3 src/provider_switcher.py list
python3 src/provider_switcher.py status
python3 src/provider_switcher.py switch provider_id --confirm-no-active-tasks
```

Stop active Codex tasks before switching. Completely quit and reopen Codex
after the command succeeds.

## Optional adapters

Directly compatible providers need no switcher-specific configuration. For a
provider that requires the bundled HTTP/1.1 adapter, create:

```text
~/.config/codex-provider-switcher/adapters.toml
```

Use `examples/adapters.example.toml` as a starting point. Adapter definitions
contain routing metadata only. Credentials remain in the environment variable
already referenced by Codex.

The matching provider `base_url` in Codex must point to the configured local
port, for example `http://127.0.0.1:18080/v1`.

## Build the macOS app

```bash
zsh scripts/build-macos-app.zsh
```

The candidate build is ad-hoc signed and intended for local testing. Public
binary distribution would require a separate signing and notarization policy.

## Test

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Tests use temporary configurations, random loopback ports, and reserved
`.invalid` hostnames. They do not access provider services or credentials.

## Maturity direction

This project matures as a deterministic, safety-focused software product through
verified source releases, compatibility fixes, lifecycle hardening, and explicit
signing and notarization policy before any public binary distribution. Its core
switching, validation, adapter ownership, and rollback behavior remains in code,
tests, the CLI, and the native app rather than moving into a model-driven Skill.

A future Skill may assist with diagnostics or runbook selection after those
support workflows become repetitive and stable. It must not replace the tested
switching implementation, inspect credentials, or broaden configuration authority.

## Security

Read `SECURITY.md` before reporting a vulnerability. Use GitHub Issues for
ordinary bugs and GitHub Private Vulnerability Reporting for security issues.
Do not include API keys, Codex auth files, complete private configuration, or
provider response bodies in an issue.

## Contributing

Contributions for additional platforms, safer lifecycle handling, provider
compatibility adapters, tests, and documentation are welcome. See
`CONTRIBUTING.md` and `docs/architecture.md`.

## License

MIT. See `LICENSE`.

## 中文说明

这是一个非官方、仅在本机工作的 Codex Provider 切换器。它支持 Codex 内置的
`openai` Provider，并动态读取 `~/.codex/config.toml` 中配置的自定义 Provider；
它不绑定任何中转服务，也不读取或保存 API Key。切换前必须停止活动任务，切换后
应完全退出并重新打开 Codex。
