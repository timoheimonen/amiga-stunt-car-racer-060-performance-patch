# WHDLoad install

The patched game, installed to a hard disk and started with
[WHDLoad](https://www.whdload.de/). The intro is not shown; the game starts at
its loading picture. Custom tracks, their records and the season saves are
files in the install directory.

## Requirements

- An Amiga with a 68060, 2 MiB Chip memory and at least 2 MiB Fast memory
- WHDLoad 17 or later

## Install

```sh
python3 patch.py "/path/to/Stunt Car Racer.adf"
```

Creates the install directory `StuntCarRacerPerf` and its drawer icon
`StuntCarRacerPerf.info` beside the original disk image. To write them
elsewhere, name the directory after the disk image, for example
`/path/to/Games/StuntCarRacerPerf`.

`patch.py` accepts only the [supported original disk image](PATCH.md#checksums)
and refuses an existing output directory or drawer icon. It can write directly
to FAT-formatted media. It writes:

| File | Contents |
| --- | --- |
| `StuntCarRacerPerf.slave` | The WHDLoad slave |
| `StuntCarRacerPerf.disk` | The patched game disk image; WHDLoad only reads it |
| `StuntCarRacerPerf.info` | Workbench icon |
| `tracks` | Empty drawer for the Track Editor's files |
| `tracks.info` | Drawer icon of `tracks`; its window lists all files by name |
| `StuntCarRacerPerf.info` next to the directory | Drawer icon of the directory, named after it |

The game's saves are created next to these files (see [Saving](#saving)).

The names differ from those of other WHDLoad installs of the game, which use
`StuntCarRacer.slave`, `StuntCarRacer.info` and `Disk.1`, so the files can
share one directory with such an install; each is started from its own icon.
With `PRELOAD`, WHDLoad preloads every file of the directory, so a shared
directory needs more memory.

Copy the directory and its drawer icon to the Amiga, for example into a
`Games` drawer. Open the drawer and double-click the game's icon, or start
it from a shell:

```sh
cd Games/StuntCarRacerPerf
WHDLoad StuntCarRacerPerf.slave PRELOAD NOWRITECACHE WRITEDELAY=10
```

**F10** quits back to the system (WHDLoad's `QuitKey` option changes it).

## Loading picture

The game's loading picture stays on the screen for 3 seconds; a mouse button,
fire or a key continues at once. With WHDLoad's `ButtonWait` option the
picture stays until the left mouse button or the joystick fire is pressed.
Enable it with the tool type `BUTTONWAIT`, the `ButtonWait` checkbox in
WHDLoad's start window, or `BUTTONWAIT` on the shell command line. The quit
key may not respond while the picture waits.

The slave starts only the disk it was made for. Any other
`StuntCarRacerPerf.disk`, including an unpatched one, ends with WHDLoad's
message that the data files are damaged or an unsupported version.

## Saving

All saves are files in the install directory. The Track Editor's files are
in the drawer `tracks`, which the installer creates:

| Saved by | File |
| --- | --- |
| Track Editor, slot 1..512 | `tracks/Track001.sct` .. `tracks/Track512.sct` |
| Records of a custom track | `tracks/Track001.rec` .. `tracks/Track512.rec` |
| Season save index | `SaveIndex` |
| Season saves 1..30 | `Save01` .. `Save30` |

- Without a file, slots 1-3 hold the tracks BUILD, BUILD 2 and BUILD 3 and the
  other slots are empty. Deleting a track file brings that back.
- The slot is the file name: renaming a track file moves the track to that
  slot. Copy the `tracks` drawer's files between installs under the same names.
- Without the `tracks` drawer, the Track Editor saves nothing and says
  `No tracks drawer. Nothing saved.`; create the drawer and start the game
  again.
- Track files of version 2.2.0 and earlier (`Track01.sct` .. `Track32.sct`,
  `.rec` and `TrackIndex` in the install directory) are not read by the Track
  Editor. Copied into the new install directory, they are imported into
  `tracks` when the game starts; see
  [Tracks from an older version](docs/track-editor.md#tracks-from-an-older-version).
- Season save files keep their names and format between versions: copy them
  from an earlier install into the new one. An install made with version 1.6.0
  used `StuntCarRacer.slave`, `StuntCarRacer.info` and `Disk.1`, but its save
  files have the same names as now.
- Season Load and Save open the list of season saves directly; the game does
  not ask for a save disk. Without season save files, the list is empty.
  A season save file of the wrong size reads as empty; the next save
  replaces it.
- Season Load also records the loaded position in `SaveIndex`, so even
  loading writes to the install directory: keep it on a writable volume.

The icon's tool types are `SLAVE=` the slave, `PRELOAD`, `NOWRITECACHE` and
`WRITEDELAY=10`. With `NOWRITECACHE`, WHDLoad writes every save to the hard
disk at once and then waits `WRITEDELAY` (in fiftieths of a second) so the
file system can finish; the display is blanked during the write.
`WRITEDELAY=10` waits 0.2 seconds instead of WHDLoad's default of 150, that is
3 seconds. A Track Editor save writes one file. On a file
system that finishes its writes later, a reset right after a save may lose
that save; remove `WRITEDELAY=10` or raise its value to wait longer.

Without `NOWRITECACHE`, WHDLoad keeps written files in memory and writes them
to the hard disk only when it quits. Then **leave the game with the quit key**
before switching off or resetting, or the saves of the session are lost.

To change the behaviour, select the icon, choose Information from the
Workbench menu and edit the tool types; a tool type in parentheses is
disabled:

| Tool types | Saving | Display during a save |
| --- | --- | --- |
| `PRELOAD` `NOWRITECACHE` `WRITEDELAY=10` (default) | At once | Blanked for a moment |
| `PRELOAD` `NOWRITECACHE` `(WRITEDELAY=10)` | At once | Blanked for a few seconds |
| `PRELOAD` `(NOWRITECACHE)` | When WHDLoad quits | No noticeable pause |

While the display is blanked, the system has the keyboard: keys pressed
then do not reach the game. A key released then counts as released when the
game continues.

If a write fails, for example on a full or write-protected volume, WHDLoad
ends the game with an error requester.

## How it works

The slave runs the disk image's own boot block on a minimal `exec.library`
and `trackdisk.device`, and that boot code installs the performance runtime,
the Track Editor and the Computer Link module: Chip memory comes from
WHDLoad's base memory, Fast memory from its expansion memory. It skips
the intro, and replaces the floppy driver of the game's loader and of the game
with reads of `StuntCarRacerPerf.disk`. The disk areas of the season saves are
mapped to the files above, and the Track Editor reads and writes its files by
name through the slave. Other writes are refused, so the disk image never
changes. The game's
request for a season save disk is skipped. Technical details:
[Patch details](PATCH.md#whdload-install).
