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
ModelCatalog.shared            // ~/.codexbar/
CodexConfig.patchCodexConfig()            // explicit apply → ~/.codex/config.toml managed blocks
CodexConfig.refreshManagedConfigIfApplied() // automatic callers; only if block already present
CodexAppServer.shared          // restart Codex Desktop
```

## Gateway routes

See `ARCHITECTURE.md` → Gateway routes. The gateway is **minimal and loopback-only** (`LoopbackHTTPServer.start` pins `requiredLocalEndpoint` to `127.0.0.1`): only `/health`, `/api/restart-codex`, `/v1/models`, `/v1/responses`, `/v1/chat/completions`. There are **no HTTP provider/model mutation endpoints and no browser dashboard** — all management is done in-process by the native Settings UI (`ModelCatalog` / `CodexConfig`).

Provider/model add flow (native, not HTTP): installing a preset writes only the provider endpoint/key; Settings then fetches OpenAI-compatible provider models via `ProviderModelFetcher` (`GET {base_url}/models`) before adding selected models. Fetched lists persist in `~/.codexbar/fetched_models.json` and are replaced on the next fetch. Cline Pass uses its fixed catalog list. `ProviderModelFetcher.parse` accepts OpenAI (`data[]`), bare arrays, and an `items[]` shape (flattening to top-level `id`s and ignoring per-model variants). Note: providers must expose an OpenAI-compatible `/chat/completions` endpoint to actually serve models — a `/models`-only API (e.g. Cursor's) can list models but can't complete, so such providers aren't shipped as presets.

## Config files

| File | Managed by |
|------|-----------|
| `~/.codexbar/custom_model_catalog.json` | `ModelCatalog` internal routing catalog |
| `~/.codex/model-catalogs/custom-providers.json` | `ModelCatalog` Codex-compatible picker catalog export; includes native ChatGPT/Codex models plus custom models. **Custom entries only appear in Codex's picker when signed in** (free account suffices); signed out Codex shows a built-in fallback and labels active custom models as "Custom". `SettingsStore.customModelsNeedSignIn` drives a Settings hint. |
| `~/.codexbar/providers.json` | `ModelCatalog` |
| `~/.codex/config.toml` | `CodexConfig` (managed blocks). `requires_openai_auth` follows `CodexConfig.isSignedIn()`: `false` when signed out (no Codex login needed for local-only Ollama/custom), `true` when signed in (native GPT/ChatGPT pass-through). |
| `~/.codex/auth.json` | read-only for pass-through token + `isSignedIn()` detection |

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
