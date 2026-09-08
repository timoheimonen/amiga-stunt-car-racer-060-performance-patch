"""Standard-library tests; full disk tests use a separately supplied original."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch as mock_patch

import patch

ROOT = Path(__file__).resolve().parent
SOURCE = Path(os.environ.get('SCR_ADF', ROOT / 'originals/Stunt Car Racer.adf')).expanduser()
if 'SCR_ADF' in os.environ and not SOURCE.is_file():
    raise FileNotFoundError('SCR_ADF does not name an existing original ADF: ' + str(SOURCE))


class PatcherUnitTests(unittest.TestCase):
    def test_embedded_release_matches_manifest(self):
        manifest = json.loads((ROOT / 'src/patches.json').read_text())
        self.assertEqual(patch.VERSION, manifest['release_version'])
        self.assertEqual(patch.SOURCE_SHA256, manifest['source']['sha256'])
        self.assertEqual(patch.OUTPUT_SHA256, manifest['output']['sha256'])
        self.assertEqual(patch.OUTPUT_NAME, manifest['output']['name'])
        self.assertEqual(patch.DISK_SIZE, manifest['output']['size'])
        hooks = [(int(p['adf_offset'], 0), p['expected_hex'], p['replacement_hex'])
                 for p in manifest['patches']]
        self.assertEqual(patch.HOOKS, hooks)
        self.assertEqual(len(hooks), 75)
        for item in manifest['payloads']:
            payload = bytes.fromhex(getattr(patch, item['id'].upper() + '_HEX'))
            self.assertEqual(len(payload), item['size'])
            self.assertEqual(patch.sha256(payload), item['sha256'])
            self.assertTrue((ROOT / 'src' / item['source']).is_file())
        self.assertEqual(patch.TAIL_SHA256, manifest['payloads'][1]['expected_sha256'])

    def test_hook_address_mapping_and_dispatch(self):
        manifest = json.loads((ROOT / 'src/patches.json').read_text())
        for item in manifest['patches']:
            with self.subTest(hook=item['id']):
                adf = int(item['adf_offset'], 0)
                runtime = int(item['runtime_address'], 0)
                self.assertEqual(runtime, adf + 0xb00)
                self.assertEqual(runtime, int(item['game_file_offset'], 0) + 0xe700)
                old, new = bytes.fromhex(item['expected_hex']), bytes.fromhex(item['replacement_hex'])
                self.assertEqual(len(old), len(new))
                self.assertEqual(runtime % 2, 0)
                if 'dispatch_address' in item:
                    self.assertIn(new[:2], (bytes.fromhex('4eb9'), bytes.fromhex('4ef9')))
                    destination = int.from_bytes(new[2:6], 'big')
                    self.assertEqual(destination, int(item['dispatch_address'], 0))
                    if item['target'] == 'inline_color_masks060':
                        self.assertEqual(destination, 0x6770a)
                    elif item['target'] == 'word_call060':
                        self.assertEqual(destination, int(manifest['exports']['word_dispatch_local060'], 0))
                    else:
                        self.assertEqual(destination, int(manifest['exports'][item['target']], 0))
                        self.assertTrue(0x181000 <= destination < 0x181000 + 4004)
                else:
                    self.assertIn(runtime, {int(p['runtime_address'], 0)
                                            for p in manifest['assembly_patches']})

    def test_boot_memory_and_copy_contract(self):
        manifest = json.loads((ROOT / 'src/patches.json').read_text())
        expected = [(int(p['adf_offset'], 0), p['expected_hex'], p['replacement_hex'])
                    for p in manifest['boot_patches'] if int(p['adf_offset'], 0) != 4]
        self.assertEqual(patch.BOOT_HOOKS, expected)
        boot = bytes.fromhex(patch.BOOT_HEX)
        self.assertEqual(boot[0x1a:0x1e], bytes.fromhex('00009c00'))
        self.assertEqual((int.from_bytes(boot[0x64:0x66], 'big') + 1) * 2,
                         len(bytes.fromhex(patch.RUNTIME_HEX)))
        self.assertLessEqual(0x8b20 + len(bytes.fromhex(patch.RUNTIME_HEX)), 0x9c00)

    def test_reject_unknown_images(self):
        for data in (b'', b'bad', bytes(patch.DISK_SIZE), bytes(patch.DISK_SIZE - 1)):
            with self.subTest(size=len(data)), self.assertRaisesRegex(ValueError, 'Unsupported'):
                patch.patch_disk(data)

    def test_default_path_is_beside_source(self):
        source = Path('/some folder/original.adf')
        self.assertEqual(patch.default_output_path(source),
                         source.parent / 'StuntCarRacer-060-50FPS.adf')

    def test_cli_version_and_help(self):
        for option in ('--version', '--help'):
            run = subprocess.run([sys.executable, '-I', str(ROOT / 'patch.py'), option],
                                 capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertIn(patch.VERSION if option == '--version' else '--force', run.stdout)

    def test_bad_input_leaves_existing_output_untouched(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'bad.adf', Path(directory) / 'output.adf'
            source.write_bytes(b'bad')
            with self.assertRaises(ValueError):
                patch.write_disk(source, output)
            self.assertFalse(output.exists())
            output.write_bytes(b'keep')
            with self.assertRaises(ValueError):
                patch.write_disk(source, output, force=True)
            self.assertEqual(output.read_bytes(), b'keep')
            self.assertEqual(set(Path(directory).iterdir()), {source, output})

    def test_cli_missing_input_reports_error(self):
        with tempfile.TemporaryDirectory() as directory:
            run = subprocess.run([sys.executable, '-I', str(ROOT / 'patch.py'),
                                  str(Path(directory) / 'missing.adf')], capture_output=True, text=True)
            self.assertEqual(run.returncode, 1)
            self.assertIn('Error:', run.stderr)
            self.assertNotIn('Traceback', run.stderr)
            self.assertEqual(list(Path(directory).iterdir()), [])


@unittest.skipUnless(SOURCE.is_file(), 'Supply originals/Stunt Car Racer.adf or set SCR_ADF')
class OriginalImageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = SOURCE.read_bytes()
        cls.patched = patch.patch_disk(cls.original)

    def test_matches_0_4_0_disk(self):
        self.assertEqual(patch.sha256(self.patched),
                         'ef2fb22aa5789a6be96dd986babdb498772b0a8baf042e742dde092c1160c45a')
        self.assertEqual(self.patched, patch.patch_disk(self.original))
        self.assertEqual(len(self.patched), patch.DISK_SIZE)
        self.assertEqual(patch.boot_sum(self.patched), 0xffffffff)

    def test_secondary_clock_entry_is_preserved(self):
        runtime = bytes.fromhex(patch.RUNTIME_HEX)
        self.assertEqual(runtime[0x9f4:0x9fa], self.original[0x5d432:0x5d438])
        self.assertEqual(runtime[0x9fa:0xa00], bytes.fromhex('4ef90005df38'))
        self.assertEqual(self.patched[0x60d54:0x60d5a], bytes.fromhex('4eb9001819f4'))

    def test_only_documented_disk_ranges_change(self):
        manifest = json.loads((ROOT / 'src/patches.json').read_text())
        ranges = []
        for item in manifest['boot_patches'] + manifest['patches']:
            offset = int(item['adf_offset'], 0)
            old, new = bytes.fromhex(item['expected_hex']), bytes.fromhex(item['replacement_hex'])
            self.assertEqual(self.original[offset:offset + len(old)], old)
            self.assertEqual(self.patched[offset:offset + len(new)], new)
            ranges.append((offset, offset + len(new)))
        for item in manifest['payloads']:
            offset, size = int(item['adf_offset'], 0), item['size']
            ranges.append((offset, offset + size))
            self.assertEqual(patch.sha256(self.patched[offset:offset + size]), item['sha256'])
        previous = 0
        for start, end in sorted(ranges):
            self.assertGreaterEqual(start, previous, 'Overlapping patch ranges')
            self.assertEqual(self.original[previous:start], self.patched[previous:start])
            previous = end
        self.assertEqual(self.original[previous:], self.patched[previous:])
        game = manifest['source']['game_block']
        offset = int(game['adf_offset'], 0)
        self.assertEqual(patch.sha256(self.original[offset:offset + game['size']]), game['sha256'])

    def test_wrong_truncated_and_already_patched(self):
        corrupt = bytearray(self.original)
        corrupt[-1] ^= 1
        for invalid in (bytes(corrupt), self.original[:-1], self.patched):
            with self.subTest(size=len(invalid)), self.assertRaises(ValueError):
                patch.patch_disk(invalid)

    def test_corrupt_payloads_are_rejected(self):
        for name in ('BOOT_HEX', 'RUNTIME_HEX'):
            broken = 'ff' + getattr(patch, name)[2:]
            with mock_patch.object(patch, name, broken), self.assertRaisesRegex(ValueError, 'corrupt'):
                patch.patch_disk(self.original)

    def test_expected_hook_bytes_are_checked(self):
        offset, old, new = patch.HOOKS[0]
        hooks = [(offset, 'ff' + old[2:], new)] + patch.HOOKS[1:]
        with mock_patch.object(patch, 'HOOKS', hooks), self.assertRaisesRegex(ValueError, 'Original bytes'):
            patch.patch_disk(self.original)

    def test_bad_replacement_fails_output_hash(self):
        offset, old, new = patch.HOOKS[0]
        hooks = [(offset, old, 'ff' + new[2:])] + patch.HOOKS[1:]
        with mock_patch.object(patch, 'HOOKS', hooks), self.assertRaisesRegex(ValueError, 'verification failed'):
            patch.patch_disk(self.original)

    def test_force_replaces_only_output(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'original.adf', Path(directory) / 'output.adf'
            source.write_bytes(self.original)
            patch.write_disk(source, output)
            self.assertEqual(output.read_bytes(), self.patched)
            output.write_bytes(b'keep')
            with self.assertRaises(FileExistsError):
                patch.write_disk(source, output)
            self.assertEqual(output.read_bytes(), b'keep')
            patch.write_disk(source, output, force=True)
            self.assertEqual(source.read_bytes(), self.original)
            self.assertEqual(output.read_bytes(), self.patched)
            self.assertEqual(set(Path(directory).iterdir()), {source, output})

    def test_source_aliases_are_protected_even_with_force(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'original.adf'
            source.write_bytes(self.original)
            symlink, hardlink = Path(directory) / 'symlink.adf', Path(directory) / 'hardlink.adf'
            symlink.symlink_to(source)
            os.link(source, hardlink)
            for output in (source, symlink, hardlink):
                with self.subTest(path=output), self.assertRaisesRegex(ValueError, 'original ADF'):
                    patch.write_disk(source, output, force=True)
            self.assertEqual(source.read_bytes(), self.original)

    def test_output_symlinks_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source, other, output = (Path(directory) / n for n in ('source.adf', 'other.adf', 'out.adf'))
            source.write_bytes(self.original)
            other.write_bytes(b'keep')
            output.symlink_to(other)
            with self.assertRaisesRegex(ValueError, 'symbolic link'):
                patch.write_disk(source, output, force=True)
            self.assertEqual(other.read_bytes(), b'keep')
            other.unlink()
            with self.assertRaisesRegex(ValueError, 'symbolic link'):
                patch.write_disk(source, output)
            self.assertFalse(other.exists())

    def test_destination_created_during_write_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'source.adf', Path(directory) / 'out.adf'
            source.write_bytes(self.original)
            real_link = os.link

            def competing_link(temporary, destination):
                destination.write_bytes(b'another writer')
                return real_link(temporary, destination)

            with mock_patch.object(patch.os, 'link', side_effect=competing_link):
                with self.assertRaises(FileExistsError):
                    patch.write_disk(source, output)
            self.assertEqual(output.read_bytes(), b'another writer')
            self.assertEqual(set(Path(directory).iterdir()), {source, output})

    def test_failed_publication_cleans_temporary_file(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'source.adf', Path(directory) / 'out.adf'
            source.write_bytes(self.original)
            output.write_bytes(b'keep')
            with mock_patch.object(patch.os, 'replace', side_effect=OSError('disk error')):
                with self.assertRaises(OSError):
                    patch.write_disk(source, output, force=True)
            self.assertEqual(output.read_bytes(), b'keep')
            self.assertEqual(set(Path(directory).iterdir()), {source, output})

    def test_standalone_cli_and_default_location(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            script = folder / 'patch.py'
            script.write_bytes((ROOT / 'patch.py').read_bytes())
            source = folder / 'input with spaces' / 'original.adf'
            source.parent.mkdir()
            source.write_bytes(self.original)
            command = [sys.executable, '-I', str(script), str(source)]
            run = subprocess.run(command, cwd=folder, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual((source.parent / patch.OUTPUT_NAME).read_bytes(), self.patched)
            self.assertFalse((folder / patch.OUTPUT_NAME).exists())
            output = folder / 'nested output' / 'result.adf'
            explicit = command + ['--output', str(output)]
            self.assertEqual(subprocess.run(explicit, capture_output=True).returncode, 0)
            self.assertEqual(subprocess.run(explicit, capture_output=True).returncode, 1)
            self.assertEqual(subprocess.run(explicit + ['--force'], capture_output=True).returncode, 0)
            self.assertEqual(output.read_bytes(), self.patched)
            same = subprocess.run(command + ['-o', str(source), '--force'], capture_output=True)
            self.assertEqual(same.returncode, 1)
            self.assertEqual(source.read_bytes(), self.original)


if __name__ == '__main__':
    unittest.main()
