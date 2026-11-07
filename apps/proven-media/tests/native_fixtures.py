"""Explicit non-executable binary fixtures for mocked app transport tests.

These tests never run a native prover. Keep Deployment.validate and all model,
profile, policy and hash checks active while replacing the absent executable
with temporary bytes and their real digest. This is not native validation.
"""
from contextlib import contextmanager, ExitStack
import hashlib
from pathlib import Path
import tempfile
from unittest.mock import patch

from proven_media import shieldstral_runtime as runtime


def use_context(test, context):
    """TestCase.enterContext equivalent for the original Python 3.10 host."""
    value = context.__enter__()
    test.addCleanup(context.__exit__, None, None, None)
    return value


@contextmanager
def native_binary_fixture():
    with tempfile.TemporaryDirectory(prefix='pm-simulated-native-') as directory, ExitStack() as stack:
        binary = Path(directory).resolve()/'NOT-A-NATIVE-PROVER'
        binary.write_bytes(b'TEST FIXTURE ONLY: native execution must be mocked\n')
        digest = hashlib.sha256(binary.read_bytes()).hexdigest()
        stack.enter_context(patch.object(runtime, 'BINARY', binary))
        stack.enter_context(patch.object(runtime, 'BINARY_SHA', digest))
        yield binary
