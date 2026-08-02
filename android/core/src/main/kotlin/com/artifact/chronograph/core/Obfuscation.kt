package com.artifact.chronograph.core

/**
 * Android counterpart of apple/Extensions/Obfuscation.swift, minus Ishihara:
 * that mode is a font swap, Glance can't apply custom fonts (see the spike
 * results in the design spec), and it's deliberately out of scope on Android.
 */
enum class ObfuscationStyle {
    NONE, BRAILLE, ENIGMA;

    fun transform(text: String, dictionary: Cmudict?): String = when (this) {
        NONE -> text
        BRAILLE -> convertToBraille(text)
        ENIGMA -> convertToEnigma(text, dictionary)
    }
}
