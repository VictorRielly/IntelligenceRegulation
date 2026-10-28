"""Lane entry point: run the staged tests/test_zk60_guard_fix.py against the candidate.

Before the swap the canonical tests (tests/test_zk60_guard_fix.py beside this file,
to be copied into the repository's tests/) would test the live guard by default.
This shim points them at the candidate and the retained pre-fix copy instead:
  GUARD_FIX_NEW = zk60_resource_guard.py.new, GUARD_FIX_OLD = zk60_resource_guard.py.orig
(either can still be overridden from the environment).  Arguments pass through to
unittest, e.g. `python3 test_guard_fix.py -v TestFifo`.
"""
import importlib.util
import os
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
os.environ.setdefault("GUARD_FIX_NEW", str(HERE / "zk60_resource_guard.py.new"))
os.environ.setdefault("GUARD_FIX_OLD", str(HERE / "zk60_resource_guard.py.orig"))
_spec = importlib.util.spec_from_file_location("test_zk60_guard_fix",
                                               HERE / "tests" / "test_zk60_guard_fix.py")
tests = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(tests)

if __name__ == "__main__":
    unittest.main(module=tests)
