---
name: codexbar-gateway
description: Works with CodexBar gateway and Codex Desktop integration — HTTP routes, model translation, config patching, catalog management. Use when changing GatewayServer, Translator, ModelCatalog, CodexConfig, or CodexAppServer.
---

# Gateway & Codex in CodexBar

## Boundaries

CodexBar is a gateway + menu bar companion. Core agent behavior stays in Codex Desktop.

## Key components

```swift
// HTTP gateway
GatewayServer.shared.start()   // 127.0.0.1:8765
LoopbackHTTPServer             // Network.framework HTTP

// Translation
Translator.responsesToChat(...)
Translator.chatCompletionToResponse(...)

// Config
ModelCatalog.shared            // ~/.codexbar/ (migrates from ~/.opencodex/ on startup)
CodexConfig.patchCodexConfig() // ~/.codex/config.toml managed blocks
CodexAppServer.shared          // restart Codex Desktop
```

## Gateway routes

See `ARCHITECTURE.md` → Gateway routes. Dashboard forms use:

- `GET /api/dashboard`
- `POST /api/providers`, `DELETE /api/providers?name=…`
- `POST /api/catalog`, `DELETE /api/catalog?slug=…`
- `POST /api/presets/install` installs only the provider preset; Dashboard fetches OpenAI-compatible provider models via `ProviderModelFetcher` (`GET {base_url}/models`) before adding selected models. Fetched lists persist in `~/.codexbar/fetched_models.json` and are replaced on the next fetch. Cline Pass uses its fixed catalog list.

## Config files

| File | Managed by |
|------|-----------|
| `~/.codexbar/custom_model_catalog.json` | `ModelCatalog` internal routing catalog |
| `~/.codex/model-catalogs/custom-providers.json` | `ModelCatalog` Codex-compatible picker catalog export; includes native ChatGPT/Codex models plus custom models |
| `~/.codexbar/providers.json` | `ModelCatalog` |
| `~/.codex/config.toml` | `CodexConfig` (managed blocks) |
| `~/.codex/auth.json` | read-only for pass-through token |

## Status bar integration

- `APIClient.fetchStatus()` polls `/health`
- Posts `CodexBarStatusChanged` with `AppStatus` on main queue

## After changing gateway integration

Same session, before finishing:

1. **`make test`** — extend `TranslatorTests`, `CodexConfigTests`, or add service tests.
2. **`ARCHITECTURE.md`** — gateway routes, config paths, service map.
3. **`README.md`** — if user-visible gateway/config behavior changed.
4. **This skill** + `codex-gateway-integration.mdc` — if APIs or route contracts changed.

## Smoke test

```bash
make run
curl -s http://127.0.0.1:8765/health
```
