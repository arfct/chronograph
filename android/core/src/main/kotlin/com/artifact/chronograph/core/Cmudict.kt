package com.artifact.chronograph.core

import java.nio.ByteBuffer

/**
 * Port of apple/Extensions/Cmudict.swift: sorted "word\tipa" lines,
 * binary-searched in place so the 2.8 MB dictionary is never parsed into
 * heap objects. The caller supplies the bytes (memory-mapped on Android,
 * read from disk in JVM tests).
 */
class Cmudict(private val data: ByteBuffer) {

    fun lookup(word: String): String? {
        if (word.isEmpty() || word.length >= 50) return null
        val key = (word + "\t").toByteArray(Charsets.UTF_8)

        var low = 0
        var high = data.limit() - 1
        while (low <= high) {
            val mid = (low + high) / 2
            val lineStart = startOfLine(mid)
            when (compareLine(key, lineStart)) {
                0 -> return ipaAt(lineStart, key.size)
                -1 -> high = lineStart - 1
                else -> low = endOfLine(lineStart) + 1
            }
        }
        return null
    }

    private fun startOfLine(index: Int): Int {
        var i = index
        while (i > 0 && data.get(i - 1) != NEWLINE) i--
        return i
    }

    private fun endOfLine(index: Int): Int {
        var i = index
        while (i < data.limit() && data.get(i) != NEWLINE) i++
        return i
    }

    /** -1 if the key sorts before this line, 0 on prefix match, 1 after. */
    private fun compareLine(key: ByteArray, lineStart: Int): Int {
        for (offset in key.indices) {
            val index = lineStart + offset
            val lineByte = if (index < data.limit()) data.get(index) else NEWLINE
            val diff = (key[offset].toInt() and 0xFF) - (lineByte.toInt() and 0xFF)
            if (diff < 0) return -1
            if (diff > 0) return 1
        }
        return 0
    }

    private fun ipaAt(lineStart: Int, keyLength: Int): String? {
        val valueStart = lineStart + keyLength
        val valueEnd = endOfLine(valueStart)
        if (valueStart > valueEnd) return null
        val bytes = ByteArray(valueEnd - valueStart)
        data.duplicate().position(valueStart).get(bytes)
        return String(bytes, Charsets.UTF_8)
    }

    private companion object {
        const val NEWLINE = '\n'.code.toByte()
    }
}
