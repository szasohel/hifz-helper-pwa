# Hifz Helper PWA

## Setup checklist
- [x] Verify this workspace instruction file exists.
- [x] Clarify requirements: independent Flutter Web project; preserve all existing features.
- [x] Scaffold the project: copy the app, assets, tests and web runtime, not native runners.
- [x] Customize project identity, web launch configuration and development documentation.
- [x] Install required extensions: skipped; no additional extension installation required.
- [x] Compile the project: dependencies resolved, no analyzer errors/warnings, all 35 tests pass, web release builds. Nine inherited informational scheduler lints remain.
- [x] Create and run the web build task: task created; VS Code task discovery could not see the unopened sibling, so its exact build command was verified in the terminal.
- [x] Launch the project: deferred; debug launch has not been requested.
- [x] Ensure documentation reflects verified setup results.

## Boundaries
- Work only in this independent PWA repository. Never edit the original hifz-helper repository.
- Preserve the copied UI, scheduling, completion rules, persistence, practice and reader behavior.
- Retain the hifz_helper Dart package name for existing imports and tests. App release versions are independent.
- Use Flutter 3.47.2 / Dart 3.13.2 for the initial baseline; keep pubspec.lock committed.
- Run flutter analyze --no-fatal-infos, flutter test and the Build PWA release task before claiming a verified baseline. Strict flutter analyze currently exits nonzero for nine inherited informational private-type API lints; do not hide new warnings/errors.
- dart_test.yaml serializes the copied tests because they share a persistent SQLite filename. The icon test checks web rather than Android launcher assets.
- Offline audio, custom app service worker, robust content packs, backup/restore and deployment remain separate implementation work. Do not describe the copied baseline as production-ready offline.
- sqflite_sw.js is the SQLite worker, not a PWA service worker. Keep its matching sqlite3.wasm artifact.
- Browser storage and background behavior vary; verify actual devices rather than promise universal native parity.
- Do not add login, cloud sync, new business rules or native platform scaffolding.