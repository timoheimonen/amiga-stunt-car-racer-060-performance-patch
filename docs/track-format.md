# Track File Format

For Stunt Car Racer Performance version 2.3.2.

This document describes the files in which the game keeps custom tracks and their lap
records: their bytes, the track model they hold and the rules the game applies when it reads
them. It gives everything needed to read, check and write the files outside the game.

Contents:

1. [Conventions](#1-conventions)
2. [Files in the tracks drawer](#2-files-in-the-tracks-drawer)
3. [IFF container](#3-iff-container)
4. [Track file: FORM SCTF](#4-track-file-form-sctf)
5. [Track geometry](#5-track-geometry)
6. [Draft, Closed and Ready](#6-draft-closed-and-ready)
7. [Records file: FORM SCTT](#7-records-file-form-sctt)
8. [How the game treats each file](#8-how-the-game-treats-each-file)
9. [Conventions of the game's editor](#9-conventions-of-the-games-editor)
10. [Example track file](#10-example-track-file)
11. [Appendix A: shapes](#appendix-a-shapes)
12. [Appendix B: piece kinds](#appendix-b-piece-kinds)

## 1. Conventions

- Every number of more than one byte is **big-endian**: the most significant byte comes
  first. Numbers are unsigned unless a field says signed.
- A *word* is 2 bytes and a *long* 4 bytes. Offsets are in bytes from the start of the
  structure they are given for, in decimal unless written `0x`.
- Text is ASCII. *Printable* means a byte from 32 (space) to 126 (`~`).
- Four-character identifiers such as `FORM` or `CRC ` are their four ASCII bytes. `CRC ` ends
  with a space (32).
- **CRC-32** is the CRC of ZIP, PNG and zlib: polynomial `0x04C11DB7` in reflected form
  (`0xEDB88320`), initial value `0xFFFFFFFF`, input and output reflected, final XOR
  `0xFFFFFFFF`. The CRC-32 of the nine ASCII bytes `123456789` is `0xCBF43926`. A CRC is
  stored as a big-endian long.
- *Must* states a rule the game checks; a file that breaks it is refused as described in
  [section 8](#8-how-the-game-treats-each-file).

## 2. Files in the tracks drawer

The game keeps custom tracks in the `tracks` drawer of its WHDLoad install
(`StuntCarRacerPerf/tracks`). The drawer holds one file per slot and nothing else is
needed:

| File | Contents |
| --- | --- |
| `tracks/TrackNNN.sct` | The track of slot NNN, a `FORM SCTF` ([section 4](#4-track-file-form-sctf)). |
| `tracks/TrackNNN.rec` | The lap and race records of slot NNN, a `FORM SCTT` ([section 7](#7-records-file-form-sctt)). |
| `tracks/Imported` | A marker: the question about importing tracks of an older version has been answered. |

- There are **512 slots**. NNN is the slot number in three digits with leading zeros, `001`
  to `512`. The slot is the file name: renaming `Track007.sct` to `Track020.sct` moves the
  track to slot 20, and the records follow when `Track007.rec` is renamed the same way.
- Write the names as shown. The game opens a slot's files by these names, and when it lists
  the drawer it recognises them without regard to case. Every other name is ignored, for
  example `Track000.sct`, `Track513.sct`, `Track1.sct`, `Track0001.sct` or
  `Track001.sct.bak`. Drawers inside `tracks` are ignored.
- A file is at most **4096 bytes**. The game does not read a larger file and does not write
  one.
- A file of 0 bytes counts as no file.
- Slots 1, 2 and 3 show the tracks that come with the game (**BUILD**, **BUILD 2** and
  **BUILD 3**) while the slot has no file. A file in the slot takes their place, and deleting
  the file brings the track back. These tracks are part of the game, not files in the
  drawer.
- Without the `tracks` drawer the game saves nothing and shows only the tracks that come
  with it. The game looks for the drawer once per session.
- The game lists the drawer once per session, when a track list is first opened, and updates
  its list when it saves. A file changed by another program while the game runs is seen after
  the next start.
- `tracks/Imported` counts when it is not empty. Its contents do not matter; the game writes
  one line of text. The game asks about the import only when the install directory holds
  track files of an older version.

Versions 1.6.0 to 2.2.0 kept tracks in another format (`TrackNN.sct`, `TrackNN.rec` and
`TrackIndex` in the install directory). That format is not described here: the game converts
such files with its import, as the Track Editor manual explains.

## 3. IFF container

Both kinds of file are IFF files (EA IFF 85) of one `FORM`, with a CRC chunk at the end:

| Offset | Size | Contents |
| ---: | ---: | --- |
| 0 | 4 | `FORM` |
| 4 | 4 | Length of the rest of the file: file size - 8. |
| 8 | 4 | Form type: `SCTF` (track) or `SCTT` (records). |
| 12 | ... | Chunks, one after the other. |

A chunk:

| Offset | Size | Contents |
| ---: | ---: | --- |
| 0 | 4 | Chunk ID. |
| 4 | 4 | Data length *n*, without the pad byte. |
| 8 | *n* | Data. |
| 8 + *n* | 0 or 1 | A pad byte when *n* is odd, so that the next chunk starts at an even offset. The game writes 0 and does not check it. |

The last chunk is `CRC `, *n* = 4. Its data is the CRC-32 of every byte of the file before
the `CRC ` chunk, from offset 0 to the last byte before the ID `CRC `.

The game accepts a file only when all of these hold:

1. The file is 24 to 4096 bytes.
2. It starts with `FORM`, and the form type is the expected one.
3. The long at offset 4 plus 8 is the file size exactly. Nothing follows the `FORM`.
4. Walking the chunks from offset 12, each chunk fits: its 8-byte header lies within the
   file, *n* is not larger than the file size, and its data and pad byte end within the file.
5. The first chunk with the ID `CRC ` has *n* = 4, ends exactly at the end of the file and
   holds the right CRC-32. No chunk can follow it.

The container does not check chunk IDs. The IDs this format uses are `TRAK`, `STAT`, `RKEY`,
`NORM`, `SUPR` and `CRC `. A chunk with another ID is an *unknown chunk*: the game skips it
when it reads and keeps it when it writes the file again ([section 4](#4-track-file-form-sctf)
and [section 7](#7-records-file-form-sctt)). A chunk added to the format by a later version
of the game gets an ID of its own, and a change that alters how a track drives gets a new
version of the track model instead ([4.2](#42-trak-the-track-model)).

## 4. Track file: FORM SCTF

### 4.1 Chunks

| Chunk | Count | Contents |
| --- | --- | --- |
| `TRAK` | exactly 1 | The track model, SCTR version 1 ([4.2](#42-trak-the-track-model)). |
| `STAT` | 0 or 1 | The stored class of the track ([4.4](#44-stat-the-stored-class)). |
| any other | any | Unknown chunks, kept by the game. |
| `CRC ` | 1, last | CRC-32 of the file before it ([section 3](#3-iff-container)). |

A file with two or more `TRAK` or `STAT` chunks is damaged. The chunks before `CRC ` may come
in any order. The game writes them as `TRAK`, `STAT`, the unknown chunks of the track it
loaded in their order, and `CRC `.

The smallest file the game writes is 124 bytes (one piece). Without unknown chunks the
largest is 740 bytes (78 pieces).

### 4.2 TRAK: the track model

The `TRAK` data is one SCTR block, and the chunk length is the block's size.

| Offset | Size | Field | Values |
| ---: | ---: | --- | --- |
| 0 | 4 | Magic | `SCTR` |
| 4 | 2 | SCTR version | 1 |
| 6 | 2 | Size | 68 + 8 × piece count, the whole block with its CRC (76 to 692). The `TRAK` length must be the same. |
| 8 | 16 | Track ID | Any 16 bytes except all zero ([section 9](#9-conventions-of-the-games-editor)). |
| 24 | 4 | Geometry revision | 1, 2 or 3 ([5.5](#55-geometry-revisions)). New tracks are 3. |
| 28 | 2 | Piece count | 1 to 78. |
| 30 | 2 | Flags | 0 open, 1 closed ([5.4](#54-joins-open-and-closed)). |
| 32 | 2 | Initial height | 0 to 32767: the height where the first piece starts ([5.3](#53-heights)). |
| 34 | 2 | Reserved | 0 |
| 36 | 4 | Finish piece ID | The ID of one piece of the track, which must be of kind 1. |
| 40 | 24 | Name | 1 to 24 printable characters, then zero bytes to the end of the field. The first byte is not zero, and no printable byte follows a zero byte. |
| 64 | 8 × count | Pieces | [4.3](#43-piece-entry), in driving order. |
| size - 4 | 4 | CRC-32 | Of the block's bytes 0 to size - 5. |

The game reads the block in this order:

1. The `TRAK` data is at least 6 bytes and starts with `SCTR`; otherwise the file is damaged.
2. An SCTR version above 1 needs a newer version of the game: the list shows the slot as
   `NEWER VERSION`, and the game neither loads the file nor saves over it. Version 0 is
   damaged.
3. The `TRAK` length is 76 to 692 and equals the size field; otherwise the file is damaged.
4. When the game loads the track, or classifies it without a valid `STAT`, it checks the
   whole model ([5.6](#56-rules-for-a-valid-track)).

The game shows lower case letters of a name in upper case.

### 4.3 Piece entry

| Offset | Size | Field | Values |
| ---: | ---: | --- | --- |
| 0 | 4 | Piece ID | Not 0, and different from every other piece ID of the track. |
| 4 | 1 | Kind | 1 to 116 ([Appendix B](#appendix-b-piece-kinds)). |
| 5 | 1 | Rotation | 0 to 3 quarter turns ([5.2](#52-placing-a-piece)). |
| 6 | 1 | Reverse | 0 forward, 1 reverse. Kinds 8 to 116 must have the value given in Appendix B. |
| 7 | 1 | Cell | Map cell: X in bits 0-3, Z in bits 4-7 (`0x47` is X 7, Z 4). |

Pieces follow each other in the order the car drives. The race starts and ends on the finish
piece.

### 4.4 STAT: the stored class

| Offset | Size | Field | Values |
| ---: | ---: | --- | --- |
| 0 | 2 | Class | 1 not Ready (Draft or Closed), 2 Ready ([section 6](#6-draft-closed-and-ready)). |
| 2 | 2 | Rules version | 3 |
| 4 | 4 | TRAK CRC | The last 4 bytes of the `TRAK` data, the SCTR block's CRC. |

`STAT` spares the game from checking every track when it lists 512 slots. The game uses it
only when the data is at least 8 bytes, the class is 1 or 2, the rules version is 3 and the
TRAK CRC equals the CRC of the `TRAK` chunk. Otherwise it ignores `STAT` and classifies the
track itself; the file is not damaged. The game writes 8 bytes.

The class in `STAT` is used only for the track lists. Before a track is edited or driven, the
game checks it again, so a wrong `STAT` cannot let a track that is not Ready be driven. A
program that does not classify tracks exactly as [section 6](#6-draft-closed-and-ready)
describes leaves `STAT` out. A later version with other rules uses another rules version, and
the game then classifies each track again.

## 5. Track geometry

### 5.1 Coordinates

The map is 16 × 16 cells of 2048 × 2048 units. X and Z are the plan coordinates, from 0 to
32768 inclusive; cell (X *cx*, Z *cz*) covers X 2048·*cx* to 2048·(*cx* + 1) and Z
2048·*cz* to 2048·(*cz* + 1). Y is the height, 0 to 32767, larger values higher.

Each piece is a strip of road given as **rows**: cross sections in driving order. A row has
two points, the *first edge* and the *second edge* of the road, each with X, Y and Z. A piece
of *r* rows has *r* - 1 **segments**, the road between two rows.

### 5.2 Placing a piece

Each kind has a shape ([Appendix A](#appendix-a-shapes)): its rows as local X and Z for
rotation 0 and the forward direction. Local values may lie a little outside 0 to 2048.
The world X and Z of a piece:

1. Take the rows of the kind's shape. When Reverse is 1, take the rows in the opposite order
   and swap the two points of every row.
2. Turn each point (*x*, *z*) by the rotation:

   | Rotation | Point |
   | :---: | --- |
   | 0 | (*x*, *z*) |
   | 1 | (*z*, 2048 - *x*) |
   | 2 | (2048 - *x*, 2048 - *z*) |
   | 3 | (2048 - *z*, *x*) |

3. Add the cell: X = *x* + 2048·*cx*, Z = *z* + 2048·*cz*.

Every point must have X and Z from 0 to 32768.

### 5.3 Heights

Each piece has a *base height*. The first piece's base is the initial height. The base of
every other piece is the Y of the first edge in the last row of the piece before it.

Appendix B gives each kind two lists of heights, one per edge, in the order of the rows as
the car drives them (after step 1 above). Row *i* of a piece has first edge Y = base + *H1*[*i*]
and second edge Y = base + *H2*[*i*]. Every Y must be from 0 to 32767.

Kinds 1 to 7 have a row of heights for each Reverse value. In revision 1, kinds 2 and 3 have
all heights 0 ([5.5](#55-geometry-revisions)).

### 5.4 Joins, open and closed

Two rows **join** when their first edges and their second edges are each within 1 unit in X
and in Z and at the same Y. The 1 unit allows for small seams in the game's own road data.

- The last row of every piece must join the first row of the next piece. As each piece starts
  from the height where the one before it ended, and every *H1* list starts at 0, this comes
  down to the X and Z of both edges and to the second edge: the next piece's *H2*[0] must equal
  *H2* - *H1* of the last row of the piece before it.
- The track is **closed** when the last row of the last piece joins the first row of the
  first piece, with the same rule and the absolute heights. Flags must be 1 for a closed
  track and 0 for an open one.

### 5.5 Geometry revisions

| Revision | Kinds allowed | Notes |
| :---: | --- | --- |
| 1 | 1 to 7 | Kinds 2 and 3 are flat (all heights 0). The track is always Draft. |
| 2 | 1 to 7 | Kinds 2 and 3 are banked as in Appendix B. |
| 3 | 1 and 4 to 116 | Kinds 2 and 3 are not allowed. Kinds 8 to 116 exist only in this revision. |

The game's editor makes revision 3 tracks.

### 5.6 Rules for a valid track

The game loads a track only when its `TRAK` block meets all of these:

- The header fields have the values of [4.2](#42-trak-the-track-model): magic, version 1,
  size, a track ID that is not all zero, revision 1 to 3, 1 to 78 pieces, flags 0 or 1,
  initial height 0 to 32767, reserved 0, the name rule and the CRC-32.
- Every piece ID is not 0 and is unique. Exactly one piece has the finish piece ID, and it is
  of kind 1.
- Every kind is 1 to 116 and allowed in the track's revision ([5.5](#55-geometry-revisions)).
  Rotation is 0 to 3. Reverse is 0 or 1, and for kinds 8 to 116 the value of Appendix B.
- Every point lies on the map ([5.2](#52-placing-a-piece)) and every Y is 0 to 32767
  ([5.3](#53-heights)).
- Every piece joins the next one, and the flags match whether the track is closed
  ([5.4](#54-joins-open-and-closed)).

## 6. Draft, Closed and Ready

A valid track is **Draft**, **Closed** or **Ready**. Only a Ready track can be driven. The
game decides in this order:

1. Revision 1: Draft.
2. Open (flags 0): Draft.
3. Fewer than 8 pieces, or fewer than 64 segments in all: Closed (the road is too short).
4. A point with Y of 512 or less: Closed (the road is below the base of the side walls).
5. Two pieces overlap ([6.1](#61-road-overlap)): Closed.
6. Otherwise Ready.

`STAT` stores Ready as 2 and Draft and Closed as 1.

A track can be driven with at most 32 pieces whose kind has *no* in the Crane column of
Appendix B. Those pieces lie over a jump, where the crane that lifts a car back onto the road
does not set it down.

### 6.1 Road overlap

The road of a piece is made of one quadrilateral per segment. In plan (X and Z only), the
quadrilateral between rows *i* and *i* + 1 has the corners first edge *i*, second edge *i*,
second edge *i* + 1 and first edge *i* + 1, in this order. Heights do not count: a road that
passes above another overlaps it.

Two pieces overlap when a quadrilateral of one overlaps a quadrilateral of the other. Every
pair of pieces is tested, neighbours included. Quadrilaterals *A* and *B* overlap when both
tests pass:

1. Their bounding boxes overlap by more than 2 units: min(max X of *A*, max X of *B*) >
   max(min X of *A*, min X of *B*) + 2, and the same for Z.
2. No edge of *A* or *B* separates them. For an edge from (*x1*, *z1*) to (*x2*, *z2*), take
   *nx* = *z2* - *z1* and *nz* = *x1* - *x2*, and project the corners of both quadrilaterals:
   *p* = *x*·*nx* + *z*·*nz*. The edge separates them when min(max *p* of *A*, max *p* of *B*)
   - max(min *p* of *A*, min *p* of *B*) ≤ 2·(|*nx*| + |*nz*|).

The 2-unit margins let neighbouring pieces touch along their joins.

## 7. Records file: FORM SCTT

`TrackNNN.rec` holds the best times of the track in slot NNN.

### 7.1 Chunks

| Chunk | Count | Contents |
| --- | --- | --- |
| `RKEY` | exactly 1 | Policy and track key, 348 bytes ([7.2](#72-rkey-policy-and-track-key)). |
| `NORM` | exactly 1 | Times of the Normal league, 32 bytes ([7.3](#73-norm-and-supr-times)). |
| `SUPR` | exactly 1 | Times of the Super league, 32 bytes. |
| any other | any | Unknown chunks, kept while the file belongs to the track. |
| `CRC ` | 1, last | CRC-32 of the file before it ([section 3](#3-iff-container)). |

A file with another number of `RKEY`, `NORM` or `SUPR` chunks, or another length for any of
them, is damaged. The game writes `RKEY`, `NORM`, `SUPR` and `CRC `: 460 bytes.

### 7.2 RKEY: policy and track key

| Offset | Size | Field | Values |
| ---: | ---: | --- | --- |
| 0 | 2 | Policy | 1 |
| 2 | 2 | Reserved | 0 |
| 4 | 344 | Track key | See below. |

Policy 1 means times set with Game Speed 100%, Infinite Boost No, Disable Damage No and
Timing Performance; the game keeps records only with these settings. A file of another
policy is treated as damaged.

The track key identifies the track and its exact shape:

| Offset | Size | Field |
| ---: | ---: | --- |
| 0 | 16 | Track ID (`TRAK` offset 8). |
| 16 | 4 | Geometry revision. |
| 20 | 2 | Piece count. |
| 22 | 2 | Initial height. |
| 24 | 2 | Finish index: the position of the finish piece in the piece list, 0 for the first. |
| 26 | 6 | Zero. |
| 32 | 4 × count | For each piece in order: kind, rotation, reverse and cell (bytes 4-7 of its entry). |
| 32 + 4 × count | rest | Zero, up to 344 bytes. |

The name and the piece IDs are not in the key: renaming a track keeps its records, and
changing its shape starts fresh times.

### 7.3 NORM and SUPR: times

Each is 32 bytes: entry 0 is the best lap, entry 1 the best race time. A race time counts only
when the player wins the race against the computer driver.

| Offset | Size | Field | Values |
| ---: | ---: | --- | --- |
| 0 | 12 | Driver name | Each byte 0 or printable. |
| 12 | 1 | Minutes | 0 to 9 |
| 13 | 1 | Seconds | BCD `0x00` to `0x59` |
| 14 | 1 | Hundredths | BCD `0x00` to `0x99` |
| 15 | 1 | Reserved | 0 |

In BCD each 4 bits hold one decimal digit: `0x45` is 45. An entry without a time has the name
`------------` (12 × `-`) and the time 9:00.00 (`09 00 00 00`). A time outside these values
makes the file damaged.

### 7.4 How the game uses the file

- Before a drive that can set records, the game reads `TrackNNN.rec` of the track's slot and
  builds the track key from the track.
- Without the file, or with a file of another key, the drive starts from the times of the
  session, which are empty at first. When the drive sets a record, the game writes a new file
  in place of the old one.
- With a file of the same key, the drive starts from its times. When a record is set, the game
  writes the file back with the new times of that league, the other league as it was, the
  unknown chunks as they were, and a new CRC.
- A damaged file, or one larger than 4096 bytes, is left as it is. The game tells the player
  `Records error: Retry`, and times of that drive are kept only for the session.
- The game writes the file when the player goes back to the menus, not while driving.

## 8. How the game treats each file

| File in the slot | Track list | Load |
| --- | --- | --- |
| None, or 0 bytes | Empty row; slots 1 to 3 show the track that comes with the game. | Nothing to load. |
| Larger than 4096 bytes | `UNREADABLE` | Refused; the game does not save over it. |
| Container or `TRAK` header damaged ([section 3](#3-iff-container), [4.2](#42-trak-the-track-model)) | `UNREADABLE` | Refused; the game does not save over it. |
| SCTR version above 1 | `NEWER VERSION` | Refused; the game does not save over it. |
| Model breaks [5.6](#56-rules-for-a-valid-track), no valid `STAT` | `UNREADABLE` | Refused. |
| Model breaks [5.6](#56-rules-for-a-valid-track), valid `STAT` | The class in `STAT` | Refused. |
| Valid | `DRAFT` or `READY` (Closed shows as `DRAFT`) | Loaded with its unknown chunks. |

## 9. Conventions of the game's editor

These are not rules of the format: any value that the sections above allow is valid. They
describe how the game's own editor fills the fields, which decides how it works with a track.

- **Track ID.** When the editor saves a track into a slot other than the one it came from, it
  gives the track a new ID: `SCIE` (4 bytes), the slot index 0 to 511 (long), a counter
  (long: one more than the counter of the `SCIE` track it replaces in that slot, otherwise 1)
  and `V09` followed by the byte 1. The game compares IDs only for equality. The records key
  contains the ID ([7.2](#72-rkey-policy-and-track-key)), and the import of older tracks
  recognises a track it has already copied by its track key. A new track needs an ID that no
  other track has; 16 random bytes are enough.
- **Sections.** The editor adds and removes road in sections and finds them from the piece
  IDs. Consecutive pieces whose IDs are 256 or more and equal when their lowest 8 bits are
  cleared form one section. A piece with an ID below 256 is a section of its own. A new
  section gets the group number (the highest piece ID of the track with its lowest 8 bits
  cleared) + 256, and its pieces get the group number + 0, + 1, + 2 and so on in order. The
  editor's sections and the kinds they are made of are in the Used in column of Appendix B.
- **Start piece.** The first piece of the list is the start piece. It is of kind 1 and is
  also the finish piece, and the editor does not remove it.
- **Name.** A new track is called `TRACK` and the slot number in three digits, for example
  `TRACK005`.

## 10. Example track file

A Draft track of one piece, 124 bytes: the start piece (kind 1) in cell X 7, Z 4, open,
initial height 1280, named `EXAMPLE`, with the track ID of the 16 ASCII bytes
`EXAMPLE TRACK ID`.

```
0000  46 4f 52 4d 00 00 00 74 53 43 54 46 54 52 41 4b  FORM...tSCTFTRAK
0010  00 00 00 4c 53 43 54 52 00 01 00 4c 45 58 41 4d  ...LSCTR...LEXAM
0020  50 4c 45 20 54 52 41 43 4b 20 49 44 00 00 00 03  PLE TRACK ID....
0030  00 01 00 00 05 00 00 00 00 00 00 01 45 58 41 4d  ............EXAM
0040  50 4c 45 00 00 00 00 00 00 00 00 00 00 00 00 00  PLE.............
0050  00 00 00 00 00 00 00 01 01 00 00 47 3d 53 02 87  ...........G=S..
0060  53 54 41 54 00 00 00 08 00 01 00 03 3d 53 02 87  STAT........=S..
0070  43 52 43 20 00 00 00 04 bf 98 17 c7              CRC ........
```

| File offset | Bytes | Meaning |
| ---: | --- | --- |
| 0 | `46 4f 52 4d 00 00 00 74` | `FORM`, length 116 = 124 - 8. |
| 8 | `53 43 54 46` | Form type `SCTF`. |
| 12 | `54 52 41 4b 00 00 00 4c` | `TRAK`, 76 bytes. |
| 20 | `53 43 54 52 00 01 00 4c` | `SCTR`, version 1, size 76. |
| 28 | `45 58 ... 49 44` | Track ID `EXAMPLE TRACK ID`. |
| 44 | `00 00 00 03` | Geometry revision 3. |
| 48 | `00 01` | 1 piece. |
| 50 | `00 00` | Open. |
| 52 | `05 00` | Initial height 1280. |
| 54 | `00 00` | Reserved. |
| 56 | `00 00 00 01` | Finish piece ID 1. |
| 60 | `45 58 41 4d 50 4c 45 00 ...` | Name `EXAMPLE`, zero to 24 bytes. |
| 84 | `00 00 00 01 01 00 00 47` | Piece ID 1, kind 1, rotation 0, forward, cell X 7, Z 4. |
| 92 | `3d 53 02 87` | CRC-32 of file bytes 20 to 91 (the SCTR block without its CRC). |
| 96 | `53 54 41 54 00 00 00 08` | `STAT`, 8 bytes. |
| 104 | `00 01 00 03 3d 53 02 87` | Class 1 (Draft: open), rules version 3, the TRAK CRC. |
| 112 | `43 52 43 20 00 00 00 04` | `CRC `, 4 bytes. |
| 120 | `bf 98 17 c7` | CRC-32 of file bytes 0 to 111. |

The road of the piece runs from Z 8192 to Z 10240 at X 15168 (first edge) and X 15552 (second
edge), all at height 1280.

## Appendix A: shapes

The seven shapes give each row as local X and Z, for rotation 0 and the forward direction.
The first edge comes first in each row.

| Shape | Rows | Road |
| :---: | ---: | --- |
| S | 9 | Straight. |
| CR | 10 | Curve of 45 degrees to the right, ending diagonally. |
| CL | 10 | Curve of 45 degrees to the left, ending diagonally. |
| CRS | 9 | Shorter curve of 45 degrees to the right. |
| CLS | 9 | Shorter curve of 45 degrees to the left. |
| D | 14 | Diagonal straight. |
| DS | 12 | Shorter diagonal straight. |

Shape S (9 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 832 | 0 | 1216 | 0 |
| 1 | 832 | 256 | 1216 | 256 |
| 2 | 832 | 512 | 1216 | 512 |
| 3 | 832 | 768 | 1216 | 768 |
| 4 | 832 | 1024 | 1216 | 1024 |
| 5 | 832 | 1280 | 1216 | 1280 |
| 6 | 832 | 1536 | 1216 | 1536 |
| 7 | 832 | 1792 | 1216 | 1792 |
| 8 | 832 | 2048 | 1216 | 2048 |

Shape CR (10 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 832 | 0 | 1216 | 0 |
| 1 | 844 | 284 | 1226 | 251 |
| 2 | 881 | 566 | 1259 | 500 |
| 3 | 943 | 844 | 1314 | 745 |
| 4 | 1028 | 1116 | 1389 | 985 |
| 5 | 1137 | 1379 | 1485 | 1217 |
| 6 | 1269 | 1632 | 1601 | 1440 |
| 7 | 1422 | 1872 | 1736 | 1651 |
| 8 | 1595 | 2098 | 1889 | 1851 |
| 9 | 1788 | 2307 | 2059 | 2036 |

Shape CL (10 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 832 | 0 | 1216 | 0 |
| 1 | 821 | 251 | 1203 | 284 |
| 2 | 788 | 500 | 1166 | 566 |
| 3 | 733 | 745 | 1104 | 844 |
| 4 | 658 | 985 | 1019 | 1116 |
| 5 | 562 | 1217 | 910 | 1379 |
| 6 | 446 | 1440 | 778 | 1632 |
| 7 | 311 | 1651 | 625 | 1872 |
| 8 | 158 | 1851 | 452 | 2098 |
| 9 | -12 | 2036 | 259 | 2307 |

Shape CRS (9 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 832 | 0 | 1216 | 0 |
| 1 | 844 | 261 | 1226 | 223 |
| 2 | 883 | 519 | 1259 | 444 |
| 3 | 946 | 773 | 1314 | 661 |
| 4 | 1034 | 1019 | 1389 | 872 |
| 5 | 1146 | 1255 | 1485 | 1074 |
| 6 | 1280 | 1480 | 1600 | 1266 |
| 7 | 1436 | 1690 | 1733 | 1446 |
| 8 | 1612 | 1883 | 1883 | 1612 |

Shape CLS (9 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | 831 | 0 | 1215 | 0 |
| 1 | 821 | 223 | 1203 | 261 |
| 2 | 788 | 444 | 1164 | 519 |
| 3 | 733 | 661 | 1101 | 773 |
| 4 | 658 | 872 | 1013 | 1019 |
| 5 | 562 | 1074 | 901 | 1255 |
| 6 | 447 | 1266 | 767 | 1480 |
| 7 | 314 | 1446 | 611 | 1690 |
| 8 | 164 | 1612 | 435 | 1883 |

Shape D (14 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | -136 | 135 | 135 | -136 |
| 1 | 44 | 316 | 316 | 44 |
| 2 | 225 | 496 | 496 | 225 |
| 3 | 406 | 677 | 677 | 406 |
| 4 | 586 | 858 | 858 | 586 |
| 5 | 767 | 1038 | 1038 | 767 |
| 6 | 947 | 1219 | 1219 | 947 |
| 7 | 1128 | 1399 | 1399 | 1128 |
| 8 | 1309 | 1580 | 1580 | 1309 |
| 9 | 1489 | 1761 | 1761 | 1489 |
| 10 | 1670 | 1941 | 1941 | 1670 |
| 11 | 1850 | 2122 | 2122 | 1850 |
| 12 | 2031 | 2303 | 2303 | 2031 |
| 13 | 2212 | 2483 | 2483 | 2212 |

Shape DS (12 rows):

| Row | First edge X | First edge Z | Second edge X | Second edge Z |
| ---: | ---: | ---: | ---: | ---: |
| 0 | -136 | 135 | 135 | -136 |
| 1 | 50 | 321 | 321 | 50 |
| 2 | 236 | 508 | 508 | 236 |
| 3 | 422 | 694 | 694 | 422 |
| 4 | 608 | 880 | 880 | 608 |
| 5 | 795 | 1066 | 1066 | 795 |
| 6 | 981 | 1252 | 1252 | 981 |
| 7 | 1167 | 1439 | 1439 | 1167 |
| 8 | 1353 | 1625 | 1625 | 1353 |
| 9 | 1539 | 1811 | 1811 | 1539 |
| 10 | 1726 | 1997 | 1997 | 1726 |
| 11 | 1912 | 2183 | 2183 | 1912 |

## Appendix B: piece kinds

One row for each kind and Reverse value. Kinds 1 to 7 can be placed either way; kinds 8 to
116 only with the Reverse value shown. *H1* and *H2* are the heights of the first and the
second edge of each row in driving order, relative to the piece's base height
([5.3](#53-heights)). Crane *no* marks a piece over a jump gap ([section 6](#6-draft-closed-and-ready)).
Used in names the sections of the game's editor that contain the kind
([section 9](#9-conventions-of-the-games-editor)).

| Kind | Shape | Reverse | Rows | H1 | H2 | Crane | Used in |
| ---: | :---: | :---: | ---: | --- | --- | :---: | --- |
| 1 | S | 0 | 9 | 0 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 0 | yes | start/finish piece |
| 1 | S | 1 | 9 | 0 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 0 | yes | start/finish piece |
| 2 | CR | 0 | 10 | 0 32 64 96 96 96 96 64 32 0 | 0 0 0 0 0 0 0 0 0 0 | yes | revisions 1 and 2 |
| 2 | CR | 1 | 10 | 0 0 0 0 0 0 0 0 0 0 | 0 32 64 96 96 96 96 64 32 0 | yes | revisions 1 and 2 |
| 3 | CL | 0 | 10 | 0 0 0 0 0 0 0 0 0 0 | 0 32 64 96 96 96 96 64 32 0 | yes | revisions 1 and 2 |
| 3 | CL | 1 | 10 | 0 32 64 96 96 96 96 64 32 0 | 0 0 0 0 0 0 0 0 0 0 | yes | revisions 1 and 2 |
| 4 | S | 0 | 9 | 0 64 128 192 256 320 384 448 512 | 0 64 128 192 256 320 384 448 512 | yes | - |
| 4 | S | 1 | 9 | 0 64 128 192 256 320 384 448 512 | 0 64 128 192 256 320 384 448 512 | yes | - |
| 5 | S | 0 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | yes | - |
| 5 | S | 1 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | yes | - |
| 6 | S | 0 | 9 | 0 0 0 0 0 32 64 128 192 | 0 0 0 0 0 32 64 128 192 | yes | - |
| 6 | S | 1 | 9 | 0 0 0 0 0 32 64 128 192 | 0 0 0 0 0 32 64 128 192 | yes | - |
| 7 | S | 0 | 9 | 0 0 0 0 0 -32 -64 -128 -192 | 0 0 0 0 0 -32 -64 -128 -192 | yes | - |
| 7 | S | 1 | 9 | 0 0 0 0 0 -32 -64 -128 -192 | 0 0 0 0 0 -32 -64 -128 -192 | yes | - |
| 8 | S | 0 | 9 | 0 0 32 96 160 256 352 -640 -640 | 0 0 32 96 160 256 352 -640 -640 | yes | Ramp and landing |
| 9 | S | 0 | 9 | 0 0 0 0 1280 1280 1280 1280 1280 | 0 0 0 0 1280 1280 1280 1280 1280 | no | Ramp and landing |
| 10 | S | 0 | 9 | 0 0 32 96 192 288 416 576 736 | 0 0 32 96 192 288 416 576 736 | yes | Uphill large, Uphill medium |
| 11 | S | 0 | 9 | 0 256 512 768 1024 1280 1536 1792 2048 | 0 256 512 768 1024 1280 1536 1792 2048 | yes | Uphill large |
| 12 | S | 0 | 9 | 0 192 384 576 672 704 736 736 736 | 0 192 384 576 672 704 736 736 736 | yes | Uphill large, Uphill medium, High Jump hill |
| 13 | S | 0 | 9 | 0 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 0 | yes | Straight |
| 14 | S | 0 | 9 | 0 0 0 0 0 0 0 -32 -96 | 0 0 0 0 0 0 0 -32 -96 | yes | Downhill right 90, Downhill medium, Downhill large |
| 15 | S | 0 | 9 | 0 -64 -128 -224 -320 -448 -576 -704 -832 | 0 -64 -128 -224 -320 -448 -576 -704 -832 | yes | Downhill right 90, Downhill medium |
| 16 | S | 0 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | 0 -192 -384 -576 -768 -960 -1152 -1344 -1536 | yes | Downhill right 90 |
| 17 | CR | 0 | 10 | 0 -64 -160 -288 -416 -544 -672 -800 -928 -1056 | -1024 -1216 -1376 -1504 -1632 -1760 -1888 -2016 -2144 -2272 | yes | Downhill right 90 |
| 18 | CL | 1 | 10 | 0 -128 -256 -384 -512 -640 -768 -896 -1056 -1248 | -1216 -1344 -1472 -1600 -1728 -1856 -1984 -2112 -2208 -2272 | yes | Downhill right 90 |
| 19 | S | 0 | 9 | 0 -192 -384 -576 -768 -960 -1152 -1344 -1536 | -1024 -1088 -1152 -1216 -1280 -1344 -1408 -1472 -1536 | yes | Downhill right 90, Crest right 180 |
| 20 | S | 0 | 9 | 0 -128 -256 -384 -512 -608 -704 -768 -832 | 0 -128 -256 -384 -512 -608 -704 -768 -832 | yes | Downhill right 90, Downhill medium |
| 21 | S | 0 | 9 | 0 -64 -96 -96 -96 -96 -96 -96 -96 | 0 -64 -96 -96 -96 -96 -96 -96 -96 | yes | Downhill right 90, Downhill medium |
| 22 | S | 0 | 9 | 0 64 128 192 256 320 384 448 512 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | yes | Right 90, Right 45, Right 135 |
| 23 | CR | 0 | 10 | 0 64 96 96 96 96 96 96 96 96 | -1024 -1088 -1120 -1120 -1120 -1120 -1120 -1120 -1120 -1120 | yes | Right 90, Right 135 |
| 24 | CL | 1 | 10 | 0 0 0 0 0 0 0 0 0 0 | -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 | yes | Right 135 |
| 25 | CRS | 0 | 9 | 0 0 0 0 0 0 0 -32 -96 | -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1184 -1120 | yes | Right 135 |
| 26 | D | 1 | 14 | 0 -64 -128 -192 -256 -320 -384 -448 -512 -512 -512 -512 -512 -512 | -1024 -960 -896 -832 -768 -704 -640 -576 -512 -512 -512 -512 -512 -512 | yes | Right 45, Right 135 |
| 27 | DS | 0 | 12 | 0 0 0 0 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 0 0 0 0 | yes | Diagonal straight, Diagonal hump large, Diagonal jump |
| 28 | D | 0 | 14 | 0 0 0 0 0 32 64 128 192 256 320 384 448 512 | 0 0 0 0 0 -32 -64 -128 -192 -256 -320 -384 -448 -512 | yes | Right 135 diagonal |
| 29 | CLS | 1 | 9 | 0 64 96 96 96 96 96 96 96 | -1024 -1088 -1120 -1120 -1120 -1120 -1120 -1120 -1120 | yes | Right 135 diagonal |
| 30 | CR | 0 | 10 | 0 0 0 0 0 0 0 0 0 0 | -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 | yes | Right 135 diagonal |
| 31 | CL | 1 | 10 | 0 0 0 0 0 0 0 0 -32 -96 | -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1216 -1184 -1120 | yes | Right 90, Right 135 diagonal |
| 32 | S | 0 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | -1024 -960 -896 -832 -768 -704 -640 -576 -512 | yes | Right 90, Right 135 diagonal |
| 33 | S | 0 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | 0 64 128 192 256 320 384 448 512 | yes | Left 90, Left 135, Long left 90, Left 180 |
| 34 | CL | 0 | 10 | 0 -64 -96 -96 -96 -96 -96 -96 -96 -96 | 1024 1088 1120 1120 1120 1120 1120 1120 1120 1120 | yes | Left 90, Left 135, Left 180 |
| 35 | CR | 1 | 10 | 0 0 0 0 0 0 0 0 32 96 | 1216 1216 1216 1216 1216 1216 1216 1216 1184 1120 | yes | Left 90, Left 135 diagonal, Left 180, Uphill left 180 |
| 36 | S | 0 | 9 | 0 64 128 192 256 320 384 448 512 | 1024 960 896 832 768 704 640 576 512 | yes | Left 90, Left 45, Long left 90, Left 135 diagonal, Left 180, Uphill left 180 |
| 37 | CRS | 0 | 9 | 0 32 32 32 32 32 32 32 0 | -1024 -1056 -1056 -1056 -1056 -1056 -1056 -1056 -1024 | yes | Right 45 |
| 38 | D | 0 | 14 | 0 0 0 0 0 -32 -64 -128 -192 -256 -320 -384 -448 -512 | 0 0 0 0 0 32 64 128 192 256 320 384 448 512 | yes | Left 45, Left 135 diagonal |
| 39 | CRS | 1 | 9 | 0 -32 -32 -32 -32 -32 -32 -32 0 | 1024 1056 1056 1056 1056 1056 1056 1056 1024 | yes | Left 45 |
| 40 | CR | 1 | 10 | 0 0 0 0 0 0 0 0 0 0 | 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 | yes | Left 135, Left 180 |
| 41 | CLS | 0 | 9 | 0 0 0 0 0 0 0 32 96 | 1216 1216 1216 1216 1216 1216 1216 1184 1120 | yes | Left 135 |
| 42 | D | 1 | 14 | 0 64 128 192 256 320 384 448 512 512 512 512 512 512 | 1024 960 896 832 768 704 640 576 512 512 512 512 512 512 | yes | Left 135 |
| 43 | S | 0 | 9 | 0 -32 -96 -192 -320 -416 -480 -512 -512 | 0 -32 -96 -192 -320 -416 -480 -512 -512 | yes | Downhill small |
| 44 | S | 0 | 9 | 0 0 32 96 192 320 416 480 512 | 0 0 32 96 192 320 416 480 512 | yes | Uphill small |
| 45 | S | 0 | 9 | 0 -64 -160 -256 -384 -512 -672 -832 -1024 | 0 -64 -160 -256 -384 -512 -672 -832 -1024 | yes | Downhill large, Hump Back crest |
| 46 | S | 0 | 9 | 0 -192 -384 -576 -768 -960 -1152 -1344 -1536 | 0 -192 -384 -576 -768 -960 -1152 -1344 -1536 | yes | Downhill large, High Jump hill |
| 47 | S | 0 | 9 | 0 -192 -352 -480 -576 -640 -672 -672 -672 | 0 -192 -352 -480 -576 -640 -672 -672 -672 | yes | Downhill large |
| 48 | S | 0 | 9 | 0 0 0 0 0 0 -32 -64 -128 | 0 0 0 0 0 0 -32 -64 -128 | yes | Coaster descent |
| 49 | DS | 0 | 12 | 0 32 96 192 320 480 640 800 960 1120 1280 1440 | 0 32 96 192 320 480 640 800 960 1120 1280 1440 | yes | Diagonal hump large, Diagonal jump |
| 50 | DS | 0 | 12 | 0 160 320 480 640 800 960 1120 -1440 -1440 -1440 -1440 | 0 160 320 480 640 800 960 1120 -1440 -1440 -1440 -1440 | yes | Diagonal hump large, Diagonal jump |
| 51 | DS | 0 | 12 | 0 1920 1760 1600 1440 1280 1120 960 800 640 480 320 | 0 1920 1760 1600 1440 1280 1120 960 800 640 480 320 | yes | Diagonal jump |
| 52 | DS | 0 | 12 | 0 -128 -224 -288 -320 -320 -320 -320 -320 -320 -320 -320 | 0 -128 -224 -288 -320 -320 -320 -320 -320 -320 -320 -320 | yes | Diagonal jump |
| 53 | S | 0 | 9 | 0 0 32 64 128 192 256 352 480 | 0 0 32 64 128 192 256 352 480 | yes | Coaster long climb |
| 54 | S | 0 | 9 | 0 192 384 576 768 960 1152 1344 1536 | 0 64 128 192 256 320 384 448 512 | yes | Uphill right 90, Crest right 180 |
| 55 | CR | 0 | 10 | 0 192 352 480 608 736 864 992 1120 1248 | -1024 -960 -864 -736 -608 -480 -352 -224 -96 32 | yes | Uphill right 90 |
| 56 | CL | 1 | 10 | 0 128 256 384 512 640 768 896 992 1056 | -1216 -1088 -960 -832 -704 -576 -448 -320 -160 32 | yes | Uphill right 90 |
| 57 | S | 0 | 9 | 0 64 128 192 256 320 384 448 512 | -1024 -832 -640 -448 -256 -64 128 320 512 | yes | Uphill right 90 |
| 58 | S | 0 | 9 | 0 64 128 160 192 192 160 128 64 | 0 64 128 160 192 192 160 128 64 | yes | Hump Back crest |
| 59 | S | 0 | 9 | 0 0 0 32 96 192 320 512 768 | 0 0 0 32 96 192 320 512 768 | yes | Hump Back crest |
| 60 | S | 0 | 9 | 0 320 640 960 1280 1600 1920 2240 2560 | 0 320 640 960 1280 1600 1920 2240 2560 | yes | Hump Back crest |
| 61 | S | 0 | 9 | 0 320 640 928 1216 1472 1728 1952 2176 | 0 320 640 928 1216 1472 1728 1952 2176 | yes | Hump Back crest |
| 62 | S | 0 | 9 | 0 192 384 544 704 832 960 1056 1152 | 0 192 384 544 704 832 960 1056 1152 | yes | Hump Back crest |
| 63 | S | 0 | 9 | 0 -192 -416 -640 -896 -1152 -1440 -1728 -2048 | 0 -192 -416 -640 -896 -1152 -1440 -1728 -2048 | yes | Hump Back crest |
| 64 | S | 0 | 9 | 0 -320 -640 -960 -1280 -1600 -1920 -2240 -2560 | 0 -320 -640 -960 -1280 -1600 -1920 -2240 -2560 | yes | Hump Back crest |
| 65 | S | 0 | 9 | 0 -320 -576 -768 -896 -992 -1056 -1088 -1088 | 0 -320 -576 -768 -896 -992 -1056 -1088 -1088 | yes | Hump Back crest |
| 66 | S | 0 | 9 | 0 64 128 192 256 320 384 448 512 | 0 192 384 576 768 960 1152 1344 1536 | yes | Uphill left 90, Uphill left 180 |
| 67 | CL | 0 | 10 | 0 64 160 288 416 544 672 800 928 1056 | 1024 1216 1376 1504 1632 1760 1888 2016 2144 2272 | yes | Uphill left 90 |
| 68 | CR | 1 | 10 | 0 128 256 384 512 640 768 896 1056 1248 | 1216 1344 1472 1600 1728 1856 1984 2112 2208 2272 | yes | Uphill left 90 |
| 69 | S | 0 | 9 | 0 192 384 576 768 960 1152 1344 1536 | 1024 1088 1152 1216 1280 1344 1408 1472 1536 | yes | Uphill left 90 |
| 70 | S | 0 | 9 | 0 128 256 352 416 448 480 480 480 | 0 128 256 352 416 448 480 480 480 | yes | Coaster long climb |
| 71 | CRS | 1 | 9 | 0 -64 -96 -96 -96 -96 -96 -96 -96 | 1024 1088 1120 1120 1120 1120 1120 1120 1120 | yes | Left 135 diagonal |
| 72 | CL | 0 | 10 | 0 0 0 0 0 0 0 0 0 0 | 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 | yes | Left 135 diagonal, Left 180, Uphill left 180 |
| 73 | S | 0 | 9 | 0 256 512 768 1024 1280 1536 1792 2048 | 0 128 256 384 512 640 768 896 1024 | yes | Uphill right 45 |
| 74 | CRS | 0 | 9 | 0 224 416 608 800 992 1184 1376 1536 | -1024 -864 -672 -480 -288 -96 96 288 512 | yes | Uphill right 45 |
| 75 | D | 1 | 14 | 0 128 256 384 512 640 768 896 1024 1216 1408 1600 1792 1984 | -1024 -768 -512 -256 0 256 512 768 1024 1216 1408 1600 1792 1984 | yes | Uphill right 45 |
| 76 | D | 0 | 14 | 0 192 384 576 768 928 1088 1216 1344 1472 1600 1728 1856 1984 | 0 192 384 576 768 992 1216 1472 1728 1984 2240 2496 2752 3008 | yes | Uphill left 45 |
| 77 | CRS | 1 | 9 | 0 160 352 544 736 928 1120 1312 1536 | 1024 1248 1440 1632 1824 2016 2208 2400 2560 | yes | Uphill left 45 |
| 78 | S | 0 | 9 | 0 256 512 768 1024 1280 1536 1792 2048 | 1024 1152 1280 1408 1536 1664 1792 1920 2048 | yes | Uphill left 45 |
| 79 | S | 0 | 9 | 0 384 768 1152 1536 1920 2304 2688 3072 | 0 256 512 768 1024 1280 1536 1792 2048 | yes | Steep uphill right 90 |
| 80 | CR | 0 | 10 | 0 384 736 1056 1376 1696 2016 2336 2656 2976 | -1024 -768 -480 -160 160 480 800 1120 1440 1760 | yes | Steep uphill right 90 |
| 81 | CL | 1 | 10 | 0 320 640 960 1280 1600 1920 2240 2528 2784 | -1216 -896 -576 -256 64 384 704 1024 1376 1760 | yes | Steep uphill right 90 |
| 82 | S | 0 | 9 | 0 256 512 768 1024 1280 1536 1792 2048 | -1024 -640 -256 128 512 896 1280 1664 2048 | yes | Steep uphill right 90 |
| 83 | S | 0 | 9 | 0 -192 -384 -576 -768 -960 -1152 -1344 -1536 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | yes | Downhill left 180 |
| 84 | CL | 0 | 10 | 0 -192 -352 -480 -608 -736 -864 -992 -1120 -1248 | 1024 960 864 736 608 480 352 224 96 -32 | yes | Downhill left 180 |
| 85 | CR | 1 | 10 | 0 -128 -256 -384 -512 -640 -768 -896 -1024 -1152 | 1216 1088 960 832 704 576 448 320 192 64 | yes | Downhill left 180 |
| 86 | CL | 0 | 10 | 0 -128 -256 -384 -512 -640 -768 -896 -1024 -1152 | 1216 1088 960 832 704 576 448 320 192 64 | yes | Downhill left 180 |
| 87 | CR | 1 | 10 | 0 -128 -256 -384 -512 -640 -768 -896 -992 -1056 | 1216 1088 960 832 704 576 448 320 160 -32 | yes | Downhill left 180 |
| 88 | S | 0 | 9 | 0 -64 -128 -192 -256 -320 -384 -448 -512 | 1024 832 640 448 256 64 -128 -320 -512 | yes | Downhill left 180 |
| 89 | CLS | 0 | 9 | 0 -64 -96 -96 -96 -96 -96 -96 -96 | 1024 1088 1120 1120 1120 1120 1120 1120 1120 | yes | Long left 90 |
| 90 | D | 1 | 14 | 0 0 0 0 0 0 0 0 0 0 0 0 0 0 | 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 | yes | Long left 90 |
| 91 | DS | 0 | 12 | 0 0 0 0 0 0 0 0 0 0 0 0 | 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 | yes | Long left 90 |
| 92 | D | 0 | 14 | 0 0 0 0 0 0 0 0 0 0 0 0 0 0 | 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 1216 | yes | Long left 90 |
| 93 | CRS | 1 | 9 | 0 0 0 0 0 0 0 32 96 | 1216 1216 1216 1216 1216 1216 1216 1184 1120 | yes | Long left 90 |
| 94 | S | 0 | 9 | 0 192 448 768 1152 1600 2112 2624 3136 | 0 192 448 768 1152 1600 2112 2624 3136 | yes | Coaster long climb |
| 95 | S | 0 | 9 | 0 512 1024 1536 2048 2560 3072 3584 4096 | 0 512 1024 1536 2048 2560 3072 3584 4096 | yes | Coaster long climb |
| 96 | S | 0 | 9 | 0 512 1024 1536 1984 2368 2688 2944 3136 | 0 512 1024 1536 1984 2368 2688 2944 3136 | yes | Coaster long climb |
| 97 | S | 0 | 9 | 0 -96 -224 -384 -576 -800 -1056 -1344 -1664 | 0 -96 -224 -384 -576 -800 -1056 -1344 -1664 | yes | Coaster descent |
| 98 | S | 0 | 9 | 0 -352 -736 -1152 -1600 -2080 -2592 -3136 -3712 | 0 -352 -736 -1152 -1600 -2080 -2592 -3136 -3712 | yes | Coaster descent |
| 99 | S | 0 | 9 | 0 -608 -1216 -1824 -2432 -3040 -3648 -4256 -4864 | 0 -608 -1216 -1824 -2432 -3040 -3648 -4256 -4864 | yes | Coaster descent |
| 100 | S | 0 | 9 | 0 -608 -1152 -1632 -2048 -2400 -2688 -2912 -3072 | 0 -608 -1152 -1632 -2048 -2400 -2688 -2912 -3072 | yes | Coaster descent |
| 101 | S | 0 | 9 | 0 -96 -160 -192 -192 -160 -96 0 128 | 0 -96 -160 -192 -192 -160 -96 0 128 | yes | Coaster descent |
| 102 | CR | 0 | 10 | 0 192 320 416 512 576 640 704 768 800 | -1024 -960 -896 -800 -704 -640 -576 -512 -448 -416 | yes | Crest right 180 |
| 103 | CL | 1 | 10 | 0 32 64 96 128 128 128 128 128 128 | -1216 -1184 -1152 -1120 -1088 -1088 -1088 -1088 -1088 -1088 | yes | Crest right 180 |
| 104 | CR | 0 | 10 | 0 0 0 0 0 0 -32 -64 -96 -128 | -1216 -1216 -1216 -1216 -1216 -1216 -1248 -1280 -1312 -1344 | yes | Crest right 180 |
| 105 | CL | 1 | 10 | 0 -32 -96 -160 -224 -288 -384 -480 -608 -800 | -1216 -1248 -1312 -1376 -1440 -1504 -1600 -1696 -1760 -1824 | yes | Crest right 180 |
| 106 | CL | 0 | 10 | 0 64 128 224 320 384 448 512 576 608 | 1024 1216 1344 1440 1536 1600 1664 1728 1792 1824 | yes | Uphill left 180 |
| 107 | CR | 1 | 10 | 0 32 64 96 128 128 128 128 128 128 | 1216 1248 1280 1312 1344 1344 1344 1344 1344 1344 | yes | Uphill left 180 |
| 108 | S | 0 | 9 | 0 32 96 160 192 160 96 32 0 | 0 0 0 0 0 0 0 0 0 | yes | Bumpy straight |
| 109 | S | 0 | 9 | 0 0 0 0 0 0 0 0 0 | 0 32 96 160 192 160 96 32 0 | yes | Bumpy straight |
| 110 | S | 0 | 9 | 0 -64 -128 -192 -224 -192 -128 -64 0 | 0 -64 -128 -192 -224 -192 -128 -64 0 | yes | Dip |
| 111 | S | 0 | 9 | 0 32 96 192 320 480 704 928 1152 | 0 32 96 192 320 480 704 928 1152 | yes | High Jump hill |
| 112 | S | 0 | 9 | 0 0 32 96 192 320 480 672 896 | 0 0 32 96 192 320 480 672 896 | yes | High Jump hill |
| 113 | S | 0 | 9 | 0 256 480 672 832 960 1056 1120 1184 | 0 256 480 672 832 960 1056 1120 1184 | yes | High Jump hill |
| 114 | S | 0 | 9 | 0 32 32 0 -32 -96 -224 -384 -576 | 0 32 32 0 -32 -96 -224 -384 -576 | yes | High Jump hill |
| 115 | S | 0 | 9 | 0 -128 -224 -288 -320 -320 -320 -320 -320 | 0 -128 -224 -288 -320 -320 -320 -320 -320 | yes | High Jump hill |
| 116 | DS | 0 | 12 | 0 0 0 0 0 0 0 0 0 0 0 0 | 0 0 0 0 0 0 0 0 0 0 0 0 | no | Diagonal jump |
