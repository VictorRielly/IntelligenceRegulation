"""Public fixture conversion boundaries, not a proof or model acceptance test."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import zk60_kernel_model as model


def fixture():
    records = ["zk60-kernel-fixture v1", "meta synthetic", "status ok"]
    for name, count, _ in model.LAYOUT:
        records.append("tensor " + name + " " + str(count) + " " + " ".join(["0"] * count))
    return "\n".join(records + ["tensor private_activation 2 111 222", "end"]) + "\n"


class ModelConversionTests(unittest.TestCase):
    def test_only_declared_public_weights_and_tables_are_exported(self):
        encoded = model.convert(fixture().encode())
        self.assertEqual(encoded, b"Z60MDL01" + bytes(model.MODEL_BYTES - 8))
        other = fixture().replace("private_activation 2 111 222", "private_activation 2 999 888")
        self.assertEqual(model.convert(other.encode()), encoded)

    def test_refused_duplicate_missing_out_of_range_and_trailing_records_refuse(self):
        valid = fixture()
        bad = [valid.replace("status ok", "status refused Range"),
               valid.replace("status ok", "status ok\nstatus ok"),
               valid.replace("tensor wq 256", "tensor wq 255"),
               valid.replace("tensor wq 256 0", "tensor wq 256 128", 1),
               valid.replace("tensor wq", "tensor absent", 1),
               valid.replace("end\n", "tensor wq 1 0\nend\n"),
               valid + "extra\n"]
        for data in bad:
            with self.subTest(case=bad.index(data)), self.assertRaises(ValueError):
                model.convert(data.encode())


if __name__ == "__main__":
    unittest.main()
