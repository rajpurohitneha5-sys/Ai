# Master Blueprint — AI personal app

## Goal
Personal Android app aiming at the closest practical feature parity with the ChatGPT Pro user experience using authorized services/APIs. This cannot reproduce OpenAI proprietary internals or guarantee identical proprietary features/models.

## Architecture
- Android: Kotlin, Jetpack Compose, MVVM, Room/local cache, WorkManager sync queue, encrypted local secrets.
- Backend gateway: TypeScript/Node, provider routing, streaming, tool orchestration, authentication, rate limits, audit/error telemetry.
- Personal data: local-first storage; Google Drive backup/synchronization. Drive is not used as a transactional database.
- Storage: user-owned Drive folder for chat snapshots, project files, exports, and backup manifests. Use OAuth scopes and encryption appropriate to data sensitivity.
- AI services: provider APIs; web search, vision, image generation, voice, analysis, and safe execution are integrations subject to availability and permissions.

## Feature inventory
1. Chat: streaming, stop, regenerate, edit, continue, copy, share, markdown, code, math, tables.
2. History: search, pin, archive, delete, export, recovery.
3. Model routing and model picker for supported providers.
4. Search/research and citation UI.
5. File upload and processing: PDF, DOCX, XLSX, CSV, TXT, images.
6. Vision and image-generation/editing integrations.
7. Voice input, TTS and conversational voice mode.
8. Data analysis, chart generation and isolated code execution.
9. Personal memory with review/edit/delete controls.
10. Projects with files, instructions and context.
11. Custom assistant profiles/configurations.
12. Workspace/artifact editing, conversion and export.
13. Drive backup/sync, offline queue, conflict handling, restore verification.
14. Settings, privacy, diagnostics, performance and security.

## Phases
- P0: foundation, theme, navigation, local data, Drive OAuth design.
- P1: gateway/provider streaming and persistent chat.
- P2: history and interaction features.
- P3: research, files, vision and image tools.
- P4: voice, analysis and coding tools.
- P5: memory, projects and custom assistants.
- P6: workspace/export and integrations.
- P7: Drive sync/recovery and security hardening.
- P8: exhaustive device, failure, performance and security tests.

## Acceptance gates
- No feature marked complete without a real workflow test.
- Never store provider API secrets in the APK or ordinary Drive files.
- Drive sync must be queued/retried, integrity-checked, and conflict-aware.
- Test offline, timeout, rate-limit, malformed response, interrupted stream, restore, deletion and duplicate sync.
- Measure startup and navigation; do not promise latency targets without device measurements.
