# Backup and restore

More → Backup saves everything VYTR holds into one file, and reads that
file back. It exists because the only other route was an encrypted
iPhone backup, which takes the whole phone and gives it back the same
way.

## The file

`VYTR-backup-2026-10-16.zip` — an ordinary zip, openable on the iPhone,
on a Mac and on Windows with nothing installed:

```
manifest.json      every meal, workout and reminder, as plain JSON
photos/0001.jpg    the meal photos, byte for byte as stored
photos/0002.jpg
```

Photos are why a single JSON file was not enough. Keeping them as real
JPEGs beside the manifest, instead of base64 inside it, means the backup
can be opened and the pictures simply looked at.

It is **not encrypted**. Keep it where private files are kept.

### Why the zip is hand-written

iOS can create a zip (through `NSFileCoordinator`) but offers no API to
read one back, and no third-party libraries are allowed in this project.
`VYTR/Services/Backup/ZipArchive.swift` therefore writes and reads the
one subset the backup needs: stored (uncompressed) entries. The payload
is JPEG, which does not compress, so nothing is lost by skipping
deflate — and the CRC-32 that zip records for every entry is written and
checked, which is what turns a truncated or damaged file into a clear
message instead of nonsense.

## How import decides what is already there

The models have no id of their own. Adding one would be a SwiftData
schema migration, and the meals already on the phone are not worth that
risk, so identity is derived from the content instead:

| Entry    | Counts as the same when these match                          |
|----------|--------------------------------------------------------------|
| Meal     | name, the second it was eaten, both calorie bounds            |
| Workout  | name, the second it is scheduled for                          |
| Reminder | title, hour, minute, chosen days                              |

Names are compared trimmed and case-insensitively. Times are compared to
the whole second, which is also the resolution the file stores, so a
backup re-imported into the store it came from adds nothing.

A workout's exercises travel with the workout and are never merged on
their own.

The worst case of this rule is a duplicate — two genuinely different
meals logged at the same second with the same name and calories would be
merged, and a meal whose name was edited after the backup comes back as
a second row. Both are visible and deletable. Nothing is ever lost or
silently changed, which is the trade being made.

## What import does

1. Pick a file. It is read and checked before anything is written.
2. A sheet states exactly how many meals, workouts and reminders would be
   added, and how many are already here.
3. Only on confirming does anything change.

Import **adds**. It never deletes, never overwrites an existing entry,
and never wipes the store. An entry edited on the phone after the backup
was made keeps the edit. Running the same import twice changes nothing
the second time.

Afterwards the notification schedule is rebuilt from the store, so
imported reminders and workouts actually fire.

## When it goes wrong

A file that is not a zip, is cut short, is damaged, holds another app's
manifest, was written by a newer VYTR, or refers to a photo that is not
inside it, produces a plain message on screen and no change to the data.
`VYTRTests/BackupTests.swift` covers each of those cases.
