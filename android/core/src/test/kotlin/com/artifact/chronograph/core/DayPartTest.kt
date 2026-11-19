package com.artifact.chronograph.core

import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class DayPartTest {
    @Test
    fun `every hour maps to the bucket iOS uses`() {
        val expected = mapOf(
            0 to DayPart.SLEEPING, 3 to DayPart.SLEEPING, 6 to DayPart.SLEEPING,
            7 to DayPart.DAWN,
            8 to DayPart.SUNRISE,
            9 to DayPart.MORNING, 10 to DayPart.MORNING,
            11 to DayPart.DAY, 16 to DayPart.DAY,
            17 to DayPart.END_OF_DAY, 18 to DayPart.END_OF_DAY,
            19 to DayPart.EVENING,
            20 to DayPart.NIGHT, 22 to DayPart.NIGHT,
            23 to DayPart.SLEEPING,
        )
        for ((hour, part) in expected) assertEquals(part, DayPart.forHour(hour), "hour $hour")
    }

    @Test
    fun `morning and sleeping are reachable and every bucket is used`() {
        val used = (0..23).map(DayPart::forHour).toSet()
        assertEquals(DayPart.entries.toSet(), used)
    }

    @Test
    fun `sleeping styling agrees with the sleeping icon`() {
        for (hour in 0..23) {
            val part = DayPart.forHour(hour)
            assertEquals(part == DayPart.SLEEPING, part.isLikelySleeping, "hour $hour")
        }
        assertTrue(DayPart.forHour(2).isLikelySleeping)
        assertFalse(DayPart.forHour(22).isLikelySleeping)
    }
}
