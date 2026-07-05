# CodexBar

Pure-Swift macOS menu bar app combining the OpenCodex gateway and OpenCodexBar companion into one application.

CodexBar runs a local gateway on `http://127.0.0.1:8765` so Codex Desktop can route model requests through it, with a menu bar status indicator and dashboard.

## Features

- Embedded Swift gateway (`/v1/responses`, `/health`, `/api/config`)
- Third-party model routing with Responses ↔ Chat Completions translation
- Native GPT pass-through to official OpenAI / ChatGPT backends
- Menu bar status indicator and **dashboard** for managing providers/models
- Config management for `~/.codex/config.toml` and `~/.codexbar/` (providers, model catalog, fetch cache)
- In-app update check (GitHub Releases) with one-click install for **notarized** builds

## Requirements

- macOS 26+
- Xcode Command Line Tools
- [Codex Desktop](https://openai.com/codex) installed

## Build

```bash
make build          # release binary
make test           # run unit tests
make run            # build + launch menu bar app
make app            # dist/CodexBar.app + DMG
make install        # copy to /Applications/
```

See [BUILDING.md](BUILDING.md) for packaging, signing, notarization, and GitHub releases.

## Providers & models

Menu bar → **Dashboard** (⌘D) opens a native window — no browser required. From there you can:

- **Install a provider preset** from the expandable preset section (Z.ai, Kimi, Qwen, Xiaomi MiMo, Cline Pass, MiniMax, DeepSeek, Ollama). You're prompted for an API key when the provider needs one; provider rows show compact model counts/status, and **Add model** opens the selectable model list. Cline Pass uses its fixed catalog list.
- **Add / edit / delete** custom providers and selected provider models, with delete confirmations. A provider cannot be removed while it still has installed catalog models.
- **Reset Gateway Config** with confirmation. The dialog explains that Codex will be restarted after the reset.

The menu-bar **Restart Codex** action (⌘R) asks for confirmation before restarting Codex Desktop so the model picker picks up changes.

The loopback HTML dashboard at `http://127.0.0.1:8765/dashboard` remains available for debugging.

Presets match [grok-build-desktop](https://github.com/rimusz/grok-build-desktop) provider definitions (base URLs, model-list fetch behavior, full Cline Pass catalog).

CodexBar keeps routing metadata in `~/.codexbar/custom_model_catalog.json` and exports a Codex-readable picker catalog to `~/.codex/model-catalogs/custom-providers.json`. The exported picker catalog includes native ChatGPT/Codex models plus your custom models, so installing CodexBar does not hide the built-in model choices. On first launch after upgrading, existing `~/.opencodex/` files are moved into `~/.codexbar/` automatically.

Menu bar → **Check for Updates…** (⌘U) checks GitHub for a newer **notarized** release and can download and install it in one step. Unsigned CI releases are published for manual install only.

## Architecture

```text
Codex Desktop ──HTTP──► CodexBar Gateway (:8765) ──► third-party providers
                              │
                              ├──► official OpenAI pass-through
                              └──► Menu bar UI + dashboard
```
