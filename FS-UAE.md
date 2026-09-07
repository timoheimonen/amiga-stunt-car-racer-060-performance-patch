# FS-UAE setup for version 0.3.0

**Emulator only:** this version targets FS-UAE rather than physical Amiga hardware.

Use FS-UAE 3.2.35 with PAL A1200/AGA, MC68060, Kickstart 3.1 A1200
rev 40.68, 2 MiB Chip RAM and 8 MiB Fast RAM.

The intended profile uses `cpu_speed=real` with JIT disabled and CPU,
memory and blitter cycle-exact emulation disabled.

Include this in `.fs-uae` profile and replace the two file paths:

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
fast_memory = 8192
ntsc_mode = 0

kickstart_file = /path/to/Kickstart-3.1-A1200-40.68.rom
floppy_drive_count = 1
floppy_drive_0 = /path/to/StuntCarRacer-KS31-AGA-060-50FPS.adf
```

The patcher checks the disk, not the emulator configuration. The runtime
needs its fixed 4 KiB Chip allocation at `0x181000`. Allocation failure
halts boot with a red screen. See [memory details](PATCH.md#loader-and-memory).

## Checksums

Both ADFs are 901,120 bytes. The ROM is 524,288 bytes.
The identified source dump shows QUARTEX text in the track introduction;
support is limited to the exact checksum below.

| File | SHA-256 |
| --- | --- |
| Supported Stunt Car Racer ADF (Quartex-crack) | `548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06` |
| Patched ADF (0.3.0, 50 FPS Practice and computer-opponent races) | `a0f94e01a3162fc3649f81526f76aac02200833b119f7e888e816aa1645e45d2` |
| Kickstart 3.1 A1200 rev 40.68 | `6d43840d4099a74170ea0f0425b6257c3891ebcaa39c4d1840075a9ab22b5707` |

The patcher verifies the whole original disk, displaced instructions,
embedded payloads, loader-tail contents, boot checksum and whole output.
It reads back the complete temporary file before publishing it. The ROM
is not read or verified by the patcher. A different dump, modified save
disk, truncated image or already-patched disk is rejected.
