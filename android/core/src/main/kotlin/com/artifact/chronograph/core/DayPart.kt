package com.artifact.chronograph.core

/**
 * Port of TimeZoneRowView.getTimeOfDay (apple/Common/ChronographRow.swift):
 * contiguous, non-overlapping buckets covering all 24 hours. `sfSymbol` names
 * the symbol iOS draws; the app maps each part to a Material Symbols vector
 * (`ic_daypart_*`) that stands in for it.
 */
enum class DayPart(val sfSymbol: String) {
    DAWN("sun.dust"),
    SUNRISE("sunrise"),
    MORNING("sun.min"),
    DAY("sun.max"),
    END_OF_DAY("sunset"),
    EVENING("sun.haze"),
    NIGHT("moon.stars.fill"),
    SLEEPING("moon.zzz.fill");

    /** Drives the dimmed italic row styling, so it always agrees with the icon. */
    val isLikelySleeping: Boolean get() = this == SLEEPING

    companion object {
        fun forHour(hour: Int): DayPart = when (hour) {
            7 -> DAWN
            8 -> SUNRISE
            in 9..10 -> MORNING
            in 11..16 -> DAY
            in 17..18 -> END_OF_DAY
            19 -> EVENING
            in 20..22 -> NIGHT
            else -> SLEEPING // 23 and 0–6
        }
    }
}
