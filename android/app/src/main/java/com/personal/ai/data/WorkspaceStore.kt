package com.personal.ai.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.util.UUID

/** Schema for conversations, messages, projects and personal memory. */
class WorkspaceStore(context: Context) : SQLiteOpenHelper(context, "ai_workspace.db", null, 1) {
    override fun onConfigure(db: SQLiteDatabase) {
        db.setForeignKeyConstraintsEnabled(true)
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE conversations (id TEXT PRIMARY KEY, title TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, archived INTEGER NOT NULL DEFAULT 0, pinned INTEGER NOT NULL DEFAULT 0, model TEXT NOT NULL DEFAULT '')")
        db.execSQL("CREATE TABLE messages (id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at INTEGER NOT NULL, status TEXT NOT NULL DEFAULT 'complete', FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE)")
        db.execSQL("CREATE INDEX idx_messages_conversation ON messages(conversation_id, created_at)")
        db.execSQL("CREATE TABLE projects (id TEXT PRIMARY KEY, name TEXT NOT NULL, instructions TEXT NOT NULL DEFAULT '', created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)")
        db.execSQL("CREATE TABLE memories (id TEXT PRIMARY KEY, content TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, enabled INTEGER NOT NULL DEFAULT 1)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { }

    fun createConversation(title: String = "New chat", model: String = ""): String {
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        writableDatabase.execSQL("INSERT INTO conversations(id,title,created_at,updated_at,model) VALUES(?,?,?,?,?)", arrayOf(id,title,now,now,model))
        return id
    }

    fun addMessage(conversationId: String, role: String, content: String, status: String = "complete"): String {
        require(role in listOf("user","assistant","system","tool"))
        val id = UUID.randomUUID().toString()
        val now = System.currentTimeMillis()
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.execSQL("INSERT INTO messages(id,conversation_id,role,content,created_at,status) VALUES(?,?,?,?,?,?)", arrayOf(id,conversationId,role,content,now,status))
            db.execSQL("UPDATE conversations SET updated_at=? WHERE id=?", arrayOf(now,conversationId))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        return id
    }


    /** Recover incomplete assistant streams left behind by process death or force-close. */
    fun recoverInterruptedMessages(): Int {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val cursor = db.rawQuery("SELECT id, content FROM messages WHERE role='assistant' AND status='streaming'", null)
            val pending = mutableListOf<Pair<String, String>>()
            cursor.use { while (it.moveToNext()) pending.add(it.getString(0) to it.getString(1)) }
            val now = System.currentTimeMillis()
            pending.forEach { (id, content) ->
                val recovered = content.ifBlank { "Generation was interrupted. Please send your message again." }
                db.execSQL("UPDATE messages SET content=?, status='interrupted' WHERE id=?", arrayOf(recovered, id))
            }
            db.setTransactionSuccessful()
            return pending.size
        } finally { db.endTransaction() }
    }

    fun updateMessage(id: String, content: String, status: String) { writableDatabase.execSQL("UPDATE messages SET content=?,status=? WHERE id=?", arrayOf(content,status,id)) }
    fun renameConversation(id: String, title: String) { writableDatabase.execSQL("UPDATE conversations SET title=?,updated_at=? WHERE id=?", arrayOf(title,System.currentTimeMillis(),id)) }
    fun setPinned(id: String, value: Boolean) { writableDatabase.execSQL("UPDATE conversations SET pinned=?,updated_at=? WHERE id=?", arrayOf(if(value)1 else 0,System.currentTimeMillis(),id)) }
    fun setArchived(id: String, value: Boolean) { writableDatabase.execSQL("UPDATE conversations SET archived=?,updated_at=? WHERE id=?", arrayOf(if(value)1 else 0,System.currentTimeMillis(),id)) }

    fun deleteConversation(id: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            db.delete("messages", "conversation_id=?", arrayOf(id))
            db.delete("conversations", "id=?", arrayOf(id))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }

    fun listConversations(search: String = ""): List<Conversation> {
        val out=mutableListOf<Conversation>()
        readableDatabase.rawQuery("SELECT id,title,updated_at,pinned,archived,model FROM conversations WHERE title LIKE ? ORDER BY pinned DESC,updated_at DESC",arrayOf("%$search%")).use { c ->
            while(c.moveToNext()) out.add(Conversation(c.getString(0),c.getString(1),c.getLong(2),c.getInt(3)==1,c.getInt(4)==1,c.getString(5)))
        }
        return out
    }

    fun messages(conversationId: String): List<WorkspaceMessage> {
        val out=mutableListOf<WorkspaceMessage>()
        readableDatabase.rawQuery("SELECT id,role,content,created_at,status FROM messages WHERE conversation_id=? ORDER BY rowid ASC",arrayOf(conversationId)).use { c ->
            while(c.moveToNext()) out.add(WorkspaceMessage(c.getString(0),c.getString(1),c.getString(2),c.getLong(3),c.getString(4)))
        }
        return out
    }

    fun touchConversation(id: String, model: String? = null) {
        val now=System.currentTimeMillis()
        if(model==null) writableDatabase.execSQL("UPDATE conversations SET updated_at=? WHERE id=?",arrayOf(now,id))
        else writableDatabase.execSQL("UPDATE conversations SET updated_at=?,model=? WHERE id=?",arrayOf(now,model,id))
    }

    fun migrateLegacy(items: List<StoredMessage>): String? {
        if(items.isEmpty() || listConversations().isNotEmpty()) return null
        val db=writableDatabase
        db.beginTransaction()
        try {
            val id=UUID.randomUUID().toString()
            val now=System.currentTimeMillis()
            val title=items.firstOrNull { it.isUser }?.text?.take(60) ?: "Previous chat"
            db.execSQL("INSERT INTO conversations(id,title,created_at,updated_at,model) VALUES(?,?,?,?,?)",arrayOf(id,title,now,now,""))
            items.forEach { item ->
                db.execSQL("INSERT INTO messages(id,conversation_id,role,content,created_at,status) VALUES(?,?,?,?,?,?)",arrayOf(UUID.randomUUID().toString(),id,if(item.isUser) "user" else "assistant",item.text,System.currentTimeMillis(),"complete"))
            }
            db.setTransactionSuccessful()
            return id
        } finally { db.endTransaction() }
    }

    fun removeMessage(id: String) {
        val db=writableDatabase
        db.beginTransaction()
        try {
            val conversationId=db.rawQuery("SELECT conversation_id FROM messages WHERE id=?",arrayOf(id)).use { if(it.moveToFirst()) it.getString(0) else null }
            db.delete("messages","id=?",arrayOf(id))
            if(conversationId!=null) db.execSQL("UPDATE conversations SET updated_at=? WHERE id=?",arrayOf(System.currentTimeMillis(),conversationId))
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun updateMessageStatus(id: String,status:String) { writableDatabase.execSQL("UPDATE messages SET status=? WHERE id=?",arrayOf(status,id)) }
    fun addProject(name: String, instructions: String = ""): String {
        val id=UUID.randomUUID().toString(); val now=System.currentTimeMillis()
        writableDatabase.execSQL("INSERT INTO projects(id,name,instructions,created_at,updated_at) VALUES(?,?,?,?,?)",arrayOf(id,name,instructions,now,now))
        return id
    }
    fun projects(): List<Project> {
        val out=mutableListOf<Project>()
        readableDatabase.rawQuery("SELECT id,name,instructions,updated_at FROM projects ORDER BY updated_at DESC",null).use { c -> while(c.moveToNext()) out.add(Project(c.getString(0),c.getString(1),c.getString(2),c.getLong(3))) }
        return out
    }
    fun saveMemory(id: String?, content: String) {
        val now=System.currentTimeMillis(); val key=id?:UUID.randomUUID().toString()
        writableDatabase.execSQL("INSERT INTO memories(id,content,created_at,updated_at,enabled) VALUES(?,?,?,?,1) ON CONFLICT(id) DO UPDATE SET content=excluded.content,updated_at=excluded.updated_at,enabled=1",arrayOf(key,content,now,now))
    }
    fun memories(): List<MemoryItem> {
        val out=mutableListOf<MemoryItem>()
        readableDatabase.rawQuery("SELECT id,content,updated_at,enabled FROM memories ORDER BY updated_at DESC",null).use { c -> while(c.moveToNext()) out.add(MemoryItem(c.getString(0),c.getString(1),c.getLong(2),c.getInt(3)==1)) }
        return out
    }
    fun deleteMemory(id: String) { writableDatabase.delete("memories","id=?",arrayOf(id)) }
}
data class Conversation(val id:String,val title:String,val updatedAt:Long,val pinned:Boolean,val archived:Boolean,val model:String)
data class WorkspaceMessage(val id:String,val role:String,val content:String,val createdAt:Long,val status:String)
data class Project(val id:String,val name:String,val instructions:String,val updatedAt:Long)
data class MemoryItem(val id:String,val content:String,val updatedAt:Long,val enabled:Boolean)
