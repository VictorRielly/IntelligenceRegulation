import hashlib
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

path = Path(__file__).with_name('validate_capture_v4.py')
spec = importlib.util.spec_from_file_location('capture_v3', path)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


class CaptureStreamTests(unittest.TestCase):
    def test_whole_array_and_both_extension_limbs_across_chunks(self):
        raw = b''.join(struct.pack('<QQ', i, validator.P - i - 1) for i in range(17001))
        with tempfile.TemporaryFile() as blob:
            blob.write(b'prefix00' + raw + b'trailer0')
            validator.stream_array(blob, 8, len(raw), hashlib.sha256(raw).hexdigest())
            blob.seek(8 + validator.CHUNK_BYTES + 16)
            blob.write(struct.pack('<Q', 37))
            with self.assertRaisesRegex(AssertionError, 'array hash'):
                validator.stream_array(blob, 8, len(raw), hashlib.sha256(raw).hexdigest())

    def test_noncanonical_second_chunk_even_with_matching_hash(self):
        raw = bytearray(struct.pack('<Q', 1) * 17001)
        struct.pack_into('<Q', raw, validator.CHUNK_BYTES + 8, validator.P)
        with tempfile.TemporaryFile() as blob:
            blob.write(raw)
            with self.assertRaisesRegex(AssertionError, 'noncanonical'):
                validator.stream_array(blob, 0, len(raw), hashlib.sha256(raw).hexdigest())

    def test_short_and_unaligned_array_refuse(self):
        with tempfile.TemporaryFile() as blob:
            blob.write(b'\0' * 16)
            with self.assertRaisesRegex(AssertionError, 'short'):
                validator.stream_array(blob, 0, 24, hashlib.sha256(b'\0' * 24).hexdigest())
            for start, size in [(1, 8), (0, 7), (-8, 8)]:
                with self.assertRaises(AssertionError):
                    validator.stream_array(blob, start, size, '')

    def test_receipt_digest_covers_middle_with_header_and_short_final_chunk(self):
        raw = bytes(range(256)) * 512 + b'z'
        with tempfile.TemporaryDirectory() as tmp:
            frame = Path(tmp) / 'frame.bin'
            frame.write_bytes(raw)
            size, digest, head, tail = validator.stream_frame(frame)
            self.assertEqual((size, digest, head, tail),
                             (len(raw), hashlib.sha256(raw).hexdigest(), raw[:248], raw[-32:]))
            changed = bytearray(raw)
            changed[validator.CHUNK_BYTES + 13] ^= 1
            frame.write_bytes(changed)
            self.assertNotEqual(validator.stream_frame(frame)[1], digest)


if __name__ == '__main__':
    unittest.main()
