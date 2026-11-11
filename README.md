# Hifz Helper PWA

Independent Flutter Web fork of Hifz Helper. The native application is not modified or linked at runtime.

## Baseline

- Source version: 1.0.8+8, source commit: 8d038595136b6a839e463f1d7b476b93c29385e9.
- PWA version: 0.1.0+1; Dart package name remains `hifz_helper` to preserve imports/tests.
- Toolchain: Flutter 3.47.2 stable, Dart 3.13.2. Resolve with the committed dependency lock.
- Copied application code, fonts/icons, tests, web shell and SQLite runtime. No native runners or shared source dependencies.
- Existing features are retained as the baseline. This setup is **not yet the completed offline PWA**.

## Development

Open the included workspace file in VS Code. Select **Hifz PWA — Chrome** and press F5 to debug. The fixed localhost port 8080 keeps the browser storage origin consistent across sessions.

Use the VS Code tasks **Analyze PWA**, **Test PWA**, **Build PWA release**, and **Refresh SQLite web runtime**. The build output is `build/web`; its renderer assets are bundled locally rather than loaded from the Flutter CDN.

The SQLite runtime refresh task regenerates the worker/WASM pair for the resolved dependencies. Review both artifacts together after dependency upgrades. It is not the offline app service worker.

Do not run native-platform builds or regenerate the native application from this repository. Future upstream changes must be deliberately ported into this fork and re-tested.

## Next implementation milestones

1. Validate real-browser persistence, audio gestures and upstream CORS on Android Chrome and iOS Safari.
2. Add deterministic local bootstrap, single-writer coordination and a versioned offline shell service worker.
3. Track complete text packs for both scripts, translations and word meanings; retry failed downloads honestly.
4. Implement persistent browser audio caching and URI-based cached playback, retaining both reciters and all practice behavior.
5. Add resumable foreground downloads, storage controls and full user-progress/preferences backup/restore.
6. Add install/update guidance and bundle all runtime fonts.
7. Test installed devices, offline cold starts, quota failures, backup recovery and non-destructive updates.
8. Publish to a stable HTTPS Cloudflare Pages origin after release gates pass.

## Known baseline limitations

- Audio cache is a web stub: no guaranteed offline audio.
- The copied Quran downloader does not establish full script/word/audio completeness and can flag completion after failures.
- No custom offline app worker, backup/restore UI or deployment automation is implemented yet.
- Outfit typography can still be fetched at runtime by google_fonts.
- Data is local to the browser origin/profile/device, not synced with the native application or other devices.
- Installation support, wake lock, background audio and suspended downloads depend on browser/OS. Browser storage may be cleared or evicted; manual backups will be necessary.

No account backend or paid hosting is required by the agreed design. External data sources and free hosting limits must be validated before release.

## Verified setup results — November 11, 2026

- Dependencies resolved using the copied lockfile without a package upgrade.
- SQLite worker and WASM regenerated together for sqflite_common_ffi_web 1.1.3.
- All **35 tests pass**. Tests run serially because inherited fixtures use the same SQLite database; the launcher icon test now checks PWA assets instead of absent Android runners.
- Analyzer reports no errors or warnings; nine inherited informational private-type API notices remain in the unchanged scheduler. The Analyze PWA task uses --no-fatal-infos; strict analysis still reports them as a nonzero result.
- Web release builds successfully with local Flutter renderer assets. This does not yet verify offline behavior or real-device browser functionality.
- VS Code task creation succeeded but immediate task discovery outside the active workspace did not; the same release command succeeded in the terminal.