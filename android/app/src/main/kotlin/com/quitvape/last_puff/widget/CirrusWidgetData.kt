package com.quitvape.last_puff.widget

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import kotlin.math.max
import org.json.JSONArray
import org.json.JSONObject

/**
 * The contract between the widget and the Flutter app.
 *
 * Both sides read and write `HomeWidgetPreferences` — the SharedPreferences
 * file the `home_widget` plugin owns. We open it by name rather than through
 * the plugin's own classes so that nothing on the tap path depends on a plugin
 * type: `onReceive` runs in a cold process with a ten-second budget, and the
 * highest-value code in this feature should not be breakable by a package
 * upgrade.
 *
 * **Every key has exactly one writer.** Neither SharedPreferences nor
 * UserDefaults offers compare-and-swap, so a key written by both processes is
 * a read-modify-write race and a tap can simply vanish. Splitting ownership
 * removes the race by construction:
 *
 *  - [MIRROR] — Dart writes, we read. Everything the app computed.
 *  - [OUTBOX] — we write, Dart reads. The taps the app has not seen yet.
 *  - [CURSOR] — Dart writes, we read. How far it has taken responsibility.
 *  - [SEQ]    — ours alone. The monotonic minter.
 *
 * Key names and the JSON shape are mirrored in
 * `lib/data/stores/pending_puffs.dart` and `lib/data/stores/widget_mirror.dart`.
 * A rename on one side blanks the widget and throws nothing, so
 * `test/android_widget_test.dart` reads both files and pins them equal.
 */
internal object CirrusKeys {
    const val PREFS = "HomeWidgetPreferences"
    const val MIRROR = "lp.mirror"
    const val OUTBOX = "lp.outbox"
    const val CURSOR = "lp.cursor"
    const val SEQ = "lp.seq"
    const val SCHEMA = 1
    const val TAG = "CirrusWidget"

    /** Well above honest use, and it bounds what one drain can be handed. */
    const val MAX_EVENTS = 1000
}

internal fun Context.cirrusPrefs(): SharedPreferences =
    getSharedPreferences(CirrusKeys.PREFS, Context.MODE_PRIVATE)

/** Today, as the app keys its day map: local midnight, `yyyy-MM-dd`. */
internal fun todayKey(): String = LocalDate.now().toString()

/**
 * What the app last told us about the journey.
 *
 * Nothing here is recomputed natively except the day number and which day's
 * limit applies — everything else would mean a second implementation of the
 * taper curve in Kotlin, and two implementations of the same maths in this
 * repo have already drifted once.
 */
internal data class CirrusMirror(
    val hasJourney: Boolean,
    val dayKey: String,
    val planStartDayKey: String,
    val dayNumber: Int,
    val puffs: Int,
    val limit: Int,
    val streak: Int,
    val flame: String,
    val limits: Map<String, Int>,
    val copyDay: String,
    val copyLeftAhead: String,
    val copyLeftTight: String,
    val copyOverLimit: String,
    val copyEmptyTitle: String,
    val copyEmptyBody: String,
) {
    companion object {
        val absent = CirrusMirror(
            hasJourney = false,
            dayKey = "",
            planStartDayKey = "",
            dayNumber = 0,
            puffs = 0,
            limit = 0,
            streak = 0,
            flame = "🔥",
            limits = emptyMap(),
            copyDay = "",
            copyLeftAhead = "",
            copyLeftTight = "",
            copyOverLimit = "",
            copyEmptyTitle = "",
            copyEmptyBody = "",
        )

        /** Never throws. An unreadable mirror renders as "no journey yet". */
        fun read(prefs: SharedPreferences): CirrusMirror {
            val raw = prefs.getString(CirrusKeys.MIRROR, null) ?: return absent
            return try {
                val json = JSONObject(raw)
                if (json.optInt("v", -1) != CirrusKeys.SCHEMA) return absent
                if (!json.optBoolean("hasJourney", false)) {
                    return absent.copy(
                        copyEmptyTitle = json.optJSONObject("copy")
                            ?.optString("emptyTitle").orEmpty(),
                        copyEmptyBody = json.optJSONObject("copy")
                            ?.optString("emptyBody").orEmpty(),
                    )
                }
                val copy = json.optJSONObject("copy") ?: JSONObject()
                val limitsJson = json.optJSONObject("limits") ?: JSONObject()
                val limits = buildMap {
                    for (key in limitsJson.keys()) put(key, limitsJson.optInt(key, 0))
                }
                CirrusMirror(
                    hasJourney = true,
                    dayKey = json.optString("dayKey"),
                    planStartDayKey = json.optString("planStartDayKey"),
                    dayNumber = json.optInt("dayNumber", 0),
                    puffs = json.optInt("puffs", 0),
                    limit = json.optInt("limit", 0),
                    streak = json.optInt("streak", 0),
                    flame = json.optString("flame", "🔥"),
                    limits = limits,
                    copyDay = copy.optString("day"),
                    copyLeftAhead = copy.optString("leftAhead"),
                    copyLeftTight = copy.optString("leftTight"),
                    copyOverLimit = copy.optString("overLimit"),
                    copyEmptyTitle = copy.optString("emptyTitle"),
                    copyEmptyBody = copy.optString("emptyBody"),
                )
            } catch (error: Throwable) {
                Log.w(CirrusKeys.TAG, "mirror unreadable — showing the empty card", error)
                absent
            }
        }
    }
}

