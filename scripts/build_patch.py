#!/usr/bin/env python3
"""Verify or rebuild embedded assets using vasm and the supported original ADF.

The default is read-only verification. To regenerate patch.py, update the
versioned src/patches.json contract first and pass --write explicitly.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import subprocess
import textwrap

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--check', action='store_true', help='Verify without writing patch.py (default)')
    mode.add_argument('--write', action='store_true', help='Regenerate the embedded data in patch.py')
    args = parser.parse_args()
    source = args.original.read_bytes()
    spec = importlib.util.spec_from_file_location('adf_patch', ROOT / 'patch.py')
    patch = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(patch)
    manifest = json.loads((ROOT / 'src/patches.json').read_text())
    if (len(source) != patch.DISK_SIZE or patch.sha256(source) != patch.SOURCE_SHA256
            or patch.SOURCE_SHA256 != manifest['source']['sha256']):
        raise ValueError('Wrong original ADF')
    if patch.VERSION != manifest['release_version']:
        raise ValueError('Release version differs from source manifest')
    assembler = shutil.which('vasmm68k_mot')
    if not assembler:
        raise RuntimeError('vasmm68k_mot is required to rebuild embedded assets')
    work = ROOT / 'work/adf-patch-build'
    work.mkdir(parents=True, exist_ok=True)
    assets = {}
    from intro_tables import write_tables
    table_path = work / 'intro-tables.i'
    write_tables(table_path)
    for item in sorted(manifest['payloads'], key=lambda item: item['id'] != 'intro'):
        name, path = item['id'], 'src/' + item['source']
        target = work / (name + '.bin')
        if name == 'intro':
            wrapper = work / 'intro-wrapper.s'
            wrapper.write_text(' include "src/SCR_Intro.s"\n include "%s"\n' % table_path)
            path = str(wrapper)
        elif name == 'boot':
            intro = assets['intro']
            padded = intro + bytes(patch.INTRO_RESERVED_SIZE - len(intro))
            checksum = sum(struct.unpack('>2048I', padded)) & 0xffffffff
            wrapper = work / 'boot-wrapper.s'
            wrapper.write_text('INTRO_SUM equ $%x\n include "src/SCR_Boot.s"\n' % checksum)
            path = str(wrapper)
        subprocess.run([assembler, '-m68000', '-Fbin', '-L', str(target.with_suffix('.lst')),
                        '-o', str(target), path], cwd=ROOT, check=True)
        assets[name] = target.read_bytes()
        if (len(assets[name]) != item['size']
                or patch.sha256(assets[name]) != item['sha256']):
            raise ValueError(name + ' differs from the versioned source manifest')
    boot, runtime = assets['boot'], assets['runtime']
    # Boot copy count and entry offsets are an explicit versioned contract.
    if (len(boot) != 320 or len(runtime) != 4004 or boot[0x62:0x66].hex() != '303c07d1'
            or boot[0x1a:0x1e].hex() != '00009c00'):
        raise ValueError('Update the boot entry/copy contract before changing asset sizes')
    for item in manifest['assembly_patches']:
        wrapper = work / (Path(item['source']).stem + '.s')
        target = wrapper.with_suffix('.bin')
        address = int(item['runtime_address'], 0)
        definitions = ''.join('%s equ $%x\n' % (k, int(v, 0))
                              for k, v in item['bindings'].items())
        wrapper.write_text(' org $%x\n' % address + definitions
                           + ' include "src/%s"\n' % item['source'])
        subprocess.run([assembler, '-m68000', '-Fbin', '-o', str(target), str(wrapper)],
                       cwd=ROOT, check=True)
        assembled = target.read_bytes()
        hook = next(p for p in manifest['patches'] if int(p['runtime_address'], 0) == address)
        size = item['size']
        if assembled[:size] != bytes.fromhex(hook['replacement_hex']):
            raise ValueError(item['source'] + ' differs from the instruction patch')
        # The polygon row includes its unchanged short-loop continuation.
        expected_size = 112 if address == 0x66740 else size
        if len(assembled) != expected_size:
            raise ValueError(item['source'] + ' has an unexpected size')
        offset = int(hook['adf_offset'], 0)
        if assembled[size:] != source[offset + size:offset + len(assembled)]:
            raise ValueError(item['source'] + ' changes its preserved continuation')
    boot_hooks = [(int(p['adf_offset'], 0), p['expected_hex'], p['replacement_hex'])
                  for p in manifest['boot_patches'] if int(p['adf_offset'], 0) != 4]
    hooks = [(int(p['adf_offset'], 0), p['expected_hex'], p['replacement_hex'])
             for p in manifest['patches']]
    result = bytearray(source)
    for offset, old, new in boot_hooks + hooks:
        before, after = bytes.fromhex(old), bytes.fromhex(new)
        if source[offset:offset + len(before)] != before or len(before) != len(after):
            raise ValueError('Unexpected bytes at %x' % offset)
        result[offset:offset + len(after)] = after
    if any(source[0x200:0x200 + len(boot)]):
        raise ValueError('Boot extension space is occupied')
    result[0x200:0x200 + len(boot)] = boot
    offset = patch.PAYLOAD_OFFSET
    if patch.sha256(source[offset:offset + len(runtime)]) != manifest['payloads'][1]['expected_sha256']:
        raise ValueError('Unexpected original loader tail')
    result[offset:offset + len(runtime)] = runtime
    intro = assets['intro']
    if any(source[patch.INTRO_OFFSET:patch.INTRO_OFFSET + patch.INTRO_RESERVED_SIZE]):
        raise ValueError('Intro placement is occupied')
    result[patch.INTRO_OFFSET:patch.INTRO_OFFSET + patch.INTRO_RESERVED_SIZE] = intro + bytes(patch.INTRO_RESERVED_SIZE - len(intro))
    result[4:8] = bytes(4)
    struct.pack_into('>I', result, 4, patch.boot_sum(result) ^ 0xffffffff)
    if patch.boot_sum(result) != 0xffffffff or patch.sha256(result) != manifest['output']['sha256']:
        raise ValueError('Generated ADF differs from the versioned release hash')
    lines = []
    for name, data in [('BOOT', boot), ('RUNTIME', runtime), ('INTRO', intro)]:
        lines += [name + '_HEX = ('] + ["    '" + line + "'" for line in textwrap.wrap(data.hex(), 96)] + [')']
        lines += [name + '_SHA256 = ' + repr(patch.sha256(data))]
    lines += ['BOOT_HOOKS = [']
    lines += ['    (0x%x, %r, %r),' % h for h in boot_hooks] + [']']
    lines += ['TAIL_SHA256 = ' + repr(patch.sha256(source[offset:offset + len(runtime)])),
              'OUTPUT_SHA256 = ' + repr(patch.sha256(result)), 'HOOKS = [']
    lines += ['    (0x%x, %r, %r),' % h for h in hooks] + [']']
    path = ROOT / 'patch.py'
    text = path.read_text()
    start = '# BEGIN GENERATED PATCH DATA (scripts/build_patch.py)\n'
    end = '# END GENERATED PATCH DATA'
    if text.count(start) != 1 or text.count(end) != 1:
        raise ValueError('Expected exactly one generated data block')
    rebuilt = text.split(start)[0] + start + '\n'.join(lines) + '\n' + end + text.split(end)[1]
    if args.write:
        path.write_text(rebuilt)
        print('Updated patch.py; output SHA-256:', patch.sha256(result))
    elif text != rebuilt:
        raise ValueError('Embedded data differs from assembly sources; review before using --write')
    else:
        print('Assembly, embedded data and release ADF match:', patch.sha256(result))


if __name__ == '__main__':
    main()
