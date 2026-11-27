package com.personal.ai.sync

/** Drive sync contract. OAuth, Drive API upload/download and conflict policy must be wired before this is production-ready. */
data class SyncItem(val localId: String, val type: String, val payload: String, val modifiedAt: Long)
enum class SyncState { IDLE, QUEUED, SYNCING, SYNCED, FAILED }
data class SyncResult(val state: SyncState, val message: String = "")
interface PersonalDriveSync {
    suspend fun upload(items: List<SyncItem>): SyncResult
    suspend fun downloadSince(cursor: String?): Pair<List<SyncItem>, String?>
    suspend fun verifyBackup(): Boolean
}
/** Offline queue abstraction; implementations can persist items in SQLite and schedule WorkManager. */
interface SyncQueue { fun enqueue(item: SyncItem); fun pending(): List<SyncItem>; fun markComplete(localId: String); fun markFailed(localId: String, reason: String) }
