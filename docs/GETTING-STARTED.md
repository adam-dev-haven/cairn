# Getting started

This guide takes you from a clean Mac to a first logged session, then covers the iPhone app, the optional coach and common problems.

## 1. Install the tools

You need an Apple silicon Mac on macOS 14 or later and the Xcode Command Line Tools. Check whether they are installed:

```bash
swift --version
```

If that prints a version of 5.9 or higher, continue. Otherwise install the tools and run it again:

```bash
xcode-select --install
```

Cairn does not support Intel Macs. `build.sh` builds for `arm64` only.

## 2. Build the Mac app

```bash
git clone https://github.com/adam-dev-haven/cairn.git
cd cairn
./build.sh
open Cairn.app
```

The first build downloads nothing, because Cairn has no package dependencies. It compiles the sources, draws the app icon, assembles `Cairn.app` and signs it ad hoc. To move it to Applications, drag `Cairn.app` there in Finder.

Because you built the app yourself, macOS does not quarantine it and Gatekeeper does not prompt.

## 3. First launch

Cairn opens on the **Today** page with an empty log. It has created a profile named after your macOS account and set the start of the block to the nearest Monday: today if it is a Monday, otherwise the next one. If the block has not started yet, Today shows a short checklist of things to prepare.

Before the first session, open **Settings** and look at three sections:

- **The block** holds the name and start date. The start is always a Monday, and moving it moves the whole plan.
- **Grades** switches between the V scale, the Font scale and your gym's colour circuits. If your gym grades by colour, turn on "My gym grades by colour" and edit each colour's range.
- **Your week** sets which days hold which sessions. The default is two hard climbing days (Monday and Thursday), an optional easy climb on Wednesday, and strength on Tuesday, Wednesday, Friday and Saturday.

Changes save as you make them. Each setting says what it does underneath its label.

## 4. Logging

On **Today**, each planned session is a card. Open one to log it.

- **Climbing:** tap a grade for every send. Mark the tries and technique tags if you want them, and note whether this week's drill felt boring.
- **Strength:** the sets come prefilled from last time. Click a set to tick it, hover for minus and plus, or press "Done as planned".
- **Low day:** "Did the minimum" counts the warm-up and the ladder as a full session. "Skip" records why you skipped.
- **Small things:** steps, a protein tick and an "I'm sick today" box sit beside the session. Sick days do not count as missed.
- **Elbow check-in:** green, amber or red. Amber advises technique work. Red can swap pulling and climbing for prehab, depending on the elbow rule in Settings → Smart scheduling.

`⌘L` opens the logger from anywhere. **This week** shows the seven days and how many points the week has earned. **The mountain** shows the whole block. **Journal** lists every logged session, and any day can be opened and corrected, including past days.

## 5. How the plan changes

Cairn checks the plan each time it opens and each Monday.

- Two or more missed gym days in a week repeat that week, and everything after it slides back seven days.
- Three or more sick days in a week add an easy return week with half the sets.
- Holiday and test weeks never move.

Settings → **Adapting the plan** lets you pick between adjusting automatically, asking first, or leaving the plan alone, and lets you change the thresholds. Every change appears on the timeline and has an undo button.

## 6. Profiles and resetting

Settings → **Profiles** creates a second profile with its own plan, log and settings. Use it for a partner, or to start a fresh block without losing the first one.

Settings → **Reset** offers scoped resets: side quests and missions, benchmarks, sessions and daily logs, plan and timing, or everything in the profile. Each one saves a snapshot first and can be undone.

## 7. The coach (optional)

The coach is a check-in that reads your recent log and suggests small changes. It needs the Claude Code command-line tool, installed and signed in:

1. Install Claude Code from Anthropic's documentation and run `claude` once in Terminal.
2. Type `/login` and finish signing in.
3. In Cairn, open **Coach** and start a check-in.

Cairn looks for the `claude` program in the usual places. If yours is somewhere else, set its path in Settings → **Progression and coach**, where you can also change the model and effort and edit the context text the coach receives. Read [SECURITY.md](../SECURITY.md) for exactly what is sent.

## 8. The iPhone app (optional)

The iPhone app is the same code with a layout built for logging at the gym. It is installed from source and synced through your Mac.

**Install.** You need Xcode and an Apple ID signed in to it (Xcode → Settings → Accounts). A free Apple ID works. Find your Team ID in the same Accounts pane, plug in and unlock the iPhone, then run:

```bash
CAIRN_TEAM_ID=ABCDE12345 ./install-phone.sh
```

Add `CAIRN_BUNDLE_ID=com.yourname.cairn` if you changed the identifier for the Mac build. Bundle identifiers have to be unique per Apple ID, so a free account usually needs its own.

The script builds, signs, installs and opens the app. On first run iOS may ask you to trust the developer: Settings → General → VPN & Device Management.

**Free-account limits.** A free Apple ID signature lasts seven days. Run the same command weekly to renew it. Your data on the phone is kept.

**Pair it with the Mac.**

1. On the Mac, open Settings → Sync and switch on **iPhone sync**. A six-digit pairing code appears.
2. On the iPhone, open **More → Sync with your Mac** and enter the code. Accept the Local Network prompt when iOS asks.
3. Press **Pair**.

After that the phone syncs when you open the app, when you leave it, and on tap, provided the Mac is on the same Wi-Fi with Cairn open. Wi-Fi sync is not encrypted, so read the limits in [SECURITY.md](../SECURITY.md) first and switch it off on networks you do not trust.

To see the phone layout without a phone, run `CAIRN_PHONE=1 Cairn.app/Contents/MacOS/Cairn`, which opens it in a phone-sized Mac window, or build for the simulator with `./build-ios.sh --sim`.

## 9. Importing watch activities (optional)

Cairn can read bouldering and walking sessions from a folder you point it at. The format and an example are in [ACTIVITY-IMPORT.md](ACTIVITY-IMPORT.md). Until you choose a folder, the sidebar shows "Watch not connected" and the import buttons are disabled.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `swift: command not found` | Install the Command Line Tools with `xcode-select --install`. |
| Build fails with an architecture error | The build is Apple silicon only. |
| "Cairn is damaged" or "cannot be opened" after copying the app from another Mac | Quarantine flag. Build on this Mac, or run `xattr -dr com.apple.quarantine Cairn.app`. |
| `install-phone.sh` says "Set CAIRN_TEAM_ID" | Pass your ten-character Team ID, as shown in step 8. |
| `install-phone.sh` says "No iPhone found" | Plug it in, unlock it and tap Trust. |
| The phone says it can't find a Mac | Check that iPhone sync is on, Cairn is open on the Mac, both are on the same Wi-Fi, and Local Network is allowed for Cairn in the iPhone's Settings → Privacy & Security. |
| "Wrong pairing code" | Re-read the code in Settings → Sync on the Mac. Pressing "New code" there invalidates every paired phone. |
| "Too many wrong codes" | Five misses lock the listener for a minute. Wait and try again. |
| The app stopped opening on the iPhone after a week | The free signature expired. Run `install-phone.sh` again. |
| The coach says it cannot find `claude` | Install Claude Code, or set its path in Settings → Progression and coach. |
| The coach says Claude is not signed in | Run `claude` in Terminal and use `/login`. |

If something is still wrong, the log file and its daily backups are in `~/Library/Application Support/Cairn/`. Cairn never overwrites a file it cannot read. It saves a copy beside it and runs without saving until you fix or restore it.
