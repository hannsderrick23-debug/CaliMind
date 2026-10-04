package com.calimind.calimind

import android.Manifest
import android.os.Build
import android.content.pm.PackageManager
import android.content.ActivityNotFoundException
import android.content.Intent
import android.database.Cursor
import android.provider.CalendarContract
import android.content.ContentUris
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CALENDAR_CHANNEL = "com.calimind/device_calendar_read_only"
        private const val CALENDAR_PERMISSION_REQUEST = 7428
        private const val CALENDAR_PERMISSION_PREFERENCES = "calendar_read_permission"
        private const val CALENDAR_PERMISSION_ASKED = "asked"
        private const val MAX_QUERY_DURATION_MILLIS = 26L * 60L * 60L * 1000L
    }

    private var pendingCalendarPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALENDAR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "permissionStatus" -> result.success(
                        mapOf("status" to calendarPermissionStatus())
                    )
                    "requestReadPermission" -> requestReadPermission(result)
                    "getBusyIntervals" -> getBusyIntervals(call.argument<Number>("startMillis")?.toLong(),
                        call.argument<Number>("endMillis")?.toLong(), result)
                    "createEvent" -> createCalendarEvent(
                        call.argument<String>("title"),
                        call.argument<String>("description"),
                        call.argument<Number>("startMillis")?.toLong(),
                        call.argument<Number>("endMillis")?.toLong(),
                        result
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != CALENDAR_PERMISSION_REQUEST) return

        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingCalendarPermissionResult?.success(
            mapOf("status" to if (granted) "granted" else "denied")
        )
        pendingCalendarPermissionResult = null
    }

    private fun requestReadPermission(result: MethodChannel.Result) {
        if (hasReadCalendarPermission()) {
            result.success(mapOf("status" to "granted"))
            return
        }
        if (pendingCalendarPermissionResult != null) {
            result.error("request_in_progress", "A calendar permission request is already active.", null)
            return
        }

        getSharedPreferences(CALENDAR_PERMISSION_PREFERENCES, MODE_PRIVATE)
            .edit()
            .putBoolean(CALENDAR_PERMISSION_ASKED, true)
            .apply()
        pendingCalendarPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.READ_CALENDAR),
            CALENDAR_PERMISSION_REQUEST
        )
    }

    private fun calendarPermissionStatus(): String {
        if (hasReadCalendarPermission()) return "granted"
        val wasAsked = getSharedPreferences(CALENDAR_PERMISSION_PREFERENCES, MODE_PRIVATE)
            .getBoolean(CALENDAR_PERMISSION_ASKED, false)
        return if (wasAsked) "denied" else "notRequested"
    }

    private fun hasReadCalendarPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    private fun getBusyIntervals(
        startMillis: Long?,
        endMillis: Long?,
        result: MethodChannel.Result
    ) {
        if (!hasReadCalendarPermission()) {
            result.success(mapOf("status" to calendarPermissionStatus(), "intervals" to emptyList<Any>()))
            return
        }
        if (startMillis == null || endMillis == null ||
            endMillis <= startMillis || endMillis - startMillis > MAX_QUERY_DURATION_MILLIS
        ) {
            result.error("invalid_range", "Calendar queries must be bounded to one local day.", null)
            return
        }

        val intervals = mutableListOf<Map<String, Long>>()
        var cursor: Cursor? = null
        try {
            val uriBuilder = CalendarContract.Instances.CONTENT_URI.buildUpon()
            ContentUris.appendId(uriBuilder, startMillis)
            ContentUris.appendId(uriBuilder, endMillis)
            cursor = contentResolver.query(
                uriBuilder.build(),
                arrayOf(
                    CalendarContract.Instances.BEGIN,
                    CalendarContract.Instances.END,
                    CalendarContract.Instances.AVAILABILITY
                ),
                null,
                null,
                null
            )

            val beginColumn = cursor?.getColumnIndex(CalendarContract.Instances.BEGIN) ?: -1
            val endColumn = cursor?.getColumnIndex(CalendarContract.Instances.END) ?: -1
            val availabilityColumn =
                cursor?.getColumnIndex(CalendarContract.Instances.AVAILABILITY) ?: -1
            while (cursor?.moveToNext() == true) {
                val begin = cursor.getLong(beginColumn)
                val end = cursor.getLong(endColumn)
                val availability =
                    if (availabilityColumn >= 0 && !cursor.isNull(availabilityColumn)) {
                        cursor.getInt(availabilityColumn)
                    } else {
                        CalendarContract.Events.AVAILABILITY_BUSY
                    }
                if (availability == CalendarContract.Events.AVAILABILITY_FREE) continue

                val clippedStart = maxOf(begin, startMillis)
                val clippedEnd = minOf(end, endMillis)
                if (clippedEnd > clippedStart) {
                    intervals.add(mapOf("startMillis" to clippedStart, "endMillis" to clippedEnd))
                }
            }
            result.success(mapOf("status" to "granted", "intervals" to intervals))
        } catch (exception: Exception) {
            result.error("calendar_read_failed", "Could not read calendar busy times.", null)
        } finally {
            cursor?.close()
        }
    }

    private fun createCalendarEvent(
        title: String?,
        description: String?,
        startMillis: Long?,
        endMillis: Long?,
        result: MethodChannel.Result
    ) {
        if (title.isNullOrBlank() || startMillis == null || endMillis == null ||
            endMillis <= startMillis
        ) {
            result.error("invalid_event", "A title and valid event time are required.", null)
            return
        }

        val intent = Intent(Intent.ACTION_INSERT).apply {
            data = CalendarContract.Events.CONTENT_URI
            putExtra(CalendarContract.Events.TITLE, title)
            putExtra(CalendarContract.Events.DESCRIPTION, description.orEmpty())
            putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMillis)
            putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endMillis)
        }
        try {
            startActivity(Intent.createChooser(intent, "Add event to calendar"))
            result.success(true)
        } catch (exception: ActivityNotFoundException) {
            result.error(
                "calendar_app_unavailable",
                "No calendar app is available on this device.",
                null
            )
        } catch (exception: Exception) {
            result.error("calendar_event_failed", "Could not open a calendar app.", null)
        }
    }
}