/**
 * Today's numbers as the widget should draw them, mirror plus anything the app
 * has not drained yet.
 */
internal data class CirrusToday(
    val dayNumber: Int,
    val count: Int,
    val limit: Int,
    val left: Int,
    val over: Boolean,
    val knowsLimit: Boolean,
)

/**
 * The taps the app has not applied yet.
 *
 * Deliberately tiny: reading and appending JSON in `org.json`, which is in the
 * framework, so a `+` costs one file read, one parse and one `commit()`. No
 * Flutter engine is started — `home_widget`'s background-callback route would
 * cost 300–800 ms of cold engine start per tap and would land in an isolate
 * with no `JourneyStore` to log against anyway.
 */
internal object CirrusOutbox {

    private val lock = Any()

    /**
     * The event list out of the wrapper document `{"v":1,"e":[…]}`.
     *
     * The wrapper shape is parsed in exactly one place. Anything unreadable —
     * absent, truncated, or from a schema this build does not know — is an
     * empty queue rather than an exception: `onReceive` must never throw, or
     * the launcher shows "Problem loading widget" and the tap is lost anyway.
     */
    private fun events(prefs: SharedPreferences): JSONArray = try {
        val raw = prefs.getString(CirrusKeys.OUTBOX, null)
        if (raw.isNullOrEmpty()) {
            JSONArray()
        } else {
            val json = JSONObject(raw)
            if (json.optInt("v", -1) != CirrusKeys.SCHEMA) JSONArray()
            else json.optJSONArray("e") ?: JSONArray()
        }
    } catch (_: Throwable) {
        JSONArray()
    }

    private fun cursor(prefs: SharedPreferences): Long =
        prefs.getString(CirrusKeys.CURSOR, null)?.toLongOrNull() ?: 0L

    private fun dayOf(epochMillis: Long): String =
        Instant.ofEpochMilli(epochMillis).atZone(ZoneId.systemDefault())
            .toLocalDate().toString()

    /**
     * Net deltas that are still pending AND belong to today.
     *
     * "Still pending" is the load-bearing half: once the app has drained an
     * event it is inside `mirror.puffs`, and counting it here as well would
     * show a number one higher than the user's own record for as long as the
     * queue took to be pruned.
     */
    fun pendingToday(prefs: SharedPreferences): Int {
        val queued = events(prefs)
        val cursor = cursor(prefs)
        val today = todayKey()
        var sum = 0
        for (i in 0 until queued.length()) {
            val event = queued.optJSONObject(i) ?: continue
            if (event.optLong("s", 0L) <= cursor) continue
            val at = event.optLong("t", 0L)
            if (at == 0L || dayOf(at) != today) continue
            sum += event.optInt("d", 0)
        }
        return sum
    }

