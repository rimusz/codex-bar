---
name: codexbar-release
description: Versions, packages, signs, notarizes, and publishes CodexBar GitHub releases. Use when bumping VERSION, running make release, editing release.yml, or helping with codesigning/notarization.
---

# CodexBar release

## Version files

- `VERSION` — semver baked into Info.plist at package time; About/menu prefer that, with a `VERSION`-file fallback for unpackaged builds (e.g. `1.0.0`)
- Tag format: `v{VERSION}` (e.g. `v1.0.0`)

## CI release (unsigned)

Workflow: `.github/workflows/release.yml` — **Actions → Release → Run workflow**. Publishes unsigned `.app.zip` + DMG only.

**Notarized release:** local `make release RELEASE_TYPE=notarized` with `.env` (`SIGN_IDENTITY`, `NOTARY_PROFILE`).

## Local release

```bash
cp .env.example .env   # optional: SIGN_IDENTITY, NOTARY_PROFILE
make release           # unsigned, publishes via gh
make release RELEASE_TYPE=notarized
```

Script: `scripts/release.sh`. Requires `gh auth login`. Use one path per version — CI or local, not both.

## Checklist

1. Bump `VERSION`
2. **`make test`** — must pass; add tests if release/packaging logic changed
3. `make app` or `make dmg` to verify packaging
4. **Update docs** — `BUILDING.md`, `README.md` (install), `ARCHITECTURE.md` if structure changed
5. Commit on feature branch; user creates tag/PR
6. Do not force-push `main` or skip git hooks unless asked

## Packaging

- Bundle ID: `com.rimusz.CodexBar`
- Output: `dist/CodexBar.app`, `dist/CodexBar-macOS.dmg`
- Scripts: `scripts/build-macos-app.sh`, `scripts/codesign-app-bundle.sh`, `scripts/notarize.sh`, `scripts/codexbar-install-update.sh`

When changing release naming, assets, packaging, or in-app update behavior, update `BUILDING.md` and `ARCHITECTURE.md`.
