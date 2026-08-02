# Architecture

## Components

```text
Codex config
  -> built-in registry + custom provider discovery
     -> provider-neutral switching transaction
     -> direct provider, or
     -> typed local adapter -> HTTPS upstream

macOS app -> bundled launcher -> switching core
```

## Core boundary

The core owns discovery, status, confirmation, locking, TOML validation,
atomic replacement, rollback, and adapter lifecycle. It does not own provider
credentials, models, pricing, subscription limits, account state, or
service-specific claims.

Provider metadata comes from two sources:

- a registry entry for the built-in `openai` provider, verified against
  published Codex documentation;
- custom provider IDs, names, and base URLs from `[model_providers.*]`.

The 0.2 built-in registry intentionally contains only `openai` and stores no
endpoints, credentials, or routing rules. Custom tables cannot override a
registered built-in ID, and adapters cannot be assigned to registered built-in
providers. The root `model_provider` assignment is the only Codex setting the
core modifies.

## Adapter boundary

Adapters are optional and typed. The alpha contains one `http11_gateway` type:

- binds to `127.0.0.1` only;
- forwards only configured paths over HTTPS;
- removes hop-by-hop headers;
- never logs headers, credentials, request bodies, or response bodies;
- exposes a metadata-only `/healthz` identity;
- cannot run arbitrary user-supplied commands.

Future adapters should extend a reviewed schema. Treat executable hooks as a
separate threat model rather than adding them to this configuration format.

## Configuration transaction

```text
lock config
-> parse current TOML
-> validate target provider
-> confirm no active tasks
-> start and identify target adapter when required
-> write validated temporary file in the config directory
-> atomic replace
-> parse and verify applied provider
-> restore original bytes on failure
-> stop the previous owned adapter
```

## Public/private boundary

Public artifacts may contain source, fixtures with reserved domains, build
scripts, and redacted documentation. They must not contain private Codex task
metadata, user paths, provider credentials, real account responses, or personal
validation evidence.
