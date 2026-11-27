# Personal AI app target scope
This is a practical independent AI assistant, inspired by the general chat-and-tools workflow of modern AI assistants. It is not an exact copy of ChatGPT Pro, OpenAI branding, proprietary UI, or proprietary systems.

## Target features / implementation stages
- Core chat, model selection, configurable gateway
- Conversation management: new chat, history, rename, delete, search, archive, pin
- Streaming output, stop/cancel, retry and regenerate
- Markdown rendering, code blocks and copy actions
- Attachments: document/image upload and provider-compatible analysis (permissions and limits)
- Voice: speech input and text-to-speech
- Image generation integration via configured provider
- Web search integration through a separately configured search provider
- Memory controls: user-visible opt-in facts, review and delete
- Projects/workspaces and project-specific instructions
- Data export/import and backup/restore
- Privacy/security: secure token storage, redaction, request limits, provider-key server-side only
- Reliability: offline states, timeouts, retries, tests, logging without secrets
- Accessibility, dark/light themes and adaptive layout

## Status
The merged source remains a foundation. This package adds a build workflow, setup documentation, and a sample Apps Script gateway. The listed target features are not all implemented or verified. We will upload, build, install, test and iterate in stages; this bundle is not represented as production-ready.
