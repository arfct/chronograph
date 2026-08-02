package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.DynamicTest
import org.junit.jupiter.api.TestFactory
import java.io.File
import java.nio.ByteBuffer

/**
 * Golden-vector parity with the Swift implementation. The fixtures are
 * generated FROM apple/Extensions (the source of truth); if this test
 * fails, fix the Kotlin port — never the vectors by hand.
 */
class ObfuscationVectorsTest {

    private val dictionary = Cmudict(
        ByteBuffer.wrap(File(System.getProperty("chronograph.cmudict")).readBytes())
    )

    @TestFactory
    fun `vectors match the Swift implementation`(): List<DynamicTest> {
        val lines = File(System.getProperty("chronograph.fixtures"), "obfuscation-vectors.tsv")
            .readLines()
            .drop(1) // header
            .filter { it.isNotBlank() }

        check(lines.size >= 30) { "suspiciously few vectors: ${lines.size}" }

        return lines.flatMap { line ->
            val (input, braille, enigma) = line.split("\t")
            listOf(
                DynamicTest.dynamicTest("braille: $input") {
                    assertEquals(braille, convertToBraille(input))
                },
                DynamicTest.dynamicTest("enigma: $input") {
                    assertEquals(enigma, convertToEnigma(input, dictionary))
                },
            )
        }
    }
}
