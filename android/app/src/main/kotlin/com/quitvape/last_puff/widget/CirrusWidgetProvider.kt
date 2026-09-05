package com.quitvape.last_puff.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.quitvape.last_puff.MainActivity
import com.quitvape.last_puff.R
import java.util.Locale
import kotlin.math.roundToInt

/**
 * The Cirrus home-screen widget.
 *
 * Day number on top, today's count below, and one tap to log a puff without
 * opening the app — the whole point, and what the store listing has been
 * promising since launch (docs/08 B21).
 *
 * **How a tap survives a dead app.** The launcher holds our `RemoteViews` and
 * our `PendingIntent`s; both outlive our process. A tap makes the launcher
 * call `PendingIntent.send()`, the system resolves the explicit component,
 * starts our process if it has to, and calls [onReceive] on the main thread
 * with a ten-second budget. We append one JSON event and redraw. No Flutter
 * engine, no Dart, no Firebase — typical cold cost is a few tens of
 * milliseconds. The Flutter app applies the event on its next launch or
 * resume, through the same `JourneyStore.logPuff` the in-app button uses.
 *
 * The one case this cannot survive is a **force-stopped** package: Android
 * adds `FLAG_EXCLUDE_STOPPED_PACKAGES` to every broadcast, so a package the
 * user has force-stopped receives nothing until it is next launched by hand.
 * That is platform behaviour every widget on the device shares. When testing
 * "the app is not running", use `adb shell am kill` — which kills the process
 * without setting the stopped flag — never `am force-stop`.
 */
class CirrusWidgetProvider : AppWidgetProvider() {

