# Security

Cairn is a single-user app that stores a training log on your own machine. This page describes what it stores, what can reach the network, and where the limits are.

## Reporting a problem

Use GitHub's private vulnerability reporting: open the **Security** tab of this repository and choose **Report a vulnerability**. Please do not open a public issue for a security problem.

## What Cairn stores

- One JSON file per profile in `~/Library/Application Support/Cairn/`, plus daily backups and, if you use the coach, its snapshots and reports.
- The files are plain text. They hold training data, and optionally body weight, waist, step counts, pain scores and free-text notes. They are not encrypted by Cairn. Turn on FileVault if the disk may be lost or shared.
- No passwords, API keys or tokens are stored. The app has no accounts.
- The source repository contains no credentials. The Apple Developer Team ID and bundle identifier are supplied at build time through environment variables (`CAIRN_TEAM_ID`, `CAIRN_BUNDLE_ID`) and are not committed.

## What can reach a network

Cairn has no HTTP client and makes no internet requests of its own. Two features touch a network:

**iPhone sync (local Wi-Fi, off by default).** The Mac app listens for the iPhone app over TCP and advertises itself with Bonjour (`_cairn._tcp`) under the name "Cairn on <your Mac's name>". The listener only starts after you switch on iPhone sync in Settings → Sync.

**Coach check-in (optional).** When you run a check-in, Cairn starts the `claude` command-line program that you installed and signed in to yourself. It pipes a JSON summary of your recent log to that program's standard input and reads the reply. The call runs with `--tools ""` and `--setting-sources ""`, so the model gets no tools and no local settings or hooks. Cairn removes `ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` from the child process's environment, so a check-in uses your normal sign-in and never an API key that happens to be set in your shell.

The summary contains planned and completed sessions, grades sent, loads, pain and energy scores, step and protein figures, body weight and waist if you entered them, your targets, and the editable "context" text from Settings. It does not contain your name, email address, Mac name or any device identifier. Whatever you write in the context field is sent, so leave out anything you would not want sent. Replies are parsed as data. Suggested changes are validated (known exercise ids, sane ranges for weights, sets and reps) and applied only when you press the button for each one.

## Sync protocol: what it protects and what it does not

The pairing code is six digits, shown on the Mac. The iPhone sends the code with every request, and the Mac answers a correct code with the full merged log.

What is in place:

- The listener is off until you enable it.
- Five wrong codes in a row lock the listener for 60 seconds, which limits a guesser to about five attempts a minute against a million codes. The counter is held in memory and resets when Cairn quits.
- Codes are compared in constant time.
- Profile identifiers received from the phone are checked against a strict allowlist before they are used in a file name, and received profile names are length-limited.
- Messages are length-prefixed and capped at 8 MB. A real log is tens of kilobytes.
- A profile that the phone creates on the Mac is stored with the per-machine settings stripped: the path of the `claude` program and the watch folder. A phone can therefore never choose which program the Mac runs or which folder it reads. Existing profiles are merged through a fixed list of shared settings that excludes both.
- A phone can create at most 20 profiles on the Mac, and the Mac keeps only the newest five pre-merge snapshots of each profile, so a paired device cannot grow the data folder without limit.

What is not in place:

- **The connection is not encrypted.** Anyone who can capture traffic on your Wi-Fi can read the pairing code and the log in transit, and can replay the code. A six-digit code would not make a pre-shared-key TLS handshake safe against an offline guess either, so adding TLS alone would not close this. A proper fix needs a password-authenticated key exchange or certificate pinning at pairing time.
- The Mac reads up to 8 MB from a connection before it checks the code, so a device on the same network can make the Mac briefly hold that much memory.
- A device that keeps sending wrong codes can keep the listener locked and block your own phone from syncing.

For these reasons, use iPhone sync on a network you control, and switch it off when you are on a shared or public network. The rest of the app works without it.

## Other local behaviour

- The coach and the activity import read and write only inside the Cairn data folder and the folder you choose. The import never writes to your watch folder.
- The `claude` path in Settings is run as an executable. It must be an absolute path (a relative one is ignored, so nothing is picked up from the folder Cairn was launched in), and it is only ever set by you in Settings. Set it only to a program you trust.
- `CAIRN_DATA_DIR`, `CAIRN_NOW`, `CAIRN_DEMO` and the other `CAIRN_*` variables are development hooks. They only change where Cairn reads and writes, and have no effect unless set in the environment that launches the app.

## Supported versions

Only the latest commit on `main` receives fixes.
