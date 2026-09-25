# T.N.D.R. — The Naggy Wife Reminder

A reminder alarm that **gets louder and louder until you prove the task is done.**
No "dismiss" button: the only ways out are completing a proof challenge or using
one of a limited number of snoozes (each one makes the next ring start louder).

Built with Flutter for Windows, Android, iPhone and Mac. Alexa support is planned.

## Status (beta)

| Platform | State |
|---|---|
| Windows | Working: tray app, fullscreen alarm that can't be closed, real system-volume escalation, restores your volume afterwards |
| Android | Runs while the app is open; background alarms (native alarm service) are next |
| iPhone / Mac | Planned (AlarmKit on iOS 26+) |
| Alexa | Planned (spoken repeat reminders through an Alexa-hosted skill) |

## Features

- **Escalation**: starting volume, how often it gets louder, and when it switches
  to a harsher escalation sound. On Windows it raises the real system volume,
  unmutes, and re-raises it if you turn it down.
- **Sounds for every hearing level**, from a soft chime to "max blast":

  | Sound | Loudness | Pitch |
  |---|---|---|
  | Gentle chime | Soft (≈ −20 dB) | High, 1.3–1.8 kHz |
  | Classic beep | Loud (≈ −4 dB) | High, 1.3–1.8 kHz |
  | Siren | Louder (≈ −1 dB) | Sweeps 0.7–1.6 kHz |
  | Low tone 520 Hz 🦻 | Loud (≈ −4 dB) | Low: the fire-alarm wake-up standard for hard-of-hearing sleepers |
  | Bass pulse 🦻 | Louder (≈ −2 dB) | Deep 200 Hz |
  | Max blast 🦻 | Loudest (≈ 0 dB) | Low 520–780 Hz square wave, no gaps |

  🦻 = recommended for hard of hearing. The most common hearing loss affects high
  pitches, so low-pitched square waves are heard far better than high beeps.
  Levels are relative to each other; real loudness depends on the speaker.
- **Flash the screen** as a visual alarm (1 flash/second, below the 3/second
  photosensitivity threshold).
- **Proof it's done**: math problems (a wrong answer resets the count) or typing
  a random phrase (copy/paste blocked). Require all proofs or any one.
  Coming: QR/NFC tag scan, location/steps, photo proof (on-device) and
  photo approval by another person.
- **Light / dark / match-system theme.**

## Building

Requires Flutter 3.47+. On Windows, also Visual Studio 2022 Build Tools
("Desktop development with C++") and Developer Mode.

```
flutter pub get
flutter test
flutter run -d windows
```

Alarm sounds are generated, not recorded: `python tools/gen_sounds.py`.

## Project layout

```
lib/core/       models, escalation math, scheduling, local storage, settings
lib/alarm/      sound playback and system-volume control
lib/proof/      proof challenges (math, typing, ...)
lib/desktop/    tray icon, fullscreen takeover, launch at login
lib/ui/         screens
windows/runner/ native volume + sound code (flutter_window.cpp)
tools/          sound generator
```
