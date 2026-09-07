#!/usr/bin/env python3
# Copyright (c) 2026 Timo Heimonen
# SPDX-License-Identifier: MIT

"""Patch a Stunt Car Racer ADF for 68060, PAL 50 FPS.

Self-contained: Python 3.8+ and the supported original ADF are sufficient.
Fixed 20 ms physics and 50 FPS rendering for Practice and computer-opponent races.
"""
import argparse
import hashlib
import os
from pathlib import Path
import struct
import tempfile

VERSION = '0.3.0'
OUTPUT_NAME = 'StuntCarRacer-060-50FPS.adf'
SOURCE_SHA256 = '548fd106cd62f2d80159d48ddd5293d8b22b6b17f80c17a84a61d75f5c8a9e06'
DISK_SIZE = 901120
PAYLOAD_OFFSET = 0xb720


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def boot_sum(data):
    """Amiga end-around-carry sum of the two boot sectors."""
    total = 0
    for (word,) in struct.iter_unpack('>I', data[:1024]):
        total += word
        total = (total & 0xffffffff) + (total >> 32)
    return total


def patch_disk(source):
    if len(source) != DISK_SIZE or sha256(source) != SOURCE_SHA256:
        raise ValueError('Unsupported original ADF: expected SHA-256 ' + SOURCE_SHA256)
    boot = bytes.fromhex(BOOT_HEX)
    runtime = bytes.fromhex(RUNTIME_HEX)
    if sha256(boot) != BOOT_SHA256 or sha256(runtime) != RUNTIME_SHA256:
        raise ValueError('Embedded patch is corrupt')
    result = bytearray(source)

    def replace(offset, expected, new):
        if len(expected) != len(new) or source[offset:offset + len(new)] != expected:
            raise ValueError('Original bytes differ at ADF offset 0x%x' % offset)
        result[offset:offset + len(new)] = new

    replace(0x2c, bytes.fromhex('4eaeff3a'), bytes.fromhex('610001d2'))
    replace(0x70, bytes.fromhex('4eaefe38'), bytes.fromhex('610001da'))
    replace(0x200, bytes(len(boot)), boot)
    original_tail = source[PAYLOAD_OFFSET:PAYLOAD_OFFSET + len(runtime)]
    if sha256(original_tail) != TAIL_SHA256:
        raise ValueError('Unexpected loader tail')
    replace(PAYLOAD_OFFSET, original_tail, runtime)
    for offset, original, replacement in HOOKS:
        replace(offset, bytes.fromhex(original), bytes.fromhex(replacement))
    result[4:8] = bytes(4)
    struct.pack_into('>I', result, 4, boot_sum(result) ^ 0xffffffff)
    if boot_sum(result) != 0xffffffff or sha256(result) != OUTPUT_SHA256:
        raise ValueError('Patched ADF verification failed')
    return bytes(result)


def default_output_path(source_path):
    return Path(source_path).with_name(OUTPUT_NAME)


def write_disk(source_path, output_path, force=False):
    source_path = Path(source_path).expanduser()
    output_path = Path(output_path).expanduser()
    if source_path.resolve() == output_path.resolve():
        raise ValueError('The original ADF must not be overwritten')
    if output_path.exists() and source_path.samefile(output_path):
        raise ValueError('The original ADF must not be overwritten (same file)')
    if output_path.is_symlink():
        raise ValueError('Output must not be a symbolic link: ' + str(output_path))
    if output_path.exists() and not force:
        raise FileExistsError('Output already exists (use --force): ' + str(output_path))
    patched = patch_disk(source_path.read_bytes())
    output_path.parent.mkdir(parents=True, exist_ok=True)
    # Verify the complete temporary file before publishing. Without --force,
    # link also protects a destination created after the existence check.
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(dir=output_path.parent, prefix='.stunt-', delete=False) as f:
            temporary = Path(f.name)
            f.write(patched)
            f.flush()
            os.fsync(f.fileno())
        if temporary.read_bytes() != patched:
            raise ValueError('Written ADF verification failed')
        if force:
            os.replace(temporary, output_path)
            temporary = None
        else:
            os.link(temporary, output_path)
    finally:
        if temporary is not None:
            temporary.unlink()
    return sha256(patched)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path, help='Unmodified supported Stunt Car Racer ADF')
    parser.add_argument('-o', '--output', type=Path,
                        help='Output ADF (default: %s beside original)' % OUTPUT_NAME)
    parser.add_argument('-f', '--force', action='store_true',
                        help='Replace an existing output; never overwrite the original')
    parser.add_argument('--version', action='version', version='%(prog)s ' + VERSION)
    args = parser.parse_args(argv)
    output = args.output if args.output is not None else default_output_path(args.original)
    try:
        digest = write_disk(args.original, output, force=args.force)
    except (OSError, ValueError) as error:
        parser.exit(1, 'Error: %s\n' % error)
    print('Stunt Car Racer 50 FPS patch ' + VERSION)
    print('Created %s\nSHA-256: %s' % (output, digest))
    print('Practice and computer-opponent races: PAL, 68060, 2 MiB Chip, 8 MiB Fast.')


