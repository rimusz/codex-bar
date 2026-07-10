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
- **Open at Login** — optional menu-bar toggle so CodexBar starts with macOS
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
2. (Optional) Menu bar → **Open at Login** so the gateway starts automatically after reboot.
3. Open **Settings** (menu bar → Settings, or ⌘,).
4. **Install a provider preset** and enter its API key (skipped for keyless providers like Ollama).
5. Click **Add model** on the provider row and pick the models you want.
6. Restart Codex when prompted (**Restart Codex**, ⌘R) so its picker refreshes.
7. In Codex Desktop, open the model picker — your models are now listed.

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

### Open at Login

Menu bar → **Open at Login** toggles whether CodexBar launches when you sign in to macOS (via `SMAppService`). A checkmark means it is enabled. The first time you turn it on, macOS may ask you to allow CodexBar under **System Settings → General → Login Items & Extensions** — CodexBar offers a shortcut to that pane when approval is required.

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

Menu bar → **Check for Updates…** (⌘U) checks GitHub for a newer **notarized** release and can **download, verify, install, and relaunch** in one flow (same pattern as [GrokBuild Desktop](https://github.com/rimusz/grok-build-desktop)):

1. **Update App** — downloads `CodexBar-{tag}.app.zip` and verifies the signature  
2. **Install and Restart** — replaces the running app via the bundled `codexbar-install-update` helper and relaunches  

Only **notarized** releases with a `.app.zip` asset are installable in-app. Unsigned CI releases are ignored (use the DMG from GitHub manually). If you previously chose **Skip This Version**, **Check for Updates…** still offers **Update App** so you can install later.

Unsigned CI releases are published for manual install only.

## Using CodexBar with [Zero](https://zero.gitlawb.com)

[Zero](https://zero.gitlawb.com) is a terminal coding agent that supports any **OpenAI-compatible** API. You can point it at the CodexBar gateway on the same Mac and use the models you configured in CodexBar Settings — Cline Pass, Ollama, DeepSeek, xAI via your keys, and so on.

CodexBar must be **running** (menu bar icon present). The gateway is local-only:

| Item | Value |
|------|--------|
| Base URL | `http://127.0.0.1:8765/v1` |
| Health | `http://127.0.0.1:8765/health` |
| Model list | `GET http://127.0.0.1:8765/v1/models` |

Provider API keys live in CodexBar (`~/.codexbar/providers.json`); Zero only needs a **dummy** credential so its `custom-openai-compatible` profile passes auth checks.

### Prerequisites

1. CodexBar is running and the gateway is healthy:

   ```bash
   curl -s http://127.0.0.1:8765/health
   ```

2. Models are installed in **CodexBar → Settings** (providers + models, **Update Gateway Config** if needed).

3. [Zero](https://zero.gitlawb.com) is installed (`npm install -g @gitlawb/zero` or see Zero's install docs).

### One-time setup (CLI)

Add CodexBar as a **Custom OpenAI-compatible** provider. Use catalog id `custom-openai-compatible` (not a made-up name like `codexbar`):

```bash
zero providers add custom-openai-compatible \
  --name codexbar \
  --base-url http://127.0.0.1:8765/v1 \
  --model clinepass/cline-pass-glm-5.2 \
  --auth-header-value not-used \
  --set-active
```

- `--name codexbar` — your profile label (any name you like).
- `--model` — default model slug; pick one from `zero providers models codexbar` (see below).
- `--auth-header-value not-used` — stored dummy key (CodexBar ignores it for custom models; Zero requires *something* for this profile type).

**Alternative:** set an env var instead of storing a key:

```bash
export OPENAI_API_KEY=not-used
zero providers add custom-openai-compatible \
  --name codexbar \
  --base-url http://127.0.0.1:8765/v1 \
  --model clinepass/cline-pass-glm-5.2 \
  --api-key-env OPENAI_API_KEY \
  --set-active
```

### Verify setup

```bash
zero providers check codexbar --connectivity
zero providers models codexbar
zero providers current
```

You want `status: ok` and `connectivity: pass`. `zero providers models codexbar` lists every slug the gateway exposes (custom + native GPT slugs).

### CLI — providers & models

| Command | Purpose |
|---------|---------|
| `zero providers list` | All saved provider profiles |
| `zero providers current` | Active provider + model |
| `zero providers use codexbar` | Switch to the CodexBar profile |
| `zero providers models codexbar` | Live list from CodexBar `/v1/models` |
| `zero providers check codexbar --connectivity` | Auth + reachability |
| `zero providers catalog` | Built-in provider types (`custom-openai-compatible`, etc.) |

**Change default model** on the profile (re-run add with a new `--model`):

```bash
zero providers add custom-openai-compatible \
  --name codexbar \
  --base-url http://127.0.0.1:8765/v1 \
  --model clinepass/cline-pass-kimi-k2.7-code \
  --auth-header-value not-used \
  --set-active
```

### CLI — run tasks (headless)

```bash
# One-shot prompt (uses active provider unless --model overrides)
zero exec "explain this repo"

# Explicit model slug from CodexBar
zero exec --model clinepass/cline-pass-glm-5.2 "fix the failing test in ./pkg"

# Scriptable / CI-style I/O
zero exec --output-format stream-json "summarize main.go"
```

Model slugs must match **`zero providers models codexbar`** exactly (e.g. `clinepass/cline-pass-glm-5.2`, not the raw Cline Pass upstream id).

### TUI — interactive terminal

Start Zero with the **codexbar** profile already active (do this in a normal terminal, not inside the TUI):

```bash
zero providers use codexbar
zero
```

If you used `--set-active` when you ran `zero providers add`, **codexbar** is already the active profile — you can run `zero` directly. Check anytime:

```bash
zero providers current
```

Inside the TUI, `/config` or the bottom status line shows the active provider and model (you want **codexbar** · your model slug).

> **`/provider` is for managing providers** (add / edit / delete), not for switching. Use **`zero providers use codexbar`** in a shell before launching `zero`, or rely on `--set-active` from setup.

#### Changing the model in TUI

CodexBar models are **not** reliably listed in Zero's `/model` search picker. Use one of these methods instead:

**Method 1 — `/model <slug>` (best for switching mid-session)**

1. Confirm **codexbar** is active (status bar or `/config`). If not, exit the TUI and run `zero providers use codexbar`, then `zero` again.

2. In another terminal, list valid slugs:

   ```bash
   zero providers models codexbar
   ```

3. In the Zero TUI, switch model by typing the **full slug** (no picker needed):

   ```text
   /model clinepass/cline-pass-glm-5.2
   ```

   Other examples:

   ```text
   /model clinepass/cline-pass-kimi-k2.7-code
   /model clinepass/cline-pass-deepseek-v4-pro
   /model gpt-5.4
   ```

4. Confirm the switch — Zero prints a status line showing the new model. The status bar at the bottom of the TUI also updates (provider · model).

**Method 2 — Set default before starting Zero (CLI)**

Change the profile's default model, then launch `zero`:

```bash
zero providers add custom-openai-compatible \
  --name codexbar \
  --base-url http://127.0.0.1:8765/v1 \
  --model clinepass/cline-pass-kimi-k2.7-code \
  --auth-header-value not-used \
  --set-active

zero
```

New sessions start on that model. Use **Method 1** to switch again without restarting.

**Method 3 — `/model` picker + Recent**

After you switch with `/model <slug>` once, that model appears under **Recent** in `/model` for quicker re-selection. The graphical picker may still not show Cline Pass models when you search — use Recent or type the slug directly.

#### Other TUI / CLI commands

| Action | How |
|--------|-----|
| Switch to CodexBar provider | **`zero providers use codexbar`** (in shell, before or after exiting TUI) |
| Add/edit providers in TUI | `/provider add` or `/provider` (manager — not for picking active provider) |
| Show active provider + model | `/config` or bottom status line; CLI: `zero providers current` |
| List models | `zero providers models codexbar` |
| Check setup | `/doctor` or `zero doctor` |

**`/model` picker limitation:** Zero's graphical model picker uses a static placeholder catalog for `custom-openai-compatible` and often **does not list** CodexBar's live models (searching `cline` may show "no matching models"). This is a Zero behavior, not a CodexBar bug.

CodexBar models appear under provider group **"Custom OpenAI-compatible"** in `/model`, not "CodexBar". Sections like **xAI** or **MiniMax** in the picker are **other** Zero profiles talking directly to those APIs, not through CodexBar.

### Troubleshooting

| Symptom | Fix |
|---------|-----|
| `unknown provider "codexbar"` on `providers add` | Use catalog id **`custom-openai-compatible`**, not `codexbar`. |
| `unknown flag "--api-key"` | Use **`--auth-header-value`** or **`--api-key-env`**, not `--api-key`. |
| `requires API credentials` / connectivity fail | Set **`--auth-header-value not-used`** or `export OPENAI_API_KEY=not-used`. |
| `zero providers models` works but TUI picker is empty | Use **`/model <full-slug>`** inside TUI (see **Changing the model in TUI** above). |
| Wrong provider active (xAI, MiniMax, etc.) | Exit TUI; run **`zero providers use codexbar`**, then **`zero`** again. |
| Connection refused | Start CodexBar; confirm `curl http://127.0.0.1:8765/health`. |
| Model not found at runtime | Slug must match `zero providers models codexbar`; re-export from CodexBar Settings if you added models recently. |

## Contributing

CodexBar is a pure-Swift SwiftPM app (no Xcode project). See [ARCHITECTURE.md](ARCHITECTURE.md) for the app map, gateway routes, config paths, and a "common tasks → files" lookup, and [AGENTS.md](AGENTS.md) for repo conventions.
