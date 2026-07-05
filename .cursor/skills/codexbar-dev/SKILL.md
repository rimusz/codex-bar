---
name: codexbar-dev
description: Builds, runs, and tests the CodexBar macOS SwiftPM app. Use when developing CodexBar, running make targets, fixing build failures, or working on AppKit/menu bar UI in this repo.
---

# CodexBar development

## Quick start

```bash
make run          # build release + launch via open
make test         # swift test
swift build       # debug build
xed .             # open Package.swift in Xcode (optional)
```

## Before coding

1. Read `ARCHITECTURE.md` for file layout and gateway routes.
2. Prefer `make` over ad-hoc `xcodebuild` (no `.xcodeproj`).
3. After Swift changes, run `swift build` or `make build`.

## Definition of done (every code change)

**Do not finish a task with code-only diffs.** Same session:

1. **`make test`** — must pass; add tests in `Tests/CodexBarTests/` for behavior you changed.
2. **Smoke test** — for gateway/menu bar changes: `make run`, then `curl -s http://127.0.0.1:8765/health`.
3. **`ARCHITECTURE.md`** — update routes, source map, config paths, or common tasks → files when structure/flow changes.
4. **`README.md`** — update when users would notice the change.
5. **`BUILDING.md`** — update when build/packaging/scripts change.
6. **Skills/rules** — update relevant `.cursor/skills/` or `.cursor/rules/` if workflow changed.

Full checklist: `.cursor/rules/docs-and-tests.mdc`.

## Common tasks

| Task | Command |
|------|---------|
| Package .app | `make app` → `dist/CodexBar.app` |
| DMG | `make dmg` |
| Clean | `make clean` |
| Unit tests | `make test` |
| Install | `make install` |

## Codex Desktop dependency

App patches `~/.codex/config.toml` to route through the gateway. User needs Codex Desktop installed. Smoke test: `curl http://127.0.0.1:8765/health`.

## Architecture reminders

- Gateway: `GatewayServer` + `LoopbackHTTPServer`
- Translation: `Translator`
- Config: `ModelCatalog`, `CodexConfig`, `Paths`
- Menu bar: `StatusBarController` + `AppDelegate`
- Full map: `ARCHITECTURE.md`
- Do not commit unless the user asks.
