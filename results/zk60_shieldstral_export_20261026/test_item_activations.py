import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
import write_item_activations as writer


class ItemActivations(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.content = self.root / 'content.ids'
        writer.private_write(self.content, b'1000,1001,1002')
        self.request = {'name': 'sexual-0', 'policy_id': 'shieldstral-1.0-3b-moderate-sexual/1',
                        'content_file': str(self.content), 'chunk_index': 0}

    def test_short_prompt_has_suffix_then_public_pad(self):
        item = writer.prepare_requests([self.request])[0]
        policy = writer.policies()[self.request['policy_id']]
        self.assertEqual(item['prompt'], policy.prefix + (1000, 1001, 1002, 4) + (11,) * 52)
        self.assertEqual(item['content_total'], 3)

    def test_native_full_tail_uses_original_post_total(self):
        self.content.write_text(','.join(str(1000 + i) for i in range(60)))
        request = {**self.request, 'chunk_index': 1}
        item = writer.prepare_requests([request])[0]
        self.assertEqual(item['chunk'], {'index': 1, 'start': 5, 'end': 60})
        self.assertEqual(item['content_total'], 60)
        self.assertEqual(item['prompt'][-56:], tuple(range(1005, 1060)) + (4,))

    def test_bad_private_tokens_cannot_become_a_prompt(self):
        for raw in (b'', b'1,1000', b'-1', b'131072', b'1000.0', b'1000,secret', b'\xff'):
            self.content.write_bytes(raw)
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                writer.prepare_requests([self.request])

    def test_request_cannot_replace_another_category_or_output(self):
        for changes in ({'name': '../elsewhere'}, {'policy_id': 'shieldstral-1.0-3b-card-unsafe/1'},
                        {'policy_id': 'shieldstral-1.0-3b-strict-sexual/1'}, {'chunk_index': True},
                        {'chunk_index': 1}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                writer.prepare_requests([{**self.request, **changes}])
        with self.assertRaises(ValueError):
            writer.prepare_requests([self.request, {**self.request, 'name': 'duplicate'}])

    def test_files_are_private_and_never_follow_symlinks_or_overwrite(self):
        self.assertEqual(stat.S_IMODE(self.content.stat().st_mode), 0o600)
        link = self.root / 'link'
        link.symlink_to(self.content)
        with self.assertRaises(OSError): writer.private_read(link, 65536)
        with self.assertRaises(FileExistsError): writer.private_write(self.content, b'replace')
        self.content.chmod(0o644)
        with self.assertRaises(ValueError): writer.private_read(self.content, 65536)

    def test_clamped_refusal_is_never_written_as_valid_int16(self):
        rec = writer.S2RecPos(1)
        source = np.array([[[40000., -32768.]]])
        clamped = rec.check('residual 2', source, -32768, 32767, 0, True)
        with self.assertRaises(ValueError): writer.checked_words(clamped, rec, source.shape)
        clean = writer.S2RecPos(1)
        x = np.array([[-32768., 32767.]])
        self.assertEqual(writer.checked_words(x, clean, (1, 2)).tobytes(), b'\x00\x80\xff\x7f')
        for bad in (np.array([[0.5, 0.]]), np.array([[np.nan, 0.]]), np.array([[32768., 0.]])):
            with self.assertRaises(ValueError): writer.checked_words(bad, clean, (1, 2))

    def test_changed_native_profile_refuses_before_any_output(self):
        request = self.root / 'request.json'
        writer.private_write(request, json.dumps([self.request]).encode())
        output = self.root / 'output'
        with patch.object(writer, 'PROFILE_SHA256', '00' * 32), self.assertRaises(ValueError):
            writer.write_sequences(request, output)
        self.assertFalse(output.exists())


if __name__ == '__main__': unittest.main()
