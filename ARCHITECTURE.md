# CodexBar — architecture reference

**Read this first in every new chat.** Canonical map of how CodexBar works. `AGENTS.md` points here; `.cursor/rules/` add file-specific conventions.

---

## What CodexBar is

CodexBar is a **menu-bar macOS app** (AppKit) that runs an embedded **gateway** on `http://127.0.0.1:8765`. Codex Desktop routes model requests through it for third-party model translation and config management.

| CodexBar owns | Codex Desktop owns |
|---------------|-------------------|
| Loopback HTTP gateway (`/v1/*`, `/health`, `/api/restart-codex`) | Chat UI, sessions, tool execution |
| Responses ↔ Chat Completions translation | Official OpenAI / ChatGPT pass-through usage |
| `~/.codexbar/` catalog + providers | User auth (`~/.codex/auth.json`) |
| `~/.codex/config.toml` managed block | Agent runtime |
| Menu bar status + native settings window | |
| In-app updates (notarized GitHub releases) | |

**Platform:** macOS 26+. **Version:** `VERSION` → `AppVersion.display`. **Build:** SwiftPM only — no Xcode project; use `make` / `swift build`.

---

## Design rules for agents

1. **Stay focused** — gateway + menu bar; no chat UI reimplementation.
2. **Reuse services** — extend `GatewayServer`, `Translator`, `ModelCatalog`, `CodexConfig`, `CodexAppServer`.
3. **Match conventions** — read surrounding code; minimize diff scope.
4. **Docs + tests with every code change** — run `make test`, update this file and other docs in the same session.
5. **Commit only when asked.**

---

## Repository layout

```
codex-bar/
├── CodexBar/                     # Main app target (AppKit)
│   ├── main.swift                # NSApplication entry (.accessory)
│   ├── AppDelegate.swift         # Gateway start/stop, status bar
│   ├── StatusBarController.swift # Menu bar icon + menu
│   ├── AppVersion.swift
│   ├── AppIconProvider.swift
│   ├── CodexBrandIcon.swift
│   ├── Services/
│   │   ├── GatewayServer.swift   # HTTP routing
│   │   ├── LoopbackHTTPServer.swift
│   │   ├── Translator.swift      # Responses ↔ Chat translation
│   │   ├── ModelCatalog.swift    # custom_model_catalog.json + providers
│   │   ├── ProviderModelFetcher.swift # OpenAI-compatible /models discovery
│   │   ├── FetchedModelsStore.swift   # ~/.codexbar/fetched_models.json cache
│   │   ├── ZstdBridge.swift         # zstd decompress for Codex request bodies
│   │   ├── UpdateChecker.swift    # GitHub release version check
│   │   ├── UpdateScheduler.swift  # Background update polling
│   │   ├── AppUpdater.swift       # Download, verify, install update
│   │   ├── CodexConfig.swift     # config.toml managed blocks (requires_openai_auth from sign-in)
│   │   ├── CodexAuthWatcher.swift # watches ~/.codex for sign-in changes, re-patches config
│   │   ├── CodexAppServer.swift  # Codex Desktop restart (re-patches config first)
│   │   ├── APIClient.swift       # Health polling
│   │   ├── Paths.swift
│   │   └── GatewayLog.swift
│   ├── UI/
│   │   ├── SettingsWindowController.swift
│   │   ├── SettingsView.swift
│   │   ├── SettingsStore.swift
│   │   └── UpdatePanel.swift
│   └── Resources/Assets.xcassets/
├── Tests/CodexBarTests/
├── scripts/                      # build-macos-app.sh, release.sh, notarize.sh
├── Makefile
├── Package.swift
├── VERSION
├── BUILDING.md
└── README.md
```

---

## App lifecycle

1. `main.swift` — `NSApplication` with `.accessory` (menu bar only, no Dock).
2. `AppDelegate.applicationDidFinishLaunching` — `GatewayServer.shared.start()`, then `StatusBarController` + health timer.
3. `AppDelegate.applicationWillTerminate` — stop gateway.

---

## Gateway routes

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Status + version |
| POST | `/api/restart-codex` | Restart Codex Desktop (used by the menu) |
| GET | `/v1/models` | OpenAI-compatible model list |
| POST | `/v1/responses` | Responses API (translate or pass-through) |
| POST | `/v1/chat/completions` | Chat completions proxy |

The gateway is intentionally minimal: only the routes Codex Desktop and the app itself call. Provider/model **management is done in-process** by the native Settings UI (`ModelCatalog` / `CodexConfig` directly) — there are **no HTTP mutation endpoints** and no browser dashboard, to avoid an unauthenticated local attack surface. The listener is **bound to loopback** (`NWParameters.requiredLocalEndpoint = 127.0.0.1:8765` in `LoopbackHTTPServer.start`), so it is never reachable from the LAN. WebSocket upgrades return 404 (voice removed).

`LoopbackHTTPServer` waits for complete `Content-Length` and chunked bodies, decompresses `Content-Encoding: gzip` and `zstd` request bodies, and defers POST parsing when the body has not arrived yet. Codex Desktop sends large zstd-compressed JSON to `/v1/responses`. `HTTPRequest.forwardHeaders` strips `Content-Encoding` / `Content-Length` before upstream pass-through so decoded bodies are not double-decoded.

---

## In-app updates

CodexBar checks `https://api.github.com/repos/rimusz/codex-bar/releases` for the newest **notarized** release (title/body marker). Unsigned releases are ignored for one-click install.