# BEGIN GENERATED PATCH DATA (scripts/build_patch.py)
BOOT_HEX = (
    '48e77ffe203c00001000227c001810004eaeff344a80671a203c00009800223c000100024eaeff3a4a8067064cdf7ffe'
    '4e754eaeff6a46fc270033fc7fff00dff09633fc0f0000dff18060fe4eaefe3848e7fffe204bd1fc00008b20227c0018'
    '1000303c055832d851c8fffc4eaefd844cdf7fff4e75'
)
BOOT_SHA256 = '5914198f75b76891ad43cc5b60111971c6337b22de3f94257350b92a46d94703'
RUNTIME_HEX = (
    '50323031001810280018106c001810b000181222001812a400181254001812c0001812d8001812da30390001bcf62f01'
    '720061000220221fd1790001bcea30390001bcf82f0172026100020a221fd1790001bcec30390001bcfa2f0172046100'
    '01f4221fd1790001bcee4e7530390001bcfc2f017206610001dc221fd1790001bcf030390001bcfe2f017208610001c6'
    '221fd1790001bcf230390001bd002f01720a610001b0221fd1790001bcf44e7530390001bcea2f01720c61000198221f'
    'ed80d1b90001bcd830390001bcec2f01720e61000180221fef80d1b90001bcdc30390001bcee2f01721061000168221f'
    'ed80d1b90001bce030390001bcdc0c4003e86d0e33fc03e80001bcdc4279001812ce30390001bd3a2f01721261000136'
    '221fd1790001bce430390001bd3c2f01721461000120221fd1790001bce630390001bd3e2f0172166100010a221fd179'
    '0001bce8343c00004a390001bb756a0e10390001bb9a0c0000e066025402207c00061ad436390001bce46b0a30302000'
    'b043642e600830302004b043652433c00001bce44279001812d236390001bcf0b7406b0e33fc00000001bcf042790018'
    '12c636390001bce86b0a30302000b043642e600830302004b043652433c00001bce84279001812d636390001bcf4b740'
    '6b0e33fc00000001bcf44279001812ca08b900070001bbab10390001bce46a0244000c00000f6d0808f900070001bbab'
    '303c000090790001bce433c00001bc424e75363c0678c1c3e0802f01320648c1d0810c8000007fff6f06203c00007fff'
    '0c80ffff80006c06203cffff8000221f4a404e7548e7108036020243ff00662a41fa005ec1fc00ee760036301000d083'
    '81fc0600260048434a436a065340064306003183100048c0601033fc0001001812d8143c00eec1c2e080143c00ee4cdf'
    '01084e7548e7808041fa0016700b425851c8fffc4279001812d84cdf01014e7500000000000000000000000000000000'
    '000000000000000000005232303100181336001813580018137a0018139c001813ae001813e400181466001814ba0018'
    '14d6001814ee0018154a0018156c001815740018158e001815a8001815c800181720001816ba001816bb001816bc0018'
    '16bd00181ab24a39001816ba660c30390001bcf64ef900061ae2610002946100fcd8610002a44e754a39001816ba660c'
    '30390001bcfc4ef900061b2c610002a26100fcfa610002b24e754a39001816ba660c30390001bcea4ef9000619566100'
    '02b06100fd1c610002c04e754a39001816ba66064ef90006180e6000fe764eb9000605b648e7fffe40e76100fee86100'
    '05c24239001816ba4239001816bb13fc0005001816bc4279001816be44df4cdf7fff4e7548e780804a39001816ba662c'
    '4a390001ca224e714e716100fea86100058213f90001bbcd001816bd13fc0005001816bc13fc0001001816ba52390018'
    '16bc0c390006001816bc651e4239001816bc13fc0001001816bb13fa02810001bbcd53390001bbac60164239001816bb'
    '13fc00ff0001bbcd600653390001bbac4cdf01014e754a39001816ba660c52390001bbc94ef90005db3a4a39001816bb'
    '660e13fc00ff0001bbcd4ef90005db7252390001bbc9143c0000103c00eed1390001bbcf6502530213c20001bbcd13c2'
    '001816bd4ef90005db584a39001816ba670a13fc0001000616d84e7513fc0006000616d84e754a39001816ba67084a39'
    '001816bb670252000c0000034e754a39001816ba66064ef900060fbe30390001bd306a02444033c00001bd5c12390001'
    'bb7e670c4279001816be4ef900060fea48e7300030390001bc62c0fc0bfc7600363a018cd08333c0001816be48404cdf'
    '000c91790001bc624e754a39001816ba67084a39001816bb6710103c0013207c0001c9384ef90005df384e75d1390001'
    'bbe34e7513fc0005000620b64a39001816ba670813fc001e000620b64e7513fc000500063ee04a39001816ba670813fc'
    '001e00063ee04e754a39001816ba67104a39001816bb66084a390001bb414e7553390001bb414e754239001816ba13fc'
    '0006000616d833fc002000069ede4e7540e748e7f0e0720074027600610000824cdf070f44df4e7540e748e7f0e07200'
    '740276016100006a4cdf070f44df4e7540e748e7f0e0720374027600610000524cdf070f44df4e7540e748e7f0e07203'
    '740276016100003a4cdf070f44df4e7540e748e7f0e0720674057600610000224cdf070f44df4e7540e748e7f0e07206'
    '740576016100000a4cdf070f44df4e7541fa004e43fa007a45fafc463001e5482f08207000000c410006650a0c410009'
    '64042050600230504a036610b1f10000670e3001d04042720000600423880000205f524151caffc64e75000005000000'
    '0001bcea0001bcec0001bcee0001bcf00001bcf20001bcf40001bcd80001bcdc0001bce00001bce40001bce60001bce8'
    '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
    '4eb90001b7b640e74a39001816ba4e714a390001b81666f844df4e7548e75cc0323c0000383c0600610000e24cdf033a'
    '143c00ee4ef9000640fe48e75cc0323c0004383c0c00610000c44cdf033a143c00ee4ef90006411848e75cc0323c0008'
    '383c0600610000a64cdf033a143c00ee4ef90006413048e75cc0323c000c383c0c00610000884cdf033a143c00ee4ef9'
    '0006414a48e75cc0323c0010383c06006100006a4cdf033a143c00ee4ef90006416248e75cc0323c0014383c0c006100'
    '004c4cdf033a143c00ee4ef90006417c48e75cc0323c0018383c06006100002e4cdf033a143c00ee4ef900063bf048e7'
    '5cc0323c001c383c0600610000104cdf033a143c00ee4ef900063a044a39001816ba673041fa01622270100041fa017a'
    '2609670c3611b6701002670442701000c1fc00ee6120260967083611d640318310024e75143c00eec1c2e0800c440c00'
    '66f0e2404e75760036301000d08381c4260048434a436a045340d6443183100048c04e7548e7188048c04a39001816ba'
    '670841fa0114780661cc4cdf01184e7548e760004880722061da4cdf0006d0390001bbed4e752f013f01d24106410024'
    '61c2321fd17410005501588f4e7548e75000360030390001bd5872306100ffa6964030034cdf000a4a404e752f013039'
    '0001bd56e84072346100ff8a221f4ef900063e7248e7c0007000100372386100ff7436004cdf0003207c0001bb4f4e75'
    '4a39001816ba67084a39001816bb670653390001bbc34e754a39001816ba67084a39001816bb67064ef90005bd1e4e75'
    '4a39001816ba67084a39001816bb670c12390001ca294ef9000640b04ef9000640ec48e7808041fa0030701d425851c8'
    'fffc4cdf01014e750001bd760001bd660001bd780001bd680001bd7a0001bd6a0001bbee000000000000000000000000'
    '000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000'
    '00000000207c0001c9384ef90005df38207c000699b82c700600247006043c1e53461206e301287c0001bfb02a7c0001'
    'c0f038390006979a3a390006979c301e6a000004301ad04438c0301e6a000004301a904544403ac051ceffe42f0e267c'
    '0001c2302a7c0001bfb0287c0001c0f03a35100038341000302b0022c1c5e3804840362b0020c7c4e3834843d043e440'
    '064000803b801000302b0022c1c4e3804840362b0020c7c5e38348439043e440064000403980100055016ab44ef90006'
    '9610'
)
RUNTIME_SHA256 = '526c05b3894ec650f1529df7d9214c80caa81b7f46a7d48b70bdc1626bc70eb3'
TAIL_SHA256 = '30a842e3d36a385afcc46680e66f2d2826a2eb9aafe4adae5243998c3844429a'
OUTPUT_SHA256 = 'a0f94e01a3162fc3649f81526f76aac02200833b119f7e888e816aa1645e45d2'
HOOKS = [
    (0x60fdc, '30390001bcf6', '4ef900181336'),
    (0x61026, '30390001bcfc', '4ef900181358'),
    (0x60e50, '30390001bcea', '4ef90018137a'),
    (0x61130, '4eb90006180e', '4eb90018139c'),
    (0x61258, '4eb90006180e', '4eb90018139c'),
    (0x61380, '4eb90006180e', '4eb90018139c'),
    (0x5c902, '4eb9000605b6', '4eb9001813ae'),
    (0x5c97e, '53390001bbac', '4eb9001813e4'),
    (0x5d034, '52390001bbc9', '4ef900181466'),
    (0x5cfdc, '13fc0006000616d8', '4eb9001814ba4e71'),
    (0x6466c, '52000c000003', '4eb9001814d6'),
    (0x60d7a, '4eb900060fbe', '4eb9001814ee'),
    (0x5d42e, '103c0013207c0001c938', '4ef90018154a4e714e71'),
    (0x646be, 'd1390001bbe3', '4eb90018156c'),
    (0x615ac, '13fc0005000620b6', '4eb9001815744e71'),
    (0x633d4, '13fc000500063ee0', '4eb90018158e4e71'),
    (0x5cae2, '53390001bb41', '4eb9001815a8'),
    (0x5cb74, '33fc002000069ede', '4eb9001815c84e71'),
    (0x5d02e, '4ef90001b7b6', '4ef900181720'),
    (0x60d54, '4eb90005df32', '4eb9001819f4'),
    (0x635f2, '143c00ee67000006', '4ef90018173c4e71'),
    (0x6360a, '143c00ee67000006', '4ef90018175a4e71'),
    (0x63624, '143c00ee67000006', '4ef9001817784e71'),
    (0x6363c, '143c00ee67000006', '4ef9001817964e71'),
    (0x63656, '143c00ee67000006', '4ef9001817b44e71'),
    (0x6366e, '143c00ee67000006', '4ef9001817d24e71'),
    (0x630e4, '143c00ee67000006', '4ef9001817f04e71'),
    (0x62ef8, '143c00ee67000006', '4ef90018180e4e71'),
    (0x63440, '4eb90006180e', '4eb90018139c'),
    (0x634a8, '4eb90006180e', '4eb90018139c'),
    (0x63510, '4eb90006180e', '4eb90018139c'),
    (0x62df4, 'd0390001bbed', '4eb9001818b0'),
    (0x637de, 'd17410005501', '4eb9001818c6'),
    (0x63356, '90790001bd58', '4eb9001818de'),
    (0x6336a, '30390001bd56', '4ef9001818fc'),
    (0x63302, '207c0001bb4f', '4eb900181914'),
    (0x63238, '53390001bbc3', '4eb900181930'),
    (0x62ebc, '4eb90005bd1e', '4eb900181948'),
    (0x635aa, '12390001ca29', '4ef900181960'),
    (0x68aa2, 'e740207c000699b8', '4ef900181a004e71'),
]
# END GENERATED PATCH DATA

if __name__ == '__main__':
    main()
