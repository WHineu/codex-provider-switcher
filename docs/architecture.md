# Architecture

## Components

```text
Codex config
  -> provider-neutral switching core
     -> direct provider, or
     -> typed local adapter -> HTTPS upstream

macOS app -> bundled launcher -> switching core
```

## Core boundary

The core owns discovery, status, confirmation, locking, TOML validation,
atomic replacement, rollback, and adapter lifecycle. It does not own provider
credentials, models, pricing, account state, or service-specific claims.

Provider IDs and display names come from `[model_providers.*]`. The root
`model_provider` assignment is the only Codex setting the core modifies.

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