    companion object {
        // Mirrored by the <action> entries in AndroidManifest.xml, and
        // test/android_widget_test.dart asserts that every constant here has
        // a filter there — an action the manifest does not route simply never
        // reaches onReceive, silently.
        const val ACTION_PLUS = "com.quitvape.last_puff.widget.PLUS"
        const val ACTION_MINUS = "com.quitvape.last_puff.widget.MINUS"

        /** Below this width the compact layout wins. */
        private const val WIDE_DP = 200
    }

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) = appWidgetIds.forEach { render(context, manager, it) }

    /**
     * Pre-31 reflow. On 31+ the size map in [render] does this without a
     * round trip, but this still fires and re-rendering is idempotent, so it
     * is deliberately not version-gated.
     */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) = render(context, manager, appWidgetId)

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_PLUS, ACTION_MINUS -> {
                val delta = if (intent.action == ACTION_PLUS) 1 else -1
                val now = CirrusOutbox.append(context, delta)
                Log.i(CirrusKeys.TAG, "tap $delta -> ${now ?: "refused"}")
                // Repaint EVERY instance, not just the one that was tapped:
                // two widgets on two home-screen pages must never disagree
                // about the same day's count.
                renderAll(context)
            }
            // Everything else is the framework's — APPWIDGET_UPDATE, _DELETED,
            // _ENABLED, _OPTIONS_CHANGED — and `super.onReceive` is what
            // dispatches those to onUpdate and friends. A `when` that swallows
            // the default branch is how a widget stops updating for ever.
            else -> super.onReceive(context, intent)
        }
    }

    private fun renderAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, CirrusWidgetProvider::class.java)
        )
        ids.forEach { render(context, manager, it) }
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int) {
        try {
            val prefs = context.cirrusPrefs()
            val mirror = CirrusMirror.read(prefs)
            val today = todayOf(mirror, CirrusOutbox.pendingToday(prefs))

            val compact = build(context, R.layout.cirrus_widget_small, mirror, today, id, wide = false)
            val wide = build(context, R.layout.cirrus_widget_wide, mirror, today, id, wide = true)

            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // The system picks the largest entry that fits, so the smallest
                // key has to be small enough for minWidth/minHeight or nothing
                // draws at the size the picker offers.
                RemoteViews(
                    mapOf(
                        SizeF(110f, 110f) to compact,
                        SizeF(WIDE_DP.toFloat(), 110f) to wide,
                    )
                )
            } else {
                val options = manager.getAppWidgetOptions(id)
                val minWidth = options.getInt(
                    AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH,
                    110,
                )
                if (minWidth >= WIDE_DP) wide else compact
            }
            manager.updateAppWidget(id, views)
        } catch (error: Throwable) {
            // A widget that throws here is replaced by the launcher's
            // "Problem loading widget" tile, with the reason only in logcat.
            // Better a stale card than that.
            Log.e(CirrusKeys.TAG, "render failed for widget $id", error)
        }
    }

    /**
     * Builds one layout.
     *
     * **Every setter runs on every path that reaches the active card.** On
     * API 31+ the widget picker inflates the layout directly (`previewLayout`)
     * with no RemoteViews action applied, so any field left unset would render
     * its XML placeholder — "day 12", "52" — as if it were the user's own
     * data. That is the invented-numbers failure wearing the user's
     * handwriting, on their home screen.
     */
    private fun build(
        context: Context,
        layout: Int,
        mirror: CirrusMirror,
        today: CirrusToday,
        id: Int,
        wide: Boolean,
    ): RemoteViews {
        val views = RemoteViews(context.packageName, layout)

        if (!mirror.hasJourney) {
            views.setViewVisibility(R.id.cw_active, View.GONE)
            views.setViewVisibility(R.id.cw_empty, View.VISIBLE)
            views.setTextViewText(
                R.id.cw_empty_title,
                mirror.copyEmptyTitle.ifBlank { context.getString(R.string.cw_empty_title) },
            )
            views.setTextViewText(
                R.id.cw_empty_body,
                mirror.copyEmptyBody.ifBlank { context.getString(R.string.cw_empty_body) },
            )
            views.setInt(R.id.cw_root, "setBackgroundResource", R.drawable.cw_card)
            views.setOnClickPendingIntent(R.id.cw_root, openIntent(context, id))
            return views
        }

        views.setViewVisibility(R.id.cw_active, View.VISIBLE)
        views.setViewVisibility(R.id.cw_empty, View.GONE)

        views.setTextViewText(R.id.cw_day, format(mirror.copyDay, today.dayNumber))
        views.setTextViewText(R.id.cw_flame, mirror.flame)

        views.setTextViewText(R.id.cw_count, today.count.toString())
        views.setTextViewText(R.id.cw_count_over, today.count.toString())
        views.setViewVisibility(R.id.cw_count, if (today.over) View.GONE else View.VISIBLE)
        views.setViewVisibility(R.id.cw_count_over, if (today.over) View.VISIBLE else View.GONE)

        // Two stacked TextViews for one number, because RemoteViews.setColorInt
        // and setColorStateList are API 31 and minSdk here is 24. Swapping
        // visibility is the only way to get a launcher-resolved colour on every
        // supported version.

        views.setTextViewText(
            R.id.cw_of,
            if (today.knowsLimit) "/ ${today.limit}" else "",
        )
        views.setTextViewText(R.id.cw_left, statusLine(mirror, today))
        views.setInt(
            R.id.cw_root,
            "setBackgroundResource",
            if (today.over) R.drawable.cw_card_over else R.drawable.cw_card,
        )

        // `knowsLimit` is `limit >= 0` on purpose — a limit of 0 is a real,
        // knowable limit on the last plan day and every maintenance day after
        // it. But a bar needs something to be a fraction OF, and `0/0` was
        // drawn as 100% full: a user who had logged nothing saw a completely
        // full consumption bar. iOS already gates on `limit > 0`
        // (`CirrusWidget.swift`); this is Android agreeing with it, so the two
        // platforms stop rendering the same mirror differently.
        val showBar = wide && today.knowsLimit && today.limit > 0
        val percent = if (today.limit <= 0) {
            0
        } else {
            ((today.count * 100f) / today.limit).roundToInt().coerceIn(0, 100)
        }
        views.setProgressBar(R.id.cw_bar, 100, percent, false)
        views.setProgressBar(R.id.cw_bar_over, 100, 100, false)
        views.setViewVisibility(
            R.id.cw_bar,
            if (showBar && !today.over) View.VISIBLE else View.GONE,
        )
        views.setViewVisibility(
            R.id.cw_bar_over,
            if (showBar && today.over) View.VISIBLE else View.GONE,
        )

        views.setOnClickPendingIntent(R.id.cw_plus, tapIntent(context, ACTION_PLUS, id))
        views.setContentDescription(R.id.cw_plus, context.getString(R.string.cw_plus_a11y))

        if (today.count > 0) {
            views.setInt(R.id.cw_minus, "setBackgroundResource", R.drawable.cw_btn_minus)
            views.setOnClickPendingIntent(R.id.cw_minus, tapIntent(context, ACTION_MINUS, id))
            views.setContentDescription(R.id.cw_minus, context.getString(R.string.cw_minus_a11y))
        } else {
            // Visibly inert rather than absent, so the primary button does not
            // move under the thumb the moment the count reaches zero. A null
            // PendingIntent clears the click.
            views.setInt(R.id.cw_minus, "setBackgroundResource", R.drawable.cw_btn_minus_off)
            views.setOnClickPendingIntent(R.id.cw_minus, null)
            views.setContentDescription(R.id.cw_minus, context.getString(R.string.cw_minus_off_a11y))
        }

        // The card opens the app. The two buttons consume their own taps, so
        // this never fires from them.
        views.setOnClickPendingIntent(R.id.cw_root, openIntent(context, id))
        return views
    }

    /**
     * The one line of copy the widget composes itself, following exactly the
     * rule Home already uses (`home_screen.dart`: over / comfortably under /
     * tight), so the two surfaces can never contradict each other.
     *
     * The templates arrive pre-localized from Dart carrying a `%1$d`, because
     * the count is a value the widget changes on its own — a tap while the app
     * is dead, or a midnight rollover — and it has to be formatted on this side
     * of the process boundary. Formatting rather than concatenating is what
     * keeps word order per-locale: German wants "noch 46", not "46 noch".
     */
    private fun statusLine(mirror: CirrusMirror, today: CirrusToday): String = when {
        !today.knowsLimit -> ""
        today.over -> mirror.copyOverLimit
        today.left > today.limit * 0.25 -> format(mirror.copyLeftAhead, today.left)
        else -> format(mirror.copyLeftTight, today.left)
    }

    private fun format(template: String, value: Int): String = try {
        if (template.isBlank()) "" else String.format(Locale.getDefault(), template, value)
    } catch (_: Throwable) {
        // A template whose placeholder a translator dropped must not take the
        // widget down with it.
        ""
    }

    /**
     * One PendingIntent per (widget instance × action).
     *
     * The bug this avoids: PendingIntents are deduplicated by
     * `Intent.filterEquals` plus the request code, and `filterEquals` compares
     * action, data, type, package, component and categories — it does **not**
     * compare extras. So the obvious version, with a shared request code and
     * the widget id only in an extra, hands back the *same* object for every
     * widget on the home screen, and `FLAG_UPDATE_CURRENT` then overwrites its
     * extras with the newest id. Add a second Cirrus widget and the first one's
     * buttons start reporting the second one's id. Invisible with one widget
     * placed, which is how it ships.
     *
     * Two independent fixes, both applied: a distinct request code per
     * (id, action), and the id in the data Uri, which `filterEquals` does
     * compare.
     *
     * `FLAG_IMMUTABLE` is not optional — since API 31 a PendingIntent built
     * without MUTABLE or IMMUTABLE throws at construction, which here would be
     * inside onUpdate, and the widget would never draw at all.
     */
    private fun tapIntent(context: Context, action: String, id: Int): PendingIntent {
        val slot = if (action == ACTION_PLUS) 0 else 1
        val intent = Intent(context, CirrusWidgetProvider::class.java).apply {
            this.action = action
            data = Uri.parse("cirrus://widget/$id/$slot")
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
        }
        return PendingIntent.getBroadcast(
            context,
            id * 4 + slot,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * Opens the app. An explicit component, so `MainActivity` needs no new
     * intent-filter — and deliberately no deep link: `flutter_deeplinking_enabled`
     * is false and go_router owns routing, so the Uri here exists only to keep
     * this PendingIntent distinct from the two button ones.
     */
    private fun openIntent(context: Context, id: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            data = Uri.parse("cirrus://widget/$id/open")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            id * 4 + 2,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
