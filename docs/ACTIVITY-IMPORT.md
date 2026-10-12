# Activity import

Cairn can read bouldering and walking sessions that your watch recorded, so a climbing day ticks itself and a walk counts towards the step floor. The feature is optional. Cairn does not sign in to Garmin or any other service, and it does not include an exporter. It reads a folder that something else filled.

Until you choose a folder, the sidebar shows "Watch not connected" and the import buttons are disabled.

## Connecting a folder

1. Open Settings → **Sync**.
2. Under **Watch activity folder**, press **Choose…** and pick a folder that contains a `manifest.json`.
3. Press **Import now**, or leave **Import automatically** on. Cairn then imports on launch, when you return to the app, and hourly. `⇧⌘S` runs an import from anywhere.

**Disconnect** clears the folder setting. Sessions that were already imported stay in your log.

Cairn only reads. It never writes to, renames or deletes anything in the folder.

## The format

`manifest.json` is a JSON array. Each element is one activity:

```json
[
  { "id": "a-1001", "sport": "bouldering", "startTimeLocal": "2026-10-13T07:10:00", "durationSec": 3600, "avgHr": 131 },
  { "id": "a-1002", "sport": "running",    "startTimeLocal": "2026-10-13T18:00:00", "durationSec": 1800 },
  { "id": "a-1003", "sport": "walking",    "startTimeLocal": "2026-10-14T12:00:00", "durationSec": 2700 }
]
```

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Unique and stable. Cairn remembers imported ids, so re-running an import never duplicates a session. |
| `sport` | string | yes | Case-insensitive. A value containing `boulder` or `climb` becomes a climbing session. A value containing `walk` or `hik` becomes a walk. Anything else is ignored. |
| `startTimeLocal` | string | yes | Local time as `YYYY-MM-DDTHH:MM:SS`. Only the date part is used. |
| `durationSec` | number | no | Session length in seconds. Stored as minutes. |
| `avgHr` | number | no | Average heart rate. |

Other fields are ignored, so a richer export can be pointed at Cairn unchanged as long as these keys are present.

## What the import does

- It looks at activities dated no earlier than seven days before the block starts.
- If you already logged a session of the same kind on that day, the import fills in minutes and heart rate where they are empty and leaves everything else as you typed it. Typed values always win.
- Otherwise it creates a session. A climbing session has no problems logged, so you can add the sends yourself.
- Imported sessions are marked as coming from the watch in the journal.

## Producing the file

Any tool that writes this structure works: a script on a schedule, a shortcut, or a hand-edited file. Keep `id` stable between runs.
