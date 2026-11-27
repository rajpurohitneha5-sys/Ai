# AI — Personal Android AI workspace

This is the initial source foundation for a personal Android AI application. It is not a finished ChatGPT Pro clone or a tested APK yet.

## Contents
- Android/Kotlin/Jetpack Compose application shell with a black-and-gold theme and chat screen.
- TypeScript backend gateway sample with an OpenAI-compatible provider interface and streaming endpoint.
- Development blueprint and implementation checklist.

## Security
Do not put provider API keys in the Android app. Configure the backend's provider key using environment variables. Google Drive OAuth and sync are planned, not implemented in this foundation.

## Android
Open `android/` in Android Studio. Android SDK and Gradle are required. The project targets Android 35 and Java 17.

## Backend
In `backend/`: `npm install`, copy `.env.example` to `.env`, set your key, `npm run dev`. This sample is a development gateway; before public exposure add authentication, rate limits, monitoring, secure deployment, and provider policy checks.

## Stage 2 progress
See `docs/STAGE_2_GATEWAY.md`. A protected provider gateway, `/v1/models` endpoint, non-streaming chat endpoint, and minimal Android client foundation are included. This is not yet a complete integrated chat workflow or verified Android build.

## Stage 3 — connected chat UI foundation
This stage integrates the Android chat screen with the gateway client: configure endpoint/token in app Settings, request models, select a model, and send chat messages. This is a non-streaming request implementation and does not yet persist chats or support canceling active HTTP requests.

## Stage 4 — Local chat persistence
The Stage 4 package includes an SQLite chat store and integrates message loading and successful message saves into the starter chat screen. Drive sync remains a later stage. See `docs/STAGE_4_LOCAL_CHAT_STORAGE.md`.


## Stage 5 batch
See `docs/STAGE_5_BATCH.md`. Added streaming client, workspace store schema, project/memory APIs, tool contracts and Drive sync contracts. These additions are source foundations and have not yet been compiled or device-tested.
