package com.artifact.chronograph.data

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import com.artifact.chronograph.core.CalendarItem
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

/**
 * CalendarContract → :core CalendarItem. Counterpart of TimelineEngine's
 * fetchEvents (EventKit): instances from now through +7 days, sorted by start.
 */
object CalendarRepository {

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    fun queryItems(
        context: Context,
        now: Instant = Instant.now(),
        days: Long = 7,
        zone: ZoneId = ZoneId.systemDefault(),
    ): List<CalendarItem> {
        if (!hasPermission(context)) return emptyList()

        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().apply {
            ContentUris.appendId(this, now.toEpochMilli())
            ContentUris.appendId(this, now.plus(days, ChronoUnit.DAYS).toEpochMilli())
        }.build()

        val projection = arrayOf(
            CalendarContract.Instances.EVENT_ID,
            CalendarContract.Instances.TITLE,
            CalendarContract.Instances.BEGIN,
            CalendarContract.Instances.END,
            CalendarContract.Instances.ALL_DAY,
            CalendarContract.Instances.CALENDAR_ID,
            CalendarContract.Instances.CALENDAR_DISPLAY_NAME,
            CalendarContract.Instances.EVENT_LOCATION,
            CalendarContract.Instances.DESCRIPTION,
        )

        val defaultCalendarId = defaultCalendarId(context)
        val items = mutableListOf<CalendarItem>()
        context.contentResolver.query(
            uri, projection, null, null, "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val allDay = cursor.getInt(4) == 1
                var start = Instant.ofEpochMilli(cursor.getLong(2))
                var end = Instant.ofEpochMilli(cursor.getLong(3))
                if (allDay) {
                    // All-day instances are UTC midnights; remap to local days and
                    // pull the exclusive end back inside its last day so the
                    // builder's single-day check behaves like EventKit's.
                    start = start.atZone(ZoneOffset.UTC).toLocalDate().atStartOfDay(zone).toInstant()
                    end = end.atZone(ZoneOffset.UTC).toLocalDate()
                        .atStartOfDay(zone).toInstant().minusSeconds(1)
                }
                items.add(
                    CalendarItem(
                        id = cursor.getLong(0).toString(),
                        title = cursor.getString(1),
                        start = start,
                        end = end,
                        isAllDay = allDay,
                        calendarId = cursor.getLong(5).toString(),
                        calendarTitle = cursor.getString(6) ?: "",
                        location = cursor.getString(7),
                        description = cursor.getString(8),
                        isDefaultCalendar = defaultCalendarId == null ||
                            cursor.getLong(5).toString() == defaultCalendarId,
                    )
                )
            }
        }
        return items.sortedBy { it.start }
    }

    /** iOS defaultCalendarForNewEvents analogue: the primary calendar, else the first. */
    private fun defaultCalendarId(context: Context): String? {
        val projection = arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.IS_PRIMARY)
        var first: String? = null
        context.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI, projection, null, null,
            "${CalendarContract.Calendars._ID} ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0).toString()
                if (first == null) first = id
                if (cursor.getInt(1) == 1) return id
            }
        }
        return first
    }
}
