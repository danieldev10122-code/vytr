# Keeping VYTR running

VYTR is signed with a free Apple ID, so iOS stops opening it after seven
days. Re-signing takes about two minutes and keeps all your data.

## The short version

1. Connect the iPhone by USB cable and unlock it
2. Open Sideloadly
3. Drag the newest `dist\VYTR-*.ipa` onto the window
4. Press **Start** and enter your Apple ID password

That is the whole routine. The app knows when it is due: open
**More** in VYTR and read the **This build** card.

## What you do not need

- **A new build.** The same IPA file stays valid forever as a file.
  Sideloadly applies a fresh signature each time. Only the signature
  expires, never the file.
- **An internet connection**, beyond Sideloadly contacting Apple to sign.
- **A new App ID.** Re-signing the same bundle id does not count against
  the limit of 10 App IDs per 7 days.

## What survives, and what does not

| Action | Meals, workouts, reminders | API key |
|---|---|---|
| Re-sign the same app | Kept | Kept |
| Install a newer build over it | Kept | Kept |
| Delete the app from the iPhone | **Lost** | **Lost** |
| Let the signature expire, then re-sign | Kept | Kept |

An expired signature only stops the app launching. Nothing is deleted,
so there is no rush beyond not being able to open it.

**Never delete the app to "fix" it.** That is the one action that throws
the data away. Re-signing over the top is always the answer.

## Avoiding the cable

Sideloadly can refresh apps over Wi-Fi while the phone is on the same
network, which removes the weekly cable step. It is in Sideloadly's own
settings, and it only works while that computer is switched on.

## Getting a fresh build

Only needed when the code has changed.

```powershell
.\scripts\Get-LatestIPA.ps1
```

That downloads the most recent successful build into `dist\` as
`VYTR-<commit>.ipa`. To compile the current source first:

```powershell
.\scripts\Get-LatestIPA.ps1 -Build
```

`-Build` dispatches the workflow, waits for that specific run, and fails
if it does not finish successfully.

Builds run on a macOS runner in GitHub Actions and take under a minute.
They are free because this repository is public.

Old IPAs stay where they are. The script never deletes or overwrites
anything in `dist\`: the download goes to a temporary folder first and
only moves in once it is complete, and if the same build is already
there it says so and leaves the existing file alone. Files therefore
accumulate - delete the ones you no longer want yourself, and keep at
least one known-good IPA to re-sign from.

## When something goes wrong

**"Unable to verify app" on launch**
The signature expired. Re-sign.

**Sideloadly shows `no devices detected`**
The cable is charge-only, or the phone has not trusted this computer.
Use a data cable, unlock the phone, and accept **Trust This Computer**.
Apple Mobile Device Service must be running; it comes with iTunes
installed from apple.com, not from the Microsoft Store.

**Sideloadly reports the App ID limit**
A free Apple ID allows 10 new App IDs per 7 days. Re-signing VYTR does
not consume one, since the bundle id is unchanged. Wait, or use a
different Apple ID.

**The app installs but will not open**
Check **Settings > General > VPN & Device Management** and trust the
developer profile. Developer Mode must also be on, under
**Settings > Privacy & Security**.

## If you ever want the 7 days to become a year

A paid Apple Developer account signs for a year instead of a week.
Nothing in this project changes; only how often you repeat the routine
above.
