import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from proven_media import w16r2_export
from proven_media.provers import ProverError
from tools import prepare_w16r2_verifier as verifier_kit


class PublicExportTest(unittest.TestCase):
    def test_failed_copy_can_retry_and_only_manifest_files_are_published(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            source, destination = root/'source', root/'public'/'export'
            def store(name, data):
                path = source/name
                path.parent.mkdir(parents=True,exist_ok=True)
                raw = data if isinstance(data,bytes) else json.dumps(data).encode()
                path.write_bytes(raw)
                return hashlib.sha256(raw).hexdigest()
            rotation = store('rotation_sign.bin',b'rotation')
            weight = store('layer_00/weight.bin',b'weights')
            manifest = store('layer_00/manifest.json',{'arrays':{'weight':{'file':'weight.bin','sha256':weight}}})
            checkpoint = b'synthetic public weights'
            profile = store('profile.json',{'layers':[{'layer':0,'dir':'layer_00','manifest_sha256':manifest}],
                                            'model':{'sha256':hashlib.sha256(checkpoint).hexdigest()}})
            token = store('token_io/token_io.json',{'rotation':{'sign_sha256':rotation}})
            tables = store('token_io/complete.json',{'profile_sha256':profile,'files':{'token_io.json':token}})
            store('seq_000/input.bin',b'sequence')
            store('layer_00/unused.bin',b'unlisted')
            store('token_io/unused.json',b'unlisted')
            store('layer_00/weight.bin',b'truncated')
            with patch.object(w16r2_export,'TABLE_MANIFEST_SHA',tables):
                with self.assertRaisesRegex(ProverError,'copied public model file'):
                    w16r2_export.prepare(source,destination,profile)
                self.assertFalse(destination.exists())
                store('layer_00/weight.bin',b'weights')
                w16r2_export.prepare(source,destination,profile)
                w16r2_export.prepare(source,destination,profile)
            self.assertEqual({p.relative_to(destination).as_posix() for p in destination.rglob('*') if p.is_file()},
                {'profile.json','rotation_sign.bin','layer_00/weight.bin','layer_00/manifest.json',
                 'token_io/complete.json','token_io/token_io.json'})
            self.assertFalse((source/'layer_00/weight.bin').samefile(destination/'layer_00/weight.bin'))

            model = root / 'models' / w16r2_export.CHECKPOINT
            model.parent.mkdir(parents=True)
            model.write_bytes(checkpoint)
            binary = root / 'fixture-bin'
            binary.write_bytes(b'public verifier fixture, never executed')
            authority = {'binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest()}
            kit = root / 'new kit'
            with (patch.object(w16r2_export, 'TABLE_MANIFEST_SHA', tables),
                  patch.object(verifier_kit.runtime, 'authority', return_value=authority),
                  patch.multiple(verifier_kit.runtime, BINARY=binary, EXPORT=source, PROFILE_SHA=profile),
                  patch.object(verifier_kit.runtime.baseline, 'NATIVE_MODELS', root / 'models')):
                prepared = verifier_kit.prepare(kit)
                self.assertEqual(prepared['files'], 8)
                moved = kit.rename(root / 'relocated')
                self.assertEqual(verifier_kit.check(moved), prepared)
                with self.assertRaisesRegex(ValueError, 'new directory'):
                    verifier_kit.prepare(moved)
                extra = moved / 'export' / 'extra'
                extra.write_bytes(b'unlisted file')
                with self.assertRaisesRegex(ValueError, 'unexpected or missing'):
                    verifier_kit.check(moved)
                extra.unlink()
                packaged_model = moved / 'models' / w16r2_export.CHECKPOINT
                packaged_model.unlink()
                packaged_model.symlink_to(model)
                with self.assertRaisesRegex(ValueError, 'digest or file type'):
                    verifier_kit.check(moved)
                model.write_bytes(b'different weights')
                with self.assertRaisesRegex(ValueError, 'digest or file type'):
                    verifier_kit.prepare(kit)
                self.assertFalse(kit.exists())
