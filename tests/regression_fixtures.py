"""Read-only fixture preflight for the native 125M regression tests.

Presence, metadata consistency and byte sizes are checked here. Tensor hashes,
integer execution and frozen acceptance rows remain the native gate's job.
No tensors are copied, generated, hashed, or substituted by this helper.
"""

import json
import os
from pathlib import Path
import re


class FixtureConfigurationError(ValueError):
    """A requested regression fixture cannot be used; never a skip condition."""


_SHAPES = {
    "X": [512, 768], "WgT": [768, 2048],
    "WuT": [768, 2048], "WdT": [2048, 768],
}
_DIGEST = re.compile(r"[0-9a-f]{64}\Z")
_CANDIDATES = ("m125_ffn_export", "m125_ffn_export_wsl")


def _metadata_text(path):
    if not path.is_file() or not 0 < path.stat().st_size <= 131072:
        raise FixtureConfigurationError(f"missing or oversized metadata: {path}")
    return path.read_text(encoding="utf-8")


def validate_m125_fixture(directory):
    """Require all 12 layers of the fixed int8 512/768/2048 fixture.

    A weights-only directory or a single layer00 sentinel is not complete.
    This is a configuration check, not authentication or a native proof gate.
    """
    directory = Path(directory).resolve()
    try:
        manifest = json.loads(_metadata_text(directory / "manifest.json"))
        if not isinstance(manifest, dict) or manifest.get("shapes") != _SHAPES:
            raise FixtureConfigurationError("unsupported 125M fixture shapes")
        if any(type(dim) is not int for shape in manifest["shapes"].values() for dim in shape):
            raise FixtureConfigurationError("125M fixture dimensions must be integers")
        layers = manifest.get("layers")
        if not isinstance(layers, list) or len(layers) != 12:
            raise FixtureConfigurationError("125M fixture requires all 12 layers")
        if type(manifest.get("range_violations")) is not int or manifest["range_violations"] != 0:
            raise FixtureConfigurationError("125M fixture reports range violations")
        sidecar = {}
        for line in _metadata_text(directory / "digests.txt").splitlines():
            fields = line.split()
            if len(fields) < 3 or not fields[0].isdigit():
                raise FixtureConfigurationError("malformed 125M digest sidecar")
            key = (int(fields[0]), fields[1])
            if key in sidecar:
                raise FixtureConfigurationError("duplicate 125M sidecar entry")
            sidecar[key] = fields[2:]
        expected_keys = {(i, name) for i in range(12) for name in (*_SHAPES, "z", "shifts")}
        if set(sidecar) != expected_keys:
            raise FixtureConfigurationError("incomplete or unsupported 125M sidecar entries")
        for i, layer in enumerate(layers):
            if not isinstance(layer, dict) or type(layer.get("layer")) is not int or layer["layer"] != i:
                raise FixtureConfigurationError("125M fixture layer order/index mismatch")
            if type(layer.get("eW")) is not int or layer["eW"] != -9:
                raise FixtureConfigurationError("unsupported 125M weight exponent")
            digests, shifts, files = layer.get("digests"), layer.get("shifts"), layer.get("files")
            if not all(isinstance(value, dict) for value in (digests, shifts, files)):
                raise FixtureConfigurationError("missing 125M layer metadata")
            for name in (*_SHAPES, "z"):
                digest = digests.get(name)
                if not isinstance(digest, str) or not _DIGEST.fullmatch(digest) or sidecar[i, name] != [digest]:
                    raise FixtureConfigurationError("125M manifest/sidecar digest mismatch")
            shift_values = [shifts.get(name) for name in ("g", "u", "h", "z")]
            if any(type(value) is not int or not 0 <= value < 63 for value in shift_values):
                raise FixtureConfigurationError("unsupported 125M requant shift")
            if sidecar[i, "shifts"] != [str(value) for value in shift_values]:
                raise FixtureConfigurationError("125M manifest/sidecar shift mismatch")
            for name, shape in _SHAPES.items():
                filename = f"layer{i:02}_{name}.bin"
                if files.get(name) != filename:
                    raise FixtureConfigurationError("unsupported 125M tensor filename")
                tensor = directory / filename
                if not tensor.is_file() or tensor.stat().st_size != shape[0] * shape[1]:
                    raise FixtureConfigurationError(f"missing or wrong-size 125M tensor: {tensor}")
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise FixtureConfigurationError(f"unreadable 125M fixture metadata: {directory}") from error
    return directory


def select_m125_fixture(repo_root, environ=None):
    """Honor an explicit override, otherwise choose the first complete local set.

    Relative overrides are rooted at repo_root, independent of native cwd.
    Invalid explicit configuration NEVER falls back to another checkpoint.
    """
    env = os.environ if environ is None else environ
    root = Path(repo_root).resolve()
    if "ZK_MODEL_EXPORT_DIR" in env:
        raise FixtureConfigurationError(
            "ZK_MODEL_EXPORT_DIR overrides native M125 selection; unset it for 125M regression fixtures"
        )
    if "M125_EXPORT_DIR" in env:
        value = env["M125_EXPORT_DIR"]
        if not isinstance(value, str) or not value.strip():
            raise FixtureConfigurationError("M125_EXPORT_DIR must name a nonempty fixture directory")
        path = Path(value)
        if not path.is_absolute():
            path = root / path
        return validate_m125_fixture(path)
    failures = []
    for name in _CANDIDATES:
        path = root / "results" / name
        try:
            return validate_m125_fixture(path)
        except FixtureConfigurationError as error:
            failures.append(f"{name}: {error}")
    raise FixtureConfigurationError(
        "no complete local 125M regression fixture; set M125_EXPORT_DIR to an existing complete export. "
        + "; ".join(failures)
    )


def m125_environment(repo_root, environ=None):
    """Copy the environment and pin the selected absolute path for native calls."""
    env = dict(os.environ if environ is None else environ)
    env["M125_EXPORT_DIR"] = str(select_m125_fixture(repo_root, env))
    return env
