# CodexBar

**Use any OpenAI-compatible model in Codex Desktop — from a macOS menu bar app.**

Codex Desktop normally talks only to OpenAI's own models. CodexBar sits quietly in your menu bar and runs a tiny local gateway that lets Codex route to **third-party providers** (xAI, DeepSeek, OpenRouter, Z.ai, Kimi, Qwen, MiniMax, Cline Pass, …) or **local models** (Ollama) — while still passing native GPT/ChatGPT requests straight through to OpenAI. You manage everything from a native **Settings** window; no terminal or browser required.

> Providers must expose an OpenAI-compatible `/chat/completions` endpoint. (Cursor's API, for example, only lists models and has no public chat-completions endpoint, so it can't be used here.)

---

## How it works

```text
Codex Desktop
     │  HTTP (loopback)
     ▼
CodexBar gateway — 127.0.0.1:8765
     │
     ├─ custom model → third-party provider API   (Responses ⇄ Chat Completions)
     └─ native GPT   → OpenAI / ChatGPT backend    (passed through unchanged)
```

- **Gateway** — a small embedded Swift HTTP server on `127.0.0.1:8765` (loopback only). Codex is pointed at it via a managed block in `~/.codex/config.toml`.
- **Routing** — requests for your custom models are translated (OpenAI *Responses* ⇄ *Chat Completions*) and forwarded to the provider's API with your key; native models are passed through to OpenAI/ChatGPT unchanged.
- **Menu bar + Settings** — a status icon shows gateway health and port; the Settings window is where you add providers, pick models, and sync Codex's model picker.

## Features

- **Third-party & local models in Codex** via Responses ⇄ Chat Completions translation
- **Native GPT pass-through** — official OpenAI / ChatGPT requests are untouched
- **No Codex sign-in needed for local-only use** (e.g. Ollama); sign-in is only required for native GPT/ChatGPT
- **Menu bar status** with live gateway state + port, and a native Settings window
- **Friendly model names** auto-generated from provider model IDs (editable)
- **Loopback-only gateway** — no management endpoints over HTTP, nothing reachable from the LAN
- **In-app updates** from GitHub Releases (one-click install for notarized builds)

## Requirements

- macOS 26 or later
- [Codex Desktop](https://openai.com/codex) installed
- Xcode Command Line Tools (only if building from source)

## Install

Download the latest `.dmg` from [Releases](https://github.com/rimusz/codex-bar/releases), or build from source:

```bash
make run            # build + launch the menu bar app
make app            # build dist/CodexBar.app + DMG
make install        # copy the app to /Applications/
```

See [BUILDING.md](BUILDING.md) for packaging, code signing, notarization, and publishing releases.

## Quick start

1. Launch CodexBar — a status icon appears in the menu bar.
2. Open **Settings** (menu bar → Settings, or ⌘,).
3. **Install a provider preset** and enter its API key (skipped for keyless providers like Ollama).
4. Click **Add model** on the provider row and pick the models you want.
5. Restart Codex when prompted (**Restart Codex**, ⌘R) so its picker refreshes.
6. In Codex Desktop, open the model picker — your models are now listed.

> **Custom models require you to be signed in to Codex** — a **free account is enough**. Signed out, Codex only shows its built-in fallback models and labels any active custom model as "Custom". (Native GPT/ChatGPT models still need an OpenAI/ChatGPT account.) When you have custom models but Codex is signed out, Settings shows a reminder.

## Managing providers & models

Everything lives in the **Settings** window — no browser needed.

### Providers

Install a built-in preset (**Z.ai, Kimi, Qwen, Xiaomi MiMo, Cline Pass, MiniMax, DeepSeek, xAI, OpenRouter, Ollama**) or add a custom OpenAI-compatible endpoint. You're prompted for an API key when the provider needs one. Provider rows show a compact model count and status.

You can add, edit, and delete providers. A provider can't be removed while it still has installed models — delete its models first.

### Models

Click **Add model** to fetch the provider's model list and choose which to install. (Cline Pass uses a fixed catalog instead of a live fetch.)

Display names are auto-formatted into friendly, provider-prefixed names — Cline style:

| Provider model ID | Shown in Codex as |
|---|---|
| `grok-4.3` (xAI) | **xAI Grok 4.3** |
| `deepseek/deepseek-chat-v3-0324` (OpenRouter) | **OpenRouter DeepSeek Chat V3 0324** |

Doubled vendor prefixes are collapsed, and any name you edit yourself is preserved.

### When does Codex need a restart?

Only when you **add, edit, or delete a model** — those change Codex's exported picker catalog, and Settings will surface a **Restart Codex** button. **Provider** changes (including installing a preset) take effect **immediately** — the gateway reads endpoints and keys live from `~/.codexbar/providers.json`, so no restart is required.

The menu-bar **Restart Codex** action (⌘R) always asks for confirmation first.

### Reset / Update Gateway Config

This button toggles based on whether Codex's config already matches your CodexBar models:

- **Reset Gateway Config** (in sync) — removes *only Codex's* managed block + exported catalog so Codex stops routing through CodexBar. **Your CodexBar providers and models are kept.**
- **Update Gateway Config** (out of date, e.g. after a reset or newly added models) — re-applies your providers/models to Codex.

Either action restarts Codex.

## Security & networking

The gateway binds to `127.0.0.1` only, so it is **never reachable from the local network**. It exposes just the routes Codex and the app use (`/health`, `/v1/responses`, `/v1/chat/completions`, `/v1/models`, `/api/restart-codex`) — there are **no HTTP endpoints for changing providers or models**. All management happens in-process through the native Settings UI.

## Configuration files

CodexBar keeps its own data under `~/.codexbar/` and writes only a clearly-marked managed block into Codex's config.

| Path | Purpose |
|---|---|
| `~/.codexbar/providers.json` | Provider endpoints + API keys (read live by the gateway) |
| `~/.codexbar/custom_model_catalog.json` | Your installed models + routing metadata |
| `~/.codexbar/fetched_models.json` | Cache of provider model lists |
| `~/.codex/config.toml` | Codex config — CodexBar patches a managed block only |
| `~/.codex/model-catalogs/custom-providers.json` | Codex picker export (native models **plus** your custom ones) |

The exported picker catalog always includes the native ChatGPT/Codex models, so installing CodexBar never hides the built-in choices.

## Updates

Menu bar → **Check for Updates…** (⌘U) checks GitHub for a newer **notarized** release and can download and install it in one step. Unsigned CI releases are published for manual install only.

## Contributing

CodexBar is a pure-Swift SwiftPM app (no Xcode project). See [ARCHITECTURE.md](ARCHITECTURE.md) for the app map, gateway routes, config paths, and a "common tasks → files" lookup, and [AGENTS.md](AGENTS.md) for repo conventions.
