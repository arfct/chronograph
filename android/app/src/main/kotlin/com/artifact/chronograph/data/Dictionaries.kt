package com.artifact.chronograph.data

import android.content.Context
import com.artifact.chronograph.core.Cmudict
import java.nio.ByteBuffer

/**
 * Lazy process-wide CMUdict (2.8 MB, synced from apple/Extensions by
 * scripts/sync-assets.sh). Null when the asset wasn't synced — Enigma then
 * falls back to its rule-based grapheme conversion.
 */
object Dictionaries {
    @Volatile private var attempted = false
    @Volatile private var cmudict: Cmudict? = null

    fun cmudict(context: Context): Cmudict? {
        if (!attempted) {
            synchronized(this) {
                if (!attempted) {
                    cmudict = runCatching {
                        context.assets.open("cmudict-ipa.txt").use {
                            Cmudict(ByteBuffer.wrap(it.readBytes()))
                        }
                    }.getOrNull()
                    attempted = true
                }
            }
        }
        return cmudict
    }
}
