package com.artifact.chronograph.core

/**
 * Port of apple/Extensions/Enigma.swift — IPA phonemes in the style of
 * https://github.com/arfct/enigma with its defaults. CMU dictionary first,
 * spelling rules for out-of-vocabulary words. Verified identical to the
 * Swift implementation by fixtures/obfuscation-vectors.tsv.
 */
fun convertToEnigma(input: String, dictionary: Cmudict?): String =
    input.split(" ").joinToString(" ") { enigmaWord(it, dictionary) }

private fun enigmaWord(word: String, dictionary: Cmudict?): String {
    if (word.none { it.isLetter() }) return word

    val leading = word.takeWhile { !it.isLetter() && !it.isDigit() }
    val trailing = word.takeLastWhile { !it.isLetter() && !it.isDigit() }
        .let { if (it.length == word.length) "" else it }
    val core = word.substring(leading.length, word.length - trailing.length)
    if (core.isEmpty()) return word

    val wasCapitalized = core.first().isUpperCase()
    val lookupKey = core.lowercase().replace('’', '\'')
    var ipa = dictionary?.lookup(lookupKey) ?: applyStressAccent(graphemesToIPA(lookupKey))

    if (wasCapitalized && ipa.isNotEmpty()) {
        ipa = ipa.first().uppercase() + ipa.substring(1)
    }
    return leading + ipa + trailing
}

// Ordered longest-match spelling rules; long vowels doubled ("Doubling aa").
private val enigmaRules = listOf(
    "tion" to "ʃən", "sion" to "ʒən", "ture" to "tʃəɹ", "ough" to "ɔɔ",
    "eigh" to "eɪ", "igh" to "aɪ", "tch" to "tʃ", "dge" to "dʒ",
    "ing" to "ɪŋ", "ear" to "ɪɹ", "air" to "ɛɹ", "oor" to "ɔɹ",
    "ch" to "tʃ", "sh" to "ʃ", "th" to "θ", "ph" to "f", "wh" to "w",
    "ck" to "k", "ng" to "ŋ", "qu" to "kw", "wr" to "ɹ", "kn" to "n",
    "ee" to "ii", "ea" to "ii", "oo" to "uu", "ou" to "aʊ", "ow" to "aʊ",
    "oi" to "ɔɪ", "oy" to "ɔɪ", "ai" to "eɪ", "ay" to "eɪ", "au" to "ɔɔ",
    "aw" to "ɔɔ", "ew" to "juu", "oa" to "oʊ", "ie" to "aɪ", "ue" to "uu",
    "er" to "əɹ", "ar" to "ɑɹ", "or" to "ɔɹ",
)

private val enigmaSingles = mapOf(
    'a' to "æ", 'e' to "ɛ", 'i' to "ɪ", 'o' to "ɑ", 'u' to "ʌ",
    'b' to "b", 'd' to "d", 'f' to "f", 'h' to "h", 'j' to "dʒ", 'k' to "k",
    'l' to "l", 'm' to "m", 'n' to "n", 'p' to "p", 'r' to "ɹ", 's' to "s",
    't' to "t", 'v' to "v", 'w' to "w", 'x' to "ks", 'z' to "z",
)

private fun graphemesToIPA(word: String): String {
    var characters = word.toCharArray().toMutableList()

    // Magic-e: a final silent e lengthens the previous vowel sound.
    if (characters.size > 3 && characters.last() == 'e' &&
        characters[characters.size - 2] !in "aeiou"
    ) {
        characters.removeAt(characters.size - 1)
    }

    val result = StringBuilder()
    var i = 0
    while (i < characters.size) {
        val rest = String(characters.subList(i, characters.size).toCharArray())

        val rule = enigmaRules.firstOrNull { rest.startsWith(it.first) }
        if (rule != null) {
            result.append(rule.second)
            i += rule.first.length
            continue
        }

        val char = characters[i]
        val next = characters.getOrNull(i + 1)
        when (char) {
            'c' -> result.append(if (next != null && next in "eiy") "s" else "k")
            'g' -> result.append(if (next != null && next in "eiy") "dʒ" else "g")
            'y' -> result.append(if (i == 0) "j" else "i")
            else -> result.append(enigmaSingles[char] ?: char.toString())
        }
        i++
    }
    return result.toString()
}

private val ipaVowels = "æɛɪɑʌəaeiouʊɔ".toSet()

/** First-syllable stress as a combining acute accent. */
private fun applyStressAccent(ipa: String): String {
    var vowelGroups = 0
    var previousWasVowel = false
    for (character in ipa) {
        val isVowel = character in ipaVowels
        if (isVowel && !previousWasVowel) vowelGroups++
        previousWasVowel = isVowel
    }
    if (vowelGroups <= 1) return ipa

    val index = ipa.indexOfFirst { it in ipaVowels }
    if (index < 0) return ipa
    return StringBuilder(ipa).insert(index + 1, '́').toString()
}
