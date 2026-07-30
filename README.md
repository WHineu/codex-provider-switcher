# Codex Provider Switcher

An unofficial, local-first switcher for providers already configured in Codex.
It discovers `[model_providers.*]` dynamically, changes only the top-level
`model_provider`, validates the result, and restores the original file if
post-write validation fails.

This repository is an unpublished `0.1.0-alpha` candidate. It is not affiliated
with or endorsed by OpenAI or any API provider.

Current verification and release readiness are tracked in `PROJECT_STATE.md`.

## Why it exists

Codex supports multiple provider definitions, but changing the active provider
still requires careful configuration editing and a full Codex restart. This
project makes that operation deterministic and gives providers with HTTP/1.1
compatibility requirements an optional loopback-only adapter.

The core contains no provider names, service URLs, API keys, or arbitrary
command hooks. Providers remain user-owned Codex configuration.

## Features

- discovers any provider under `[model_providers.*]`;
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
- Codex providers already configured in `~/.codex/config.toml`.

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

## Security

Read `SECURITY.md` before reporting a vulnerability. Do not include API keys,
Codex auth files, complete private configuration, or provider response bodies
in an issue.

## Contributing

Contributions for additional platforms, safer lifecycle handling, provider
compatibility adapters, tests, and documentation are welcome. See
`CONTRIBUTING.md` and `docs/architecture.md`.

## License

MIT. See `LICENSE`.

## 中文说明

这是一个非官方、仅在本机工作的 Codex Provider 切换器。它会动态读取
`~/.codex/config.toml` 中已配置的 Provider，不绑定任何中转服务，也不读取
或保存 API Key。切换前必须停止活动任务，切换后应完全退出并重新打开 Codex。
