package com.artifact.chronograph.core

/**
 * Port of apple/Extensions/Enigma.swift — IPA phonemes in the style of
 * https://github.com/arfct/enigma with its defaults. CMU dictionary first,
 * spelling rules for out-of-vocabulary words. Verified identical to the
 * Swift implementation by fixtures/obfuscation-vectors.tsv.
 */
fun convertToEnigma(input: String, dictionary: Cmudict?): String =
    input.split(" ").joinToString(" ") { enigmaToken(it, dictionary) }

/**
 * URLs and acronyms have no useful pronunciation, so phonemizing them destroys
 * the only thing that made them readable. Acronyms pass through untouched;
 * URLs are reduced to their host. Braille is unaffected: it is a character
 * cipher, and every character still maps.
 */
private fun enigmaToken(token: String, dictionary: Cmudict?): String = when {
    urlPattern.containsMatchIn(token) -> simplifyUrls(token)
    isAcronym(token) -> token
    else -> enigmaWord(token, dictionary)
}

/**
 * Reduces every URL in the token to its bare host: scheme, `www.` and the path
 * are all dropped, so `https://meet.google.com/abc-defg` reads
 * `meet.google.com`. Surrounding punctuation is left alone, and dropping the
 * path also drops the meeting id — this mode is meant to be shoulder-safe.
 */
private fun simplifyUrls(token: String): String =
    urlPattern.replace(token) { simplifyUrl(it.value) }

private fun simplifyUrl(url: String): String {
    var host = url
    val scheme = host.indexOf("://")
    if (scheme >= 0) host = host.substring(scheme + 3)
    val cut = host.indexOfFirst { it == '/' || it == '?' || it == '#' }
    if (cut >= 0) host = host.substring(0, cut)
    if (host.lowercase().startsWith("www.")) host = host.substring(4)
    return host
}

/**
 * Matches explicit schemes, `www.` hosts, and bare hosts like
 * `meet.google.com/abc-defg` — meeting links usually arrive bare in the
 * location field. Requires an alphabetic TLD of 2+ characters, so "e.g." and
 * "i.e." are not treated as hosts. A match never ends on trailing
 * punctuation, so a URL inside parentheses keeps its closing bracket.
 */
private val urlPattern = Regex(
    """(?:[a-z][a-z0-9+.\-]*://\S*[^\s.,;:!?)\]}>"'])""" +
        """|(?:www\.\S*[^\s.,;:!?)\]}>"'])""" +
        """|(?:[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9\-]{0,61}[a-z0-9])?)*""" +
        """\.[a-z]{2,24}(?:[/?#]\S*[^\s.,;:!?)\]}>"'])?)""",
    RegexOption.IGNORE_CASE,
)

/**
 * An all-caps run of 2–5 letters, optionally pluralised: PTO, EOD, NYC, OKRs.
 * The upper bound keeps a shouty title ("TEAM OFFSITE") from passing through
 * wholesale, which would defeat the mode.
 */
private fun isAcronym(token: String): Boolean {
    val core = enigmaCore(token)
    if (core.length !in 2..5 && !(core.length == 6 && core.endsWith("s"))) return false
    val letters = if (core.endsWith("s")) core.dropLast(1) else core
    if (letters.length < 2) return false
    return letters.all { it.isUpperCase() && it.isLetter() }
}

/** The alphanumeric middle of a token, with surrounding punctuation peeled. */
private fun enigmaCore(word: String): String {
    val leading = word.takeWhile { !it.isLetter() && !it.isDigit() }
    val trailing = word.takeLastWhile { !it.isLetter() && !it.isDigit() }
        .let { if (it.length == word.length) "" else it }
    if (word.length < leading.length + trailing.length) return ""
    return word.substring(leading.length, word.length - trailing.length)
}

private fun enigmaWord(word: String, dictionary: Cmudict?): String {
    if (word.none { it.isLetter() }) return word

    val leading = word.takeWhile { !it.isLetter() && !it.isDigit() }
    val trailing = word.takeLastWhile { !it.isLetter() && !it.isDigit() }
        .let { if (it.length == word.length) "" else it }
    val core = word.substring(leading.length, word.length - trailing.length)
    if (core.isEmpty()) return word

    val wasCapitalized = core.first().isUpperCase()
    val lookupKey = core.lowercase().replace('’', '\'')
    // Fallback writes no stress: word-initial primary stress is unwritten.
    var ipa = dictionary?.lookup(lookupKey) ?: graphemesToIPA(lookupKey)

    if (wasCapitalized && ipa.isNotEmpty()) {
        // Unicode raises ϑ to Θ; the notation specifies ϴ (U+03F4).
        val upper = if (ipa.first() == 'ϑ') "ϴ" else ipa.first().uppercase()
        ipa = upper + ipa.substring(1)
    }
    return leading + ipa + trailing
}

// Ordered longest-match spelling rules; long vowels doubled ("Doubling aa").
private val enigmaRules = listOf(
    "tion" to "ʃən", "sion" to "ʒən", "ture" to "tʃəɹ", "ough" to "ɔɔ",
    "eigh" to "eɪ", "igh" to "aɪ", "tch" to "tʃ", "dge" to "dʒ",
    "ing" to "ɪŋ", "ear" to "ɪɹ", "air" to "ɛɹ", "oor" to "ɔɹ",
    "ch" to "tʃ", "sh" to "ʃ", "th" to "ϑ", "ph" to "f", "wh" to "w",
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
