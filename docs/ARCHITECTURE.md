# Architecture

Cairn is one Swift package with a single executable target, `Sources/Cairn`. It uses SwiftUI and the Observation framework, and it has no third-party dependencies. The Mac app and the iPhone app compile the same folder. A handful of `#if os(macOS)` blocks cover the parts that only make sense on the Mac: the sync listener, the coach and the menu bar.

## Layers

```
UI/       SwiftUI views. Read the model and call its methods. Persistence and networking live in Model/.
Model/    AppModel plus plain value types and pure functions. Everything testable lives here.
Mac/      @main entry, window, menus, sidebar, and the app icon, which is drawn in code.
Phone/    iPhone root view, tab bar, pairing screen.
```

`AppModel` is the only object views talk to. It is an `@Observable` class that owns a `Store`, and the rest of `Model/` is value types (`struct`, `enum`) and static functions. `Overload`, `Merge`, `Bands` and `GradeScale` are stateless and are tested directly.

## The store

All user data is one `Codable` struct, `Store`: the plan, session logs, per-day logs, skill progress, goals, benchmarks, timeline events, settings and coach reports. It is written as pretty-printed, sorted-key JSON, so the file is readable and diffs cleanly.

Persistence rules, all in `AppModel.save()` and `AppModel.open(profile:)`:

- Writes are atomic.
- The first write of each day copies the existing file to `cairn.backup-YYYY-MM-DD.json`, and only the last 14 backups are kept.
- Decoding is tolerant. Fields added over time are read with `decodeIfPresent` and a default, so older files open in newer builds.
- If a file exists but fails to decode, Cairn copies it aside as `*.unreadable-<timestamp>.json`, runs on an in-memory default store, and refuses to save for the rest of the session. A file it cannot read is never overwritten.

Each profile is a separate file (`cairn.json` for the first, `cairn-<id>.json` for others), with `profiles.json` as the index. Profile ids are `main` or an eight-character hex string.

## The plan and its rules

A `Plan` is 14 week templates (phase, sets, step floors, drill, brief), a list of workouts and a timeline. The timeline is what makes the plan adaptive. It is an ordered list of template numbers, and "repeat this week" or "add a return week" inserts an entry and shifts every later date. Because the plan is data, undoing an adaptation is removing the entry.

Three rule sets sit on top of it:

- **Adaptation** (`AppModel`): judged once per finished week. Missed gym days and sick days are counted, and the result is applied automatically, queued for approval, or ignored, depending on the setting.
- **Scheduling** (`Schedule.swift`): spacing rules such as keeping pull sessions two days clear of a hard climb, carrying a skipped session to the next free day, and proposing a permanent move after the same session is missed in consecutive weeks.
- **Progression** (`Overload.swift`): double progression. Given the logged sets for an exercise it returns one of: start light, progress, stay, fix the load, or back off. Bands move in rungs, so they need the top of the range twice at the same band before moving up.

## Merging two devices

The Mac and the phone each hold a full copy of the store. A sync sends the phone's copy to the Mac, which merges it with its own and returns the result, so after one exchange both hold the same data.

`Merge.swift` makes that safe without a server or a clock-synchronisation protocol:

- Sessions and days are stamped individually with the time of their last change, so a climb logged on the phone and steps imported on the Mac do not collide. For two copies of the same record, the later stamp wins.
- Everything else (plan, settings, goals, skills) is stamped by section, and the newer section replaces the other whole.
- Deleted sessions leave a tombstone, so a delete on one device is not undone by the other device still holding the record.
- A freshly created store carries no stamps, so on a first sync it never overrides real data on the other side.
- Some settings are per machine (the watch folder) and are not merged.

## Sync transport

`PeerSync.swift`. The Mac advertises `_cairn._tcp` with Bonjour on a system-assigned port. The phone browses for it, opens a TCP connection and sends one request: a four-byte big-endian length followed by a JSON `PeerRequest` (pairing code, profile id and name, device name, the whole store). The Mac replies in the same framing with a `PeerResponse`. Frames over 8 MB are refused.

The pairing code is checked by `PairingGuard`, which locks the listener for a minute after five consecutive misses. The limits of this design, and why it is not encrypted, are set out in [SECURITY.md](../SECURITY.md).

## The coach

`CoachRun.swift` runs the `claude` command-line program as a subprocess with a fixed argument list: print mode, no tools, no setting sources, no session persistence, no slash commands, plain-text output. The prompt goes in on standard input. The system prompt asks for one JSON object, and `CoachRunner.parse` extracts it leniently, because models sometimes wrap JSON in a code fence or a line of preamble.

The reply can propose typed adjustments: change a load, change a rep scheme, move a session, repeat a week, add a return week, add a goal. `applyAdjustment` validates each one against the library and sane numeric ranges and records an undo step before changing anything. Nothing is applied without a button press. When the program is missing or signed out, the check-in still runs, using the local rules in `Coach.swift`, and says why Claude was not used.

The test suite exercises this path end to end against a shell script that stands in for `claude`.

## The exercise library

`Library.swift`, `LibraryBands.swift` and `Progressions.swift` hold the exercises, cues, progressions and skill ladders. `LibraryBands.swift` is generated: `Training/tools/data.py` is the source of truth and `Training/tools/gen_swift.py` writes the Swift file and copies the photographs into `ios/Resources/photos`. Edit the Python, not the generated Swift.

## Tests

`SelfTest.swift` and `SelfTestCoach.swift` run inside the app binary with `--selftest`, so they need no test target or Xcode. Each check is a `check(condition, message)` call that prints a line on failure, and the process exits with status 1 if any check fails. A model can be created at a pinned date, which lets the tests walk through the whole 14-week block deterministically.
