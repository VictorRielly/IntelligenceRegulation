"""Tests for tools/demo_decode.py (round 10; round 11 review REVIEW6 TR7-3: the answer id is read
from the owner's 0600 token file, never passed on a command line)."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "demo_decode.py")


def run(*a):
    p = subprocess.run([sys.executable, TOOL, *a], capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def private_file(d, name, text, mode=0o600):
    p = os.path.join(d, name)
    fd = os.open(p, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    os.write(fd, text.encode())
    os.close(fd)
    os.chmod(p, mode)
    return p


class DemoDecode(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.mkdtemp(prefix="demo-decode-")

    def tearDown(self):
        shutil.rmtree(self.d)

    def test_the_answer_id_comes_from_the_owners_0600_token_file_round11(self):
        # TR7-3: the owner's `next_token` file (one id and a newline), mode 0600
        f = private_file(self.d, "next_token", "11\n")
        rc, out, err = run("llama3", "--id-file", f)
        self.assertEqual(rc, 0, err)
        self.assertEqual(json.loads(out)["text"], ",")
        f2 = private_file(self.d, "next_token_tl", "29914\n")
        rc, out, err = run("tinyllama", "--id-file", f2)
        self.assertEqual((rc, json.loads(out)["text"]), (0, "/"), err)
        # a token file readable by others is refused, and so is one holding more than one id
        loose = private_file(self.d, "loose", "11\n", 0o644)
        rc, out, err = run("llama3", "--id-file", loose)
        self.assertNotEqual(rc, 0)
        self.assertIn("0600", err + out)
        two = private_file(self.d, "two", "11 12\n")
        rc, out, err = run("llama3", "--id-file", two)
        self.assertNotEqual(rc, 0)

    def test_the_prompt_file_decodes_and_a_loose_one_is_refused(self):
        f = private_file(self.d, "prompt", "128000,791,4062\n")
        rc, out, err = run("llama3", "--ids-file", f)
        self.assertEqual(rc, 0, err)
        self.assertEqual(json.loads(out)["text"], "The quick")
        loose = private_file(self.d, "prompt-loose", "128000,791\n", 0o640)
        rc, _, _ = run("llama3", "--ids-file", loose)
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
