# CodexBar — architecture reference

**Read this first in every new chat.** Canonical map of how CodexBar works. `AGENTS.md` points here; `.cursor/rules/` add file-specific conventions.

---

## What CodexBar is

CodexBar is a **menu-bar macOS app** (AppKit) that runs an embedded **OpenCodex gateway** on `http://127.0.0.1:8765`. Codex Desktop routes model requests through it for third-party model translation and config management.

| CodexBar owns | Codex Desktop owns |
|---------------|-------------------|
| Loopback HTTP gateway (`/v1/responses`, `/health`, `/api/*`) | Chat UI, sessions, tool execution |
| Responses ↔ Chat Completions translation | Official OpenAI / ChatGPT pass-through usage |
| `~/.codexbar/` catalog + providers | User auth (`~/.codex/auth.json`) |
| `~/.codex/config.toml` managed block | Agent runtime |
| Menu bar status + native dashboard window | |
| In-app updates (notarized GitHub releases) | |

**Platform:** macOS 14+. **Version:** `VERSION` → `AppVersion.display`. **Build:** SwiftPM only — no Xcode project; use `make` / `swift build`.

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
│   │   ├── CodexConfig.swift     # config.toml managed blocks
│   │   ├── CodexAppServer.swift  # Codex Desktop restart
│   │   ├── APIClient.swift       # Health polling
│   │   ├── GatewayDashboard.swift # HTML dashboard (debug)
│   │   ├── Paths.swift
│   │   └── SSELog.swift
│   ├── UI/
│   │   ├── DashboardWindowController.swift
│   │   ├── DashboardView.swift
│   │   ├── DashboardStore.swift
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
| GET | `/dashboard` | HTML dashboard (debug fallback) |
| GET | `/api/logs/stream` | SSE logs |
| GET | `/api/dashboard` | Providers + catalog JSON for dashboard |
| GET | `/api/models` | Catalog + active models |
| POST | `/api/providers` | Upsert one provider |
| DELETE | `/api/providers?name=…` | Delete provider (400 if catalog models still reference it) |
| POST | `/api/catalog` | Upsert one catalog model |
| DELETE | `/api/catalog?slug=…` | Delete catalog model |
| GET | `/api/presets` | List available presets |
| POST | `/api/presets/install` | Install built-in provider preset (provider only) |
| POST | `/api/restart-codex` | Restart Codex Desktop |
| POST | `/api/reset` | Reset gateway config |
| GET | `/v1/models` | OpenAI-compatible model list |
| GET | `/v1/config` | Provider summary |
| POST | `/v1/responses` | Responses API (translate or pass-through) |
| POST | `/v1/chat/completions` | Chat completions proxy |

WebSocket upgrades return 404 (voice removed).

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
| `~/.codexbar/custom_model_catalog.json` | CodexBar internal model catalog (routing metadata) |
| `~/.codex/model-catalogs/custom-providers.json` | Codex-compatible picker export (`model_catalog_json`): native ChatGPT/Codex models plus custom entries |
| `~/.codexbar/providers.json` | Provider credentials |
| `~/.codexbar/fetched_models.json` | Cached `/models` lists per provider (updated on each fetch) |
| `~/.opencodex/` | Legacy config dir; migrated once into `~/.codexbar/` on startup |
| `~/.codex/config.toml` | Codex config (managed blocks patched) |
| `~/.codex/auth.json` | Auth token for pass-through |

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
| Migrate legacy `~/.opencodex` config | `Paths.migrateLegacyConfigIfNeeded`, `Paths.prepare` |
| Install provider preset | `PresetInstaller`, dashboard window (provider only; models fetched/added separately) |
| Open dashboard | `DashboardWindowController`, menu **Dashboard** (⌘D) |
| Patch Codex config | `CodexConfig.swift` |
| Reset gateway config | `DashboardView`, `DashboardStore.resetGatewayConfig`, `CodexConfig.resetToNative` |
| Restart Codex Desktop | `CodexAppServer.swift` |
| Menu bar UI | `StatusBarController.swift` |
| In-app updates | `UpdateChecker.swift`, `AppUpdater.swift`, `UpdateScheduler.swift`, `UpdatePanel.swift` |
| Dashboard HTML | `GatewayDashboard.swift` |
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
