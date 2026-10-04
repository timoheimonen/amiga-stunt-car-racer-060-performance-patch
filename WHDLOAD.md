# WHDLoad install

The patched game, installed to a hard disk and started with
[WHDLoad](https://www.whdload.de/). The game, the Track Editor and the
Computer Link behave as on floppy. The intro is not shown; the game starts at
its loading picture. Custom tracks, their records and the season saves are
files in the install directory instead of disk sectors.

## Requirements

- An Amiga with a 68060, 2 MiB Chip memory and at least 2 MiB Fast memory
- WHDLoad 17 or later

## Install

```sh
python3 patch.py "/path/to/Stunt Car Racer.adf" --whdload
```

Creates the install directory `StuntCarRacerPerf` and its drawer icon
`StuntCarRacerPerf.info` beside the original disk image. To write them
elsewhere, name the directory, for example
`--whdload /path/to/Games/StuntCarRacerPerf`.

`patch.py` accepts only the [supported original disk image](PATCH.md#checksums)
and refuses an existing output directory or drawer icon; `--force` does not
apply to an install. It can write directly to
FAT-formatted media. It writes:

| File | Contents |
| --- | --- |
| `StuntCarRacerPerf.slave` | The WHDLoad slave |
| `StuntCarRacerPerf.disk` | The patched game disk image; WHDLoad only reads it |
| `StuntCarRacerPerf.info` | Workbench icon |
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
WHDLoad StuntCarRacerPerf.slave PRELOAD NOWRITECACHE
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

All saves are files in the install directory:

| Saved by | File |
| --- | --- |
| Track Editor, slot 1..32 | `Track01.sct` .. `Track32.sct` |
| Records of a custom track | `Track01.rec` .. `Track32.rec` |
| Track Editor slot index | `TrackIndex` |
| Season save index | `SaveIndex` |
| Season saves 1..30 | `Save01` .. `Save30` |

- Without a file, a track slot shows what the game disk holds: the BUILD track
  in slot 1 and empty slots otherwise. Deleting a track file brings that back.
- A track file belongs to its slot. A file renamed to another slot number is
  shown as UNREADABLE; move a track by loading it in the Track Editor and
  saving it into another slot. Copy files between installs under the same
  names.
- An install made with version 1.6.0 used `StuntCarRacer.slave`,
  `StuntCarRacer.info` and `Disk.1`. Its save files have the same names as
  now: copy them into the new install.
- If the index does not match the track files, for example after files were
  copied, the Track Editor shows `INDEX RECOVERED FROM RECORDS` and writes a
  new index with the next save.
- The Track Editor's DISK transfer uses a track disk in DF1 and is not
  available under WHDLoad; copy the track files instead.
- Season Load and Save open the list of season saves directly; the game does
  not ask for a save disk. Without season save files, the list is empty.

The icon's tool types are `SLAVE=` the slave, `PRELOAD`, `NOWRITECACHE` and
the disabled `(WRITEDELAY=25)`. With `NOWRITECACHE`, WHDLoad writes every save
to the hard disk at once and then waits `WRITEDELAY` (default 150, that is
3 seconds) so the file system can finish; the display is blanked during the
write. A Track Editor save writes the track and the index.

Without `NOWRITECACHE`, WHDLoad keeps written files in memory and writes them
to the hard disk only when it quits. Then **leave the game with the quit key**
before switching off or resetting, or the saves of the session are lost.

To change the behaviour, select the icon, choose Information from the
Workbench menu and edit the tool types; a tool type in parentheses is
disabled:

| Tool types | Saving | Display during a save |
| --- | --- | --- |
| `PRELOAD` `NOWRITECACHE` (default) | At once | Blanked for a few seconds |
| `PRELOAD` `NOWRITECACHE` `WRITEDELAY=25` | At once | Blanked for a shorter time; a reset right after a save may leave the file incomplete |
| `PRELOAD` `(NOWRITECACHE)` | When WHDLoad quits | No noticeable pause |

If a write fails, for example on a full or write-protected volume, WHDLoad
ends the game with an error requester.

## How it works

The slave runs the disk's own boot block on a minimal `exec.library` and
`trackdisk.device`, so the performance runtime, the Track Editor and the
Computer Link module are installed exactly as from floppy: Chip memory comes
from WHDLoad's base memory, Fast memory from its expansion memory. It skips
the intro, and replaces the floppy driver of the game's loader and of the game
with reads of `StuntCarRacerPerf.disk`. The disk areas the game and the Track Editor write are
mapped to the files above; the Track Editor's two copies of each slot are one
file. Other writes are refused, so the disk image never changes. The game's
request for a season save disk is skipped. Technical details:
[Patch details](PATCH.md#whdload-install).
