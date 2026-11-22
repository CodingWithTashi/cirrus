# Evidence: first mornings on a Pixel 8 (docs/10 §59.7)

Saturday Nov 21 2026, 21:12 to 21:31 EST. Device: Pixel 8 (`shiba`), Android 17, 1080x2400, wireless adb
(`adb-41311FDJH002AM-CFqheC._adb-tls-connect._tcp`), unlocked, on USB power, Do Not Disturb off. Backend:
`LP_BACKEND=fake` (no account, nothing written to production). Cirrus was not installed before the runs;
`flutter test integration_test` installs the debug build and uninstalls it when the run ends. Nothing on the
phone's settings was changed. This is the **Pixel half only**: the iPhone proof and the overnight real-time
acceptance are still pending.

## Results

| Run | Result |
|---|---|
| `integration_test/t_channel_rename_test.dart` (twice; 21:15 and 21:30) | **1/1 passed both times** |
| `integration_test/k_retention_test.dart`, the **whole file** (21:15 to 21:30) | **5/5 passed** |

The five `k_retention` cases, all green: the second notification ask reads the OS and its yes reaches the OS;
a week of evening check-ins sits on the device clock and its switch takes down only its own; a check-in that
fires is a real notification and its tap lands on Home; **a plan-day-2 morning that fires is a real
notification and its tap lands on Home with its slot**; the day-14 offer card and its closable paywall.

## Files

| File | What it is |
|---|---|
| `pixel-k_retention-result.txt` | The runner's lines for the whole-file run (case results, `E2E-MARKER`/`E2E-INFO` lines, exit 0) and the adb driver's log |
| `pixel-t_channel_rename-result.txt` | The same for `t_channel_rename`: both runs and the second run's driver log. The marker line `E2E-MARKER: channel-renamed name=Check-ins` |
| `pixel-morning-dumpsys-record.txt` | `dumpsys notification --noredact`, the 5199 record, taken once it had posted (21:27:59): `channel=evening_checkins`, `android.title` "Day 2", `android.template` BigTextStyle, `android.text` and `android.bigText` both "Today's line is 180 puffs. Log each one as it happens, the first one too.", `effectiveNotificationChannel` named "Check-ins", importance 3 |
| `pixel-morning-dumpsys-channels.txt` | The package's channel section from the same dump: the channel `evening_checkins` named "Check-ins" |
| `pixel-morning-collapsed.png` | The shade row as the shade first showed it, **collapsed**: "Day 2 . now" and one line, "Today's line is 180 puffs. Log each one as i…", cut off mid-word by the collapsed row's one line. A person sees the number and half the action sentence |
| `pixel-morning-expanded.png` | The same row after the chevron: "Cirrus . now", "Day 2", and the whole body in two lines, "Today's line is 180 puffs. Log each one as it / happens, the first one too." |
| `pixel-morning-row-nodes.txt` | The `uiautomator` view nodes of that row in both states (title, time, the body text, the `expand_button`), so the screenshots can be checked against text |
| `pixel-channel-rename-dumpsys-channels.txt` | After the `t_channel_rename` run: the app's section of the dump, `evening_checkins` named "Check-ins", importance 3. (That run had not been granted notifications at all, so the app-level line reads `importance=NONE`; the channel is created regardless, which is what the case relies on) |

The screenshots are **cropped to the Cirrus row**: the shade also held the phone owner's other apps'
notifications, so the full-screen captures and the raw `uiautomator` dumps were not kept in the repository.

## Notes

- The rename itself is observed **inside the device test** (`t_channel_rename_test.dart`): it creates the
  channel as "Evening check-ins", reads it back from the OS, starts a fresh `ReminderScheduler`, and reads it
  back again as "Check-ins" with the importance unchanged. The dumps above are the same state seen from outside the app.
- `adb shell cmd notification list_channels` does not exist on Android 17 ("Unknown command"), so the channel
  evidence is the `dumpsys` section.
- **One hand tap.** The driver's search for the check-in case's row used the title "Day 12", but that
  notification's title is "Day 12 check-in", so the driver reported it missing and did not tap. The row was
  tapped by hand over adb (a `uiautomator` dump for its bounds, then `adb shell input tap`, which is what the
  driver does) at 21:25:24, and the case then passed. That case is not the new morning; the morning case
  (title "Day 2", exact) was found and tapped by the driver itself, and `morning-tapped` printed.
- The notifications fired about a minute after the 70-second schedule (inexact alarm, plus the driver's polling
  of `dumpsys`): the morning was due 21:27:08 and was in the shade by 21:28:05, showing "now".
- The case's own assertions passed on the device: the planned morning is plan day 2, id 5102, a plain morning; the
  5199 notification read back from the OS carries the payload `checkin|morning|2|` with the title and body of the
  planned morning; the tap landed on Home; and exactly one new `reminder_opened` was reported, equal to
  `{kind: checkin, slot: morning, plan_day: 2}`, after a 3-second wait for a second one.