| Component | Role |
|-----------|------|
| `UpdateScheduler` | Launch + daily background check (30s delay, 24h interval) |
| `UpdateChecker` | GitHub API, semver compare, asset `CodexBar-{tag}.app.zip` |
| `AppUpdater` | Download, codesign/spctl verify, install via `codexbar-install-update` helper |
| `UpdatePanel` | Menu **Check for Updates…** / **Upgrade Available…** (⌘U) |
| `UpdateSettingsStore` | UserDefaults: auto-check, skip version, last check |

Install helper: `scripts/codexbar-install-update.sh` → bundled as `Contents/Resources/codexbar-install-update`.

---

## Config paths

| Path | Purpose |
|------|---------|
| `~/.codexbar/custom_model_catalog.json` | CodexBar internal model catalog (routing metadata). Raw model ids get friendly display names via `ModelCatalog.prettyDisplayName` / `normalizeDisplayNames` (run on Settings reload + gateway startup; drops `vendor/model` prefixes, collapses doubled vendors, title-cases, and prefixes the provider brand Cline-style via `providerBrand`, e.g. "xAI Grok 4.3"); user-edited names are preserved. |
| `~/.codex/model-catalogs/custom-providers.json` | Codex-compatible picker export (`model_catalog_json`): native ChatGPT/Codex models plus custom entries. **Codex only renders custom entries in its picker when signed in** (free account is enough); signed out it shows a built-in fallback list and labels any active custom model as "Custom". Settings surfaces a sign-in hint (`SettingsStore.customModelsNeedSignIn`) when custom models exist but `auth.json` is absent. |
| `~/.codexbar/providers.json` | Provider endpoints + credentials. Read **live** by the gateway per request (`ModelCatalog.resolveUpstream`), so provider/preset changes take effect immediately — **no Codex restart** (only model changes require one; see `SettingsStore.requiresCodexRestart`). |
| `~/.codexbar/fetched_models.json` | Cached `/models` lists per provider (updated on each fetch) |
| `~/.codex/config.toml` | Codex config (managed blocks patched). `[model_providers.codexbar].requires_openai_auth` is set from sign-in state: `false` when not signed in (skips Codex login — enables local-only Ollama/custom use), `true` when signed in (native GPT/ChatGPT pass-through). Automatic callers (startup, `CodexAuthWatcher`, restart) only **refresh** the block when it is already present (`refreshManagedConfigIfApplied`) — CodexBar never silently injects into a fresh/native Codex; Settings' **Update Gateway Config** is the explicit opt-in. |
| `~/.codex/auth.json` | Auth token for pass-through; also read by `CodexConfig.isSignedIn()` to decide `requires_openai_auth`; watched by `CodexAuthWatcher` |

---

## Notifications

| Name | Purpose |
|------|---------|
| `CodexBarStatusChanged` | Menu bar status (`AppStatus` object) |

---

## Build, test & release

```bash
make build      # swift build -c release
make test       # swift test
make run        # build + launch .build/CodexBar.app
make app        # dist/CodexBar.app + DMG
make release    # GitHub release via scripts/release.sh
```

CI: `.github/workflows/pr.yml` (PR: `make test` + `make app`), `.github/workflows/release.yml` (manual dispatch, unsigned publish). Notarized: local `make release RELEASE_TYPE=notarized`. See `BUILDING.md` → GitHub Releases.

---

## Common tasks → files

| Task | Files |
|------|-------|
| Add gateway route | `GatewayServer.swift` |
| Change translation logic | `Translator.swift` |
| Model catalog / providers | `ModelCatalog.swift`, `ProviderPresets.swift`, `ProviderModelFetcher.swift`, `Paths.swift` |
| Install provider preset | `PresetInstaller`, Settings window (provider only; models fetched/added separately) |
| Open Settings | `SettingsWindowController`, menu **Settings** (⌘,) |
| Patch Codex config | `CodexConfig.swift` |
| Reset/Update gateway config | `SettingsView` (label toggles on `SettingsStore.gatewayConfigInSync`), `SettingsStore.resetGatewayConfig` / `updateGatewayConfig`, `CodexConfig.resetToNative` (Codex-side only; keeps `~/.codexbar` data) |
| Restart Codex Desktop | `CodexAppServer.swift`; menu **Restart Codex** (⌘R); Settings shows a **Restart Codex** button (`SettingsStore.needsCodexRestart` / `restartCodex`) after provider/model changes |
| Menu bar UI | `StatusBarController.swift` |
| Gateway status/port in menu | `StatusBarController` (disabled item), `StatusBarMenuCopy.gatewayStatusTitle`, address from `Paths.gatewayHost`/`gatewayPort` |
| In-app updates | `UpdateChecker.swift`, `AppUpdater.swift`, `UpdateScheduler.swift`, `UpdatePanel.swift` |
| Version display | `AppVersion.swift`, `VERSION` |
| Packaging / signing | `scripts/build-macos-app.sh`, `BUILDING.md` |

---

## Tests

Unit tests in `Tests/CodexBarTests/`:

- `TranslatorTests` — translation, namespace mapping, think stripping
- `CodexConfigTests` — managed block stripping
- `ModelCatalogTests` — provider/model API parsing
- `StatusBarTests` — accessibility labels
- `UpdateCheckerTests` — version compare, notarized filter, asset selection
- `UpdateSettingsStoreTests` — skip/dismiss behavior
- `PathsTests` — legacy config migration

Run `make test` before finishing any code change.

---

## Related docs

- `AGENTS.md` — agent entry
- `BUILDING.md` — build, sign, release
- `README.md` — user-facing features
- `.cursor/rules/docs-and-tests.mdc` — docs + tests checklist
