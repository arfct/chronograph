#!/usr/bin/env bash
#
# Seeds the attached emulator's calendar with a realistic day, relative to the
# device's current clock. Idempotent: it clears its own events first.
#
# The fixtures deliberately exercise the row types the widget can draw — a
# conferencing link, a physical location, a description carrying Gmail's
# boilerplate, and a following day — so a screenshot taken from this state shows
# what the widget is actually for.
#
#   android/scripts/seed-calendar.sh
#
# Store screenshots are captured from this state; see android/RELEASING.md.
#
# Two quirks of `adb shell content` shape the whole script:
#
#   1. The command line is re-parsed by a shell on the device, so every value has
#      to carry quotes that survive that second pass — not just the local ones.
#   2. `--bind key:s:value` is split on every colon, so a value containing one
#      (any URL) cannot be inserted this way at all. Those fields are written
#      afterwards with sqlite3, which is safe because only text changes: the
#      event times are untouched, so the provider's instance expansion stays
#      valid.

set -euo pipefail

ACCOUNT="chronograph"
CAL_NAME="Work"
URI_CAL="content://com.android.calendar/calendars"
URI_EVT="content://com.android.calendar/events"
CAL_DB="/data/data/com.android.providers.calendar/databases/calendar.db"

MEET_URL="https://meet.google.com/abc-defg-hij"
STANDUP_NOTE="Blockers first, then the release. This event was created from an email you received in Gmail. https://mail.google.com/mail?extsrc=cal"

adb shell true >/dev/null 2>&1 || { echo "no device attached" >&2; exit 1; }

TZ_NAME=$(adb shell getprop persist.sys.timezone | tr -d '\r')
NOW=$(adb shell date +%s | tr -d '\r')
# Midnight today, device-local: subtract the local time-of-day from now.
SECS_TODAY=$(adb shell date +%H:%M:%S | tr -d '\r' | awk -F: '{print $1*3600 + $2*60 + $3}')
MIDNIGHT=$((NOW - SECS_TODAY))

echo "device now $(adb shell date | tr -d '\r')  tz=$TZ_NAME"

# --- calendar ---------------------------------------------------------------
# The device shell strips plain single quotes, so SQL string literals have to
# arrive escaped or the provider reads the value as a column name.
find_cal() {
  adb shell content query --uri "$URI_CAL" --projection _id \
    --where "account_name=\\'$ACCOUNT\\'" 2>/dev/null |
    sed -n 's/.*_id=\([0-9]*\).*/\1/p' | head -1
}

CAL_ID=$(find_cal)
if [ -z "$CAL_ID" ]; then
  adb shell content insert --uri \
    "\"$URI_CAL?account_name=$ACCOUNT&account_type=LOCAL&caller_is_syncadapter=true\"" \
    --bind account_name:s:"$ACCOUNT" \
    --bind account_type:s:LOCAL \
    --bind name:s:"$CAL_NAME" \
    --bind calendar_displayName:s:"$CAL_NAME" \
    --bind calendar_color:i:-14654801 \
    --bind calendar_access_level:i:700 \
    --bind visible:i:1 \
    --bind sync_events:i:1 \
    --bind calendar_timezone:s:"$TZ_NAME"
  CAL_ID=$(find_cal)
fi
[ -n "$CAL_ID" ] || { echo "could not resolve a calendar id" >&2; exit 1; }
echo "calendar id $CAL_ID"

adb shell content delete --uri "$URI_EVT" --where "calendar_id=$CAL_ID"

# --- events -----------------------------------------------------------------
# add <start-offset-secs> <duration-secs> <title> [location]
#
# No value here may contain a single quote; they are the device shell's quoting.
add() {
  local start=$(( (MIDNIGHT + $1) * 1000 ))
  local end=$(( (MIDNIGHT + $1 + $2) * 1000 ))
  # Epoch millis overflow content's 32-bit `i`, so they bind as `l`.
  local cmd="content insert --uri $URI_EVT"
  cmd+=" --bind calendar_id:i:$CAL_ID"
  cmd+=" --bind title:s:'$3'"
  cmd+=" --bind dtstart:l:$start"
  cmd+=" --bind dtend:l:$end"
  cmd+=" --bind eventTimezone:s:'$TZ_NAME'"
  [ -n "${4:-}" ] && cmd+=" --bind eventLocation:s:'$4'"
  adb shell "$cmd"
  echo "  + $3"
}

H=3600
# Today. The 09:00 standup sits inside the four-hour detail window, so its
# meeting link, note and boilerplate-stripping all render.
add $((9 * H))            $((15 * 60)) "Standup"
add $((10 * H + 30 * 60)) $((60 * 60)) "Design review — widgets"
add $((12 * H + 15 * 60)) $((60 * 60)) "Lunch w/ Priya" "Tartine, 600 Guerrero St"
add $((16 * H))           $((45 * 60)) "Ship Play release"

# Tomorrow, so the widget draws a second day header.
add $((24 * H + 9 * H))  $((60 * 60))  "Sprint kickoff"
add $((24 * H + 14 * H)) $((120 * 60)) "Museum with Ana" "SFMOMA"

# --- the fields content cannot bind ----------------------------------------
sql() { adb shell "sqlite3 $CAL_DB \"$1\""; }
sql "UPDATE Events SET eventLocation='$MEET_URL' WHERE title='Standup';"
sql "UPDATE Events SET description='$STANDUP_NOTE' WHERE title='Standup';"
sql "UPDATE Events SET description='Bring the Play screenshots.' WHERE title='Design review — widgets';"
echo "  ~ patched Standup location/description and the review note"

# The provider holds the database open; restart it so the text changes are read.
adb shell am force-stop com.android.providers.calendar >/dev/null 2>&1 || true

echo "seeded. nudging the widgets…"
adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE >/dev/null 2>&1 || true
