# Stage 4 — Local chat persistence

This stage introduces SQLite-backed persistence on Android for chat messages.

- Messages are stored locally to support app restart recovery.
- Storage is separate from Drive; Drive synchronization is not yet implemented.
- This simple foundation stores one message timeline and supports clearing it.
- API credentials must not be placed in this database.
- Before production, add conversation IDs, timestamps exposed to UI, message edit/delete, migrations, backup policy, and encryption appropriate to threat model.

## Integration
`ChatStore` is in `com.personal.ai.data`. Instantiate with Activity context, call `load()` on startup, and `save(text, isUser)` whenever a user or assistant message is committed. Call `clear()` only from an explicit user action.
