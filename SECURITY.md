# Security Policy

## Scope

Security reports may cover configuration replacement, adapter lifecycle,
loopback exposure, credential handling, request forwarding, or the macOS app.

## Reporting

Until a public repository has a private security-reporting channel, do not
publish an undisclosed vulnerability. Contact the maintainer through the
private channel named in the eventual repository security settings.

Never include API keys, tokens, `auth.json`, complete private Codex
configuration, request bodies, response bodies, or personal filesystem paths.

## Security model

- The switcher reads provider metadata but never reads provider credentials.
- The adapter binds only to `127.0.0.1` and permits configured API paths.
- Adapter configuration cannot execute arbitrary commands.
- State files live in a user-owned directory with mode `0700`.
- Adapter state and logs use mode `0600`.
- A process is stopped only when its health response matches the recorded
  provider, upstream, instance ID, and PID.
- Configuration replacement is serialized, validated, atomic, and reversible.

## Out of scope

- outages, pricing, or behavior of third-party providers;
- a compromised local user account;
- API keys placed directly in config files by the user;
- modified forks that expose the loopback adapter to other interfaces.
