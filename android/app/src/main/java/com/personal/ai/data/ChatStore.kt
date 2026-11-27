package com.personal.ai.data

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper

/** Persistent local chat store. Drive sync is intentionally a separate later layer. */
class ChatStore(context: Context) : SQLiteOpenHelper(context, "ai_chat_store.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("CREATE TABLE messages (id INTEGER PRIMARY KEY AUTOINCREMENT, text TEXT NOT NULL, is_user INTEGER NOT NULL, created_at INTEGER NOT NULL)")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) { }
    fun save(text: String, isUser: Boolean) {
        writableDatabase.execSQL("INSERT INTO messages(text,is_user,created_at) VALUES(?,?,?)", arrayOf(text, if (isUser) 1 else 0, System.currentTimeMillis()))
    }
    fun load(): List<StoredMessage> {
        val result = mutableListOf<StoredMessage>()
        readableDatabase.rawQuery("SELECT text,is_user FROM messages ORDER BY id", null).use { c ->
            while (c.moveToNext()) result += StoredMessage(c.getString(0), c.getInt(1) == 1)
        }
        return result
    }
    fun clear() { writableDatabase.delete("messages", null, null) }
}
data class StoredMessage(val text: String, val isUser: Boolean)
