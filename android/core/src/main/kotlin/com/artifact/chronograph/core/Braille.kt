package com.artifact.chronograph.core

// Port of apple/Extensions/Braille.swift — keep the two maps identical.
private val brailleMap = mapOf(
    'a' to "⠁", 'b' to "⠃", 'c' to "⠉", 'd' to "⠙", 'e' to "⠑",
    'f' to "⠋", 'g' to "⠛", 'h' to "⠓", 'i' to "⠊", 'j' to "⠚",
    'k' to "⠅", 'l' to "⠇", 'm' to "⠍", 'n' to "⠝", 'o' to "⠕",
    'p' to "⠏", 'q' to "⠟", 'r' to "⠗", 's' to "⠎", 't' to "⠞",
    'u' to "⠥", 'v' to "⠧", 'w' to "⠺", 'x' to "⠭", 'y' to "⠽",
    'z' to "⠵", ' ' to "⠀",

    '1' to "⠁", '2' to "⠃", '3' to "⠉", '4' to "⠙", '5' to "⠑",
    '6' to "⠋", '7' to "⠛", '8' to "⠓", '9' to "⠊", '0' to "⠚",

    '.' to "⠲", ',' to "⠂", '!' to "⠖", '?' to "⠦",
    ';' to "⠆", ':' to "⠒", '\'' to "⠄", '"' to "⠄⠄",
    '-' to "⠤", '(' to "⠐⠣", ')' to "⠐⠜", '/' to "⠌",
)

fun convertToBraille(input: String): String =
    input.lowercase().map { brailleMap[it] ?: it.toString() }.joinToString("")