    /**
     * Appends one tap. Returns the count the widget should now draw, or null
     * when the tap was refused — no journey to log against, a `−` at zero, or
     * a queue that has grown past its ceiling.
     *
     * `commit()` rather than `apply()`: `onReceive` returns and the process
     * becomes killable immediately, and this file is the only record that the
     * user logged anything at all.
     */
    fun append(context: Context, delta: Int): Int? = synchronized(lock) {
        val prefs = context.cirrusPrefs()
        val mirror = CirrusMirror.read(prefs)
        if (!mirror.hasJourney) return null

        val before = todayOf(mirror, pendingToday(prefs))
        val step = if (delta > 0) 1 else -1
        if (step < 0 && before.count <= 0) return null

        val cursor = cursor(prefs)
        val queued = events(prefs)
        val kept = JSONArray()
        for (i in 0 until queued.length()) {
            val event = queued.optJSONObject(i) ?: continue
            // Pruning below the cursor is what stops the queue growing without
            // bound. Only we write this key, so only we may prune it.
            if (event.optLong("s", 0L) <= cursor) continue
            kept.put(event)
        }
        if (kept.length() >= CirrusKeys.MAX_EVENTS) {
            Log.w(CirrusKeys.TAG, "outbox full — refusing the tap")
            return null
        }

        // Never below the cursor, so a queue the app has already drained can
        // never mint a sequence the app would then skip.
        val seq = max(prefs.getLong(CirrusKeys.SEQ, 0L), cursor) + 1
        kept.put(
            JSONObject()
                .put("i", "$seq-${System.nanoTime().toString(16)}")
                .put("s", seq)
                .put("t", System.currentTimeMillis())
                .put("d", step)
        )

        prefs.edit()
            .putString(
                CirrusKeys.OUTBOX,
                JSONObject().put("v", CirrusKeys.SCHEMA).put("e", kept).toString(),
            )
            .putLong(CirrusKeys.SEQ, seq)
            .commit()

        return before.count + step
    }
}

/**
 * Folds the mirror and the pending taps into what the widget draws.
 *
 * The two things computed natively, and why each is safe:
 *
 * * **The day number**, from the plan's start date. Whole calendar days via
 *   `LocalDate.toEpochDay`, never 24-hour arithmetic — the same rule `LpDate`
 *   enforces on the Dart side, and for the same reason: 24 absolute hours
 *   across a DST boundary lands on the wrong date.
 * * **Which day's limit applies**, by looking today up in the mirror's own
 *   seven-day window. The curve is never recomputed here; if today is past the
 *   window the widget says it does not know rather than guessing, which is the
 *   "no invented numbers" rule applied to a surface that cannot do the maths.
 */
internal fun todayOf(mirror: CirrusMirror, pending: Int): CirrusToday {
    val today = todayKey()
    val fresh = mirror.dayKey == today
    val base = if (fresh) mirror.puffs else 0
    val count = max(0, base + pending)

    val limit = mirror.limits[today] ?: if (fresh) mirror.limit else -1
    val knowsLimit = limit >= 0
    // No `limit > 0` clause. `JourneyState.limitOn` returns 0 on the last plan
    // day and on every maintenance day after it, and the app's own
    // `isOverLimit` is a bare `puffs > limit` — so guarding on a positive
    // limit made the widget draw a calm card and a full green bar on exactly
    // the days a single puff puts someone over, while Home showed red.
    val over = knowsLimit && count > limit

    // Both sides of this subtraction are true LOCAL calendar days. It used to
    // take a start expressed as the floored UTC instant of local midnight,
    // which is a day early east of Greenwich and made every positive-offset
    // user's widget read one day ahead of the app.
    val startDay = runCatching { LocalDate.parse(mirror.planStartDayKey).toEpochDay() }
        .getOrNull()
    val dayNumber = if (startDay != null) {
        max(1L, LocalDate.now().toEpochDay() - startDay + 1).toInt()
    } else {
        mirror.dayNumber
    }

    return CirrusToday(
        dayNumber = dayNumber,
        count = count,
        limit = limit,
        left = if (knowsLimit) max(0, limit - count) else 0,
        over = over,
        knowsLimit = knowsLimit,
    )
}
