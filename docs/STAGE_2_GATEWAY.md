# Stage 2 — AI gateway and client foundation

This stage adds a protected, OpenAI-compatible chat-completions gateway and a minimal Android HTTP client.

## Gateway setup
1. Install Node.js 20+.
2. In `backend`, run `npm install`.
3. Copy `.env.example` to `.env` and configure `AI_GATEWAY_TOKEN`, `AI_PROVIDER_API_KEY`, `AI_PROVIDER_BASE_URL`, and `AI_PROVIDER_MODEL`.
4. Run `npm run dev` (or the configured start command).
5. Test `GET /health`, then authorized `GET /v1/models` and `POST /v1/chat/completions`.

## Security and deployment notes
- Do not place provider keys or gateway tokens in the APK, Git history, or chat messages.
- Use HTTPS in deployment; do not use cleartext HTTP on production Android builds.
- Restrict CORS and gateway access for production.
- The sample gateway token is a starter protection, not a complete authentication system.
- Provider model IDs must be configured and supported by the selected provider.
- This client is a basic non-streaming foundation; streaming UI, cancellation, persistent chat database, Drive sync and credential management are later work.

## Android client
`GatewayClient.kt` supplies `complete()` and `listModels()` methods. The app needs a UI/ViewModel integration, endpoint configuration, and secure token storage before these methods are used in production.
