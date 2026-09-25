# T.N.W.R. — The Naggy Wife Reminder

**A reminder that won't shut up until the job is actually done.**

T.N.W.R. rings at the time you set, then gets **louder and louder** until you
**prove** you did the task. There's no "dismiss" button. The only ways out are
passing the proof challenge or using one of a few snoozes, and every snooze
makes the next ring start louder.

> **Beta.** Windows is the most complete version. See [Platform status](#platform-status).

---

## Contents

- [Features](#features)
- [Platform status](#platform-status)
- [Installing](#installing)
- [How to use it](#how-to-use-it)
  - [Create a reminder](#1-create-a-reminder)
  - [Choose how annoying it is](#2-choose-how-annoying-it-is)
  - [Choose how to prove it's done](#3-choose-how-to-prove-its-done)
  - [When the alarm goes off](#4-when-the-alarm-goes-off)
  - [Managing reminders](#5-managing-reminders)
  - [Light and dark mode](#6-light-and-dark-mode)
- [Sound guide (including hard of hearing)](#sound-guide)
- [Tips and troubleshooting](#tips-and-troubleshooting)
- [Privacy](#privacy)
- [Roadmap](#roadmap)
- [For developers](#for-developers)

---

## Features

- ⏰ **Reminders** that ring once, every day, or on chosen days of the week.
- 📈 **Escalating volume**: starts at the volume you pick and turns itself up
  on a schedule. On Windows it controls the **real system volume**: it unmutes
  your PC and turns the volume back up if you lower it. When you're done, your
  volume goes back to where it was.
- 🔊 **Six alarm sounds**, from a soft chime to "max blast", including
  **low-pitched sounds for people who are hard of hearing**.
- 🔁 **Escalation sound**: switches to a harsher sound if you ignore it too long.
- 💡 **Screen flash**: an optional visual alarm.
- 🧠 **Proof it's done**: solve math problems or type a random phrase before it
  turns off. Require all proofs, or any one of them.
- 😴 **Limited snoozes**: 0–3 per reminder. Each snooze makes the next ring
  start louder.
- 🔒 **Hard to escape (Windows)**: the alarm takes over the whole screen,
  stays on top, ignores the close button and Alt+F4, pulls itself back if you
  switch away, and can't be quit from the tray while ringing.
- 💾 **Survives restarts**: close or kill the app mid-alarm and it picks up
  right where it left off, louder, when it reopens.
- 🌗 **Light, dark, or match-system theme.**
- 🖥️ **Lives in the system tray** on Windows and starts with Windows.

## Platform status

| Platform | Status |
|---|---|
| **Windows** | ✅ Working: everything in the feature list |
| **Android** | 🟡 Works **while the app is open**. Ringing with the app closed is in progress. Volume ramps within the app, not the phone's system volume yet |
| **iPhone** | 🔜 Planned (iOS 26+ alarms that ring through silent mode) |
| **Mac** | 🔜 Planned |
| **Alexa** | 🔜 Planned: your Echo announces the reminder and repeats it until the task is done |

## Installing

### Windows

A ready-to-run download is coming with the first beta release. Until then,
build it from source (see [For developers](#for-developers)) and run
`build\windows\x64\runner\Release\TNWR.exe`.

- The first time you run it, Windows may show **"Windows protected your PC"**
  because the beta isn't code-signed. Click **More info → Run anyway**.
- After the first run of a **release build**, T.N.W.R. starts automatically
  (hidden in the tray) whenever you sign in to Windows, so reminders still fire
  after a reboot.

### Android

Beta testers get an `.apk` file. On the phone, open it and allow
**Install unknown apps** for whichever app you opened it from (Files, Chrome, …).
For now, **keep T.N.W.R. open** for alarms to ring (see Platform status).

---

## How to use it

### 1. Create a reminder

1. Click **New reminder** (bottom-right).
2. **What needs doing?** Give it a name, like "Take out the trash". The
   optional **Notes** show on the alarm screen too.
3. **When**: tap the date/time to pick when it rings.
4. Choose **Once**, **Daily**, or **Weekly**. For weekly, tap the days
   (M T W T F S S) it should repeat on.
5. Set the options below (or leave the defaults) and click **Save**.

### 2. Choose how annoying it is

| Setting | What it does | Range (default) |
|---|---|---|
| **Starting volume** | How loud it is the moment it goes off | 5–100% (30%) |
| **Gets louder every** | How often the volume goes up by 10% | 5–120 seconds (20 s) |
| **Starting sound** | The sound it rings with first. Press ▶ to preview | Six sounds (Classic beep) |
| **Escalation sound** | The sound it switches to if you keep ignoring it | Six sounds (Siren) |
| **Switch after** | How long before it changes to the escalation sound | Immediately–10 min (2 min) |
| **Flash the screen** | Makes the alarm screen flash, for when sound might not be heard | Off |
| **Snoozes allowed** | How many times you can put it off for 5 minutes | 0–3 (1) |

See the [Sound guide](#sound-guide) to pick the right sounds.

### 3. Choose how to prove it's done

Pick at least one:

- **Math problems**: 1–10 problems, Easy / Medium / Hard.
  A wrong answer **resets your count to zero**.
- **Type a random phrase**: 3–20 random words. The phrase can't be copied,
  so you have to type it. Capital letters and extra spaces don't matter.

Then choose **All of these** (every proof must be passed) or **Any one**
(passing one is enough).

*Coming soon: scan a QR code or NFC tag, go to a place, walk a number of
steps, and a photo of the finished task approved by someone you choose.*

### 4. When the alarm goes off

- The alarm **fills the screen** and starts sounding.
- It shows the reminder, how long it's been ringing, and the current volume.
- To turn it off, click a proof (for example **Solve 3 math problems**) and
  complete it. Once enough proofs are passed, the alarm stops and your
  volume goes back to normal.
- **Snooze** (if allowed) silences it for 5 minutes. When it comes back, it
  starts **louder** than before.
- **What doesn't work (on purpose):** the close button, Alt+F4, switching to
  another window (it comes back within about 3 seconds), turning the volume
  down or muting (it turns it back up within a second), and **Quit** in the
  tray menu.
- If the app gets killed, the alarm resumes when T.N.W.R. is opened again, or
  at the next Windows sign-in.

**Repeating reminders** move to their next day automatically after you prove
them done. **One-time reminders** move to the **Done** section.

### 5. Managing reminders

- **Edit**: click a reminder in the list. Saving re-arms it, even if it was done.
- **⋮ menu** on a reminder:
  - **Test: ring in 5 seconds**: try out the sound and proof settings.
  - **Delete**: remove it.
- A reminder can't be edited or deleted **while it's ringing**. Prove it first.
- **Closing the window** hides T.N.W.R. to the **system tray** (near the
  clock). Reminders keep working. Click the tray icon to reopen it.
  Right-click it and choose **Quit** to exit completely (not possible while
  an alarm is ringing).

### 6. Light and dark mode

Click the theme button in the top-right of the main screen and choose
**Match system**, **Light**, or **Dark**. Your choice is remembered.

---

## Sound guide

| Sound | Loudness | Pitch | Good for |
|---|---|---|---|
| Gentle chime | Soft (≈ −20 dB) | High, 1.3–1.8 kHz | Light sleepers, quiet rooms |
| Classic beep | Loud (≈ −4 dB) | High, 1.3–1.8 kHz | Everyday use |
| Siren | Louder (≈ −1 dB) | Sweeps 0.7–1.6 kHz | Escalation |
| 🦻 Low tone 520 Hz | Loud (≈ −4 dB) | Low | **Hard of hearing**: the tone smoke alarms use to wake hard-of-hearing sleepers |
| 🦻 Bass pulse | Louder (≈ −2 dB) | Deep, 200 Hz | **Hard of hearing**, especially severe high-pitch loss |
| 🦻 Max blast | Loudest (≈ 0 dB, the maximum a sound file can hold) | Low, 520–780 Hz, no gaps | Anyone who sleeps through everything |

**Why low sounds for hearing loss?** The most common kind of hearing loss
(from age or noise) affects **high pitches** first. Many people who can't
hear a high beep hear a low, buzzy square-wave tone clearly.

**Suggested setups**

- *Normal hearing:* Classic beep → Siren.
- *Mild hearing loss:* Low tone 520 Hz → Max blast.
- *Severe hearing loss:* Bass pulse → Max blast, **Flash the screen on**,
  starting volume 70–100%, and a loud external speaker.

The dB figures compare the sounds with each other. Actual loudness depends on
your speakers and system volume. For very hard-of-hearing users, a Bluetooth
speaker or a bed shaker helps more than any sound file.

The screen flash runs at one flash per second, below the three-per-second rate
known to trigger photosensitive seizures.

---

## Tips and troubleshooting

| Problem | Fix |
|---|---|
| **"Windows protected your PC"** | Click **More info → Run anyway**. The beta isn't code-signed yet. |
| **No sound on Windows** | Check that a speaker or headphones is the default playback device. T.N.W.R. unmutes and raises the default device only. |
| **Alarm didn't ring after a reboot** | Launch-at-sign-in only turns on after running a **release** build once. Open T.N.W.R. manually once. |
| **Alarm didn't ring on Android** | For now the app must be open (see Platform status). |
| **Want to start fresh** | Quit T.N.W.R. and delete `%APPDATA%\com.nagalarm\T.N.W.R\` (holds `tasks.json` and `settings.json`). |
| **Two copies running** | Only run one copy at a time for now. A duplicate would ring twice. |

## Privacy

Everything stays **on your device**: no account, no internet connection, no
tracking. Reminders and settings are plain files in the app's data folder.
(Future sync between devices and Alexa will be opt-in.)

## Roadmap

- [x] Windows: escalating fullscreen alarm, tray, launch at sign-in
- [x] Sound choices for every hearing level, screen flash, light/dark theme
- [x] Math and typing proofs
- [ ] Android: rings with the app closed, lock-screen alarm, system volume, vibration
- [ ] More proofs: QR / NFC tag, location, step count, photo (on-device check + approval by a chosen person)
- [ ] Sync reminders between phone and PC
- [ ] iPhone (AlarmKit) and Mac
- [ ] Alexa: announce and repeat until done
- [ ] One-click beta downloads

---

## For developers

**Requirements:** Flutter 3.47+ (Dart 3.13). For Windows builds: Visual Studio
2022 Build Tools with **Desktop development with C++**, and Windows
**Developer Mode** on. For Android: Android Studio (SDK) and
`flutter doctor --android-licenses`.

```
flutter pub get
flutter test                      # unit + widget tests
flutter run -d windows            # debug run
flutter build windows --release   # -> build/windows/x64/runner/Release/TNWR.exe
flutter build apk --release       # -> build/app/outputs/flutter-apk/app-release.apk
```

**Sounds** are generated by code, not recorded. To change them, edit
`tools/gen_sounds.py` and run:

```
python tools/gen_sounds.py
```

It prints each file's loudness in dBFS; keep the tiers in
`lib/core/models.dart` (`AlarmSound`, `Loudness`) in step with it.

**Project layout**

```
lib/core/       models, escalation math, scheduling, local storage, settings, branding
lib/alarm/      sound playback, system-volume control, the ringer
lib/proof/      proof challenges (math, typing; others to come)
lib/desktop/    tray icon, fullscreen takeover, launch at sign-in
lib/ui/         screens: reminder list, editor, alarm
windows/runner/ native Windows code: system volume (Core Audio) and
                looping sound playback (PlaySound) in flutter_window.cpp
tools/          sound generator
test/           tests
```

**How it works:** `AppController` checks once a second. Due reminders become
*ringing* and are saved to disk right away, which is why a ringing alarm
survives restarts. While something rings, `escalationAt()` works out the
target volume and sound from how long it has been ringing, and the `Ringer`
applies it. The app name lives in `lib/core/branding.dart`. The native
display names are set in each platform folder.
