package com.artifact.chronograph.data

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import com.artifact.chronograph.core.CalendarItem
import com.artifact.chronograph.core.attendeeDisplayName
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
            CalendarContract.Instances.OWNER_ACCOUNT,
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
                // Attendees only matter where the detail block can draw them,
                // the same four-hour window the row builder fetches details in.
                val eventId = cursor.getLong(0)
                val (attendeeNames, attendeeCount) =
                    if (!allDay && start < now.plus(4, ChronoUnit.HOURS)) {
                        attendees(context, eventId, owner = cursor.getString(9))
                    } else {
                        emptyList<String>() to 0
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
                        attendeeNames = attendeeNames,
                        attendeeCount = attendeeCount,
                    )
                )
            }
        }
        return items.sortedBy { it.start }
    }

    /**
     * FacePile's data: short names of everyone but the calendar's owner (iOS
     * `isCurrentUser`), and the total count including them.
     */
    private fun attendees(context: Context, eventId: Long, owner: String?): Pair<List<String>, Int> {
        val projection = arrayOf(
            CalendarContract.Attendees.ATTENDEE_NAME,
            CalendarContract.Attendees.ATTENDEE_EMAIL,
        )
        val names = mutableListOf<String>()
        var count = 0
        CalendarContract.Attendees.query(context.contentResolver, eventId, projection)?.use { cursor ->
            while (cursor.moveToNext()) {
                count++
                val email = cursor.getString(1)
                if (owner != null && email.equals(owner, ignoreCase = true)) continue
                names += attendeeDisplayName(cursor.getString(0), email)
            }
        }
        return names to count
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
