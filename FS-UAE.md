# FS-UAE setup for version 1.3.0

**Emulator only:** this version targets FS-UAE rather than physical Amiga hardware.

The example profile uses FS-UAE 3.2.35 with PAL A1200, Blizzard 1260 /
MC68060, an A1200 Kickstart ROM, a Blizzard 1260 ROM, 2 MiB Chip RAM
and 32 MiB accelerator RAM.

The intended profile uses `cpu_speed=real` with JIT disabled and CPU,
memory and blitter cycle-exact emulation disabled.

Include this in `.fs-uae` profile and replace the three file paths:

```ini
[fs-uae]
amiga_model = A1200
cpu = 68060
fpu = 0
mmu = 0
accuracy = 1
jit_compiler = 0
uae_cpu_speed = real
chip_memory = 2048
slow_memory = 0
fast_memory = 0
accelerator = blizzard-1260
accelerator_memory = 32768
accelerator_rom = /path/to/Blizzard_1260.rom
ntsc_mode = 0

kickstart_file = /path/to/Kickstart-A1200.rom
floppy_drive_count = 1
floppy_drive_0 = /path/to/StuntCarRacer-Performance-v1.3.0.adf
```

The patcher checks the disk, not the emulator configuration. The runtime
needs its fixed 8 KiB Chip allocation at `0x181000`. Allocation failure
halts boot with a red screen. See [memory details](PATCH.md#loader-and-memory).

## Editor storage

Keep DF0 writable for the editor's 32 track slots and custom-track records.
For Save/Load → Disk, set `floppy_drive_count = 2` and insert a separate
writable ADF in DF1. The editor initializes a track disk only after confirmation;
initialization erases that disk. Keep the game disk in DF0.

## Checksums

Both ADFs are 901,120 bytes. The Kickstart ROM is 524,288 bytes; the Blizzard ROM is 32,768 bytes.
The identified source dump shows QUARTEX text in the track introduction;
support is limited to the exact checksum below.

| File | SHA-256 |
| --- | --- |
| Supported Stunt Car Racer ADF (Quartex-crack) | `548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06` |
| Patched ADF (1.3.0, 50 FPS Practice and computer-opponent races) | `aa19290574252dc42ba1cc94e5c382d9d572a771331bdb77601842c082a82722` |
| Blizzard 1260 ROM | `d583d6c378a58344d133763066c353e44b4dd00b234409a89d6ba2e238a6ef2a` |
| Example A1200 Kickstart ROM, rev 40.68 | `6d43840d4099a74170ea0f0425b6257c3891ebcaa39c4d1840075a9ab22b5707` |

The patcher verifies the whole original disk, displaced instructions,
embedded payloads, loader-tail contents, boot checksum and whole output.
It reads back the complete temporary file before publishing it. The ROMs
are not read or verified by the patcher. A different dump, modified save
disk, truncated image or already-patched disk is rejected.
