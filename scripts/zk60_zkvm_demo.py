#!/usr/bin/env python3
"""Local runner for the separately versioned zkVM experiments (block, token).

Drives one explicitly selected profile's prebuilt host and wrap binaries
(``--profile block``, the default: zkvm-block/ ``zk60-block-{host,wrap}``;
``--profile token``: zkvm-model/ ``zk60-token-{host,wrap}``) through: prepare
-> execute -> prove to a PRIVATE inner receipt -> local Groth16 wrap to a
PUBLIC receipt -> fresh-process verification -> rejection controls -> a
privacy `secret-scan` of everything published or logged. The block profile
proves one fixed T32/d16/f16 block; the token profile one synthetic
(untrained) two-block greedy next token, which stays private. Neither is the
model-scale MVP, and nothing either records is a benchmark.

The last stage checks for accidental literal disclosure: the run's own private values (both
salts, the input words, the output words and the whole request), each as raw
bytes and as its SHA-256 in three encodings, are searched for as byte
substrings in every regular file of the public directory and in every file the
runner writes outside `private/` (the logs and its own bookkeeping). A hit, or
a file too large to read, fails the run; only marker kinds, file labels and
counts are recorded only in the private run status. A private value is never written anywhere by that
stage, and the scan is evidence of absence only for the files it actually
read. A clean scan does not establish cryptographic zero knowledge.

Standard library only. It never builds, downloads or selects a cloud prover:
every binary, the r0vm server and the extracted native Groth16 tools are
explicit prerequisites. Heavy stages hold /tmp/zk-heavy.lock (repository
no-hangup protocol) and every child runs in its own process group under a
bounded timeout. See docs/zkmatrix-poc/ZK60_ZKVM_DEMO.md.
"""
import argparse
import fcntl
import hashlib
import json
import math
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile
import time

SCHEMA = 2
POLICY_BYTES = 144
# Both profiles share the statement layout: 16-byte profile tag, then context,
# model, input, output (32 bytes each). Only the tag and the hashing differ.
POLICY_FIELDS = (("profile", 0), ("context", 16), ("model", 48), ("input", 80),
                 ("output", 112))
PROFILES = {
    "block": {
        "tag": b"zk60-r0-block-v1",
        "experiment": "zk60-zkvm-complete-block",
        "coverage": "one fixed T32/d16/f16 integer transformer block, "
                    "reexecuted in the RISC Zero zkVM",
        "model_magic": b"Z60MDL01", "model_bytes": 6184,
        "input_bytes": 1024, "input_desc": "512 LE i16",
        "request_bytes": 1136, "output_bytes": 1024,
        "private_output": "output.i16",
        # zk60-block-{host,wrap} verify take no image argument; they check
        # their compiled image, which the runner binds by querying image-id.
        "verify_takes_image": False,
    },
    "token": {
        "tag": b"zk60-r0-token-v1",
        "experiment": "zk60-zkvm-token-model",
        "coverage": "synthetic-T32-V32-two-block-greedy-token: one greedy next "
                    "token of a fixed synthetic (untrained) two-block integer "
                    "model, reexecuted in the RISC Zero zkVM; the token stays private",
        "model_magic": b"Z60TOK01", "model_bytes": 13928,
        "input_bytes": 128, "input_desc": "32 LE u32 token IDs in 0..31",
        "request_bytes": 240, "output_bytes": 4,
        "private_output": "output.u32",
        # zk60-token-{host,wrap} verify REQUIRE the approved image id last.
        "verify_takes_image": True,
    },
}
DEFAULT_PROFILE = "block"
# Block-profile constants, kept for existing callers.
MODEL_MAGIC = PROFILES["block"]["model_magic"]
MODEL_BYTES = PROFILES["block"]["model_bytes"]
INPUT_BYTES = PROFILES["block"]["input_bytes"]
IMAGE_ID_RE = re.compile(r"[0-9a-f]{64}")
NATIVE_FILES = ("prover", "stark_verify", "stark_verify.dat", "stark_verify.cs",
                "stark_verify_final.pk.dmp")
NATIVE_EXECUTABLES = ("prover", "stark_verify")
PUBLIC_INPUTS = ("model.bin", "policy.bin")
PUBLIC_RECEIPT = "receipt.bin"
PUBLIC_MANIFEST = "outcome.json"
DEFAULT_LOCK = "/tmp/zk-heavy.lock"
# Covers the token CLIs' refusal of RISC0_DEV_MODE, RISC0_PROVER and BONSAI_*.
SCRUBBED_PREFIXES = ("HL_", "BONSAI_", "RISC0_", "RUST_LOG")
ACCEPTANCE_FLAGS = (
    "prepared",
    "execution_matches_policy",
    "inner_receipt_verified_privately",
    "groth16_wrapped",
    "groth16_verified_fresh_process",
    "wrong_policy_rejected",
    "inner_receipt_refused_by_public_verifier",
    "malformed_receipts_rejected",
    "public_directory_audited",
    "public_secret_scan_clean",
)
# Only a verifier that takes the image id as an argument can be shown to
# refuse a wrong one.
TOKEN_ACCEPTANCE_FLAGS = (ACCEPTANCE_FLAGS[:-2] + ("wrong_image_id_rejected",)
                          + ACCEPTANCE_FLAGS[-2:])
# P1 privacy evidence (secret-scan). Every private value of the run becomes a
# search needle; a raw value shorter than MIN_RAW_MARKER_BYTES (the token
# profile's 4-byte output) would match by chance, so only its digests are used.
SECRET_MARKER_VALUES = ("input_salt", "output_salt", "input_words",
                        "output_words", "request")
SALT_OFFSETS = {"input_salt": (48, 80), "output_salt": (80, 112)}
REQUEST_WORDS_AT = 112
MIN_RAW_MARKER_BYTES = 8
SCAN_MAX_BYTES = 64 * 1024 * 1024   # a larger file is reported unscanned, and fails
SCAN_CHUNK_BYTES = 1024 * 1024
DEFAULT_TIMEOUTS = {"short": 600, "prepare": 600, "execute": 3600, "prove": 14400,
                    "wrap": 14400, "hash": 3600}
KILL_GRACE = 10.0


class RunnerError(Exception):
    """Fail-closed stop: a precondition, stage, control or audit did not hold."""


class Interrupted(RunnerError):
    """The runner itself received SIGTERM/SIGHUP/SIGINT."""


# ---- profiles and image ids ------------------------------------------------
def acceptance_flags(profile):
    return TOKEN_ACCEPTANCE_FLAGS if PROFILES[profile]["verify_takes_image"] else ACCEPTANCE_FLAGS


def not_claimed(profile):
    """Claims no run of this runner makes, whatever its outcome."""
    claims = {"model_mvp_complete": False, "model_scale_mvp": False, "trained_model": False,
              "d7_accepted": False, "benchmark": False}
    if profile == "block":
        claims["token_generation"] = False
    else:
        claims["token_disclosed"] = False
    return claims


def image_id_arg(value):
    """An image id supplied by the caller: exactly 64 lowercase hex characters."""
    if not isinstance(value, str) or not IMAGE_ID_RE.fullmatch(value):
        raise RunnerError("image ids must be exactly 64 lowercase hex characters")
    return value


def verify_command(profile, binary, policy, receipt, image_id):
    """A profile's verify invocation. The image id is the caller's pin or the
    pre-prepare queried one, never anything read from a receipt."""
    command = [binary, "verify", policy, receipt]
    if PROFILES[profile]["verify_takes_image"]:
        command.append(image_id_arg(image_id))
    return command


# ---- filesystem safety ---------------------------------------------------
def new_destination(path):
    """Absolute path for a directory that must not exist yet.

    The leaf must be absent (not even a dangling symlink) and the parent must be
    an existing real directory reached without symlinks, so the path we check is
    the path the Rust binaries will create.
    """
    path = Path(os.path.abspath(path))
    if os.path.lexists(path):
        raise RunnerError(f"destination already exists (refusing to overwrite): {path}")
    parent = path.parent
    if not parent.is_dir():
        raise RunnerError(f"destination parent is not a directory: {parent}")
    if os.path.realpath(parent) != str(parent):
        raise RunnerError(f"destination parent is reached through a symlink: {parent}")
    return path


def nested(a, b):
    """True if either path equals or lies inside the other."""
    a, b = Path(a), Path(b)
    return a == b or a in b.parents or b in a.parents


def check_disjoint(public, private_areas):
    for area in private_areas:
        if nested(public, area):
            raise RunnerError("public and private destinations must be disjoint")


def regular_file(path, what, executable=False):
    path = Path(os.path.abspath(path))
    try:
        info = os.stat(path)
    except OSError as exc:
        raise RunnerError(f"{what} missing: {path}: {exc.strerror}") from None
    if not stat.S_ISREG(info.st_mode):
        raise RunnerError(f"{what} is not a regular file: {path}")
    if executable and not os.access(path, os.X_OK):
        raise RunnerError(f"{what} is not executable: {path}")
    return Path(os.path.realpath(path))


def real_directory(path, what):
    """Existing directory that is not itself a symlink."""
    path = Path(path)
    try:
        info = os.lstat(path)
    except OSError:
        raise RunnerError(f"{what} missing: {path}") from None
    if not stat.S_ISDIR(info.st_mode):
        raise RunnerError(f"{what} is not a real directory (symlink?): {path}")
    return info


def write_new(path, data, mode):
    """Create a file that must not exist; never follows a symlink."""
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    fd = os.open(path, flags, mode)
    try:
        os.fchmod(fd, mode)  # exact mode regardless of umask
        with os.fdopen(fd, "wb", closefd=False) as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
    finally:
        os.close(fd)


def write_private_json(path, value):
    """Atomically replace a private (0600) JSON bookkeeping file."""
    path = Path(path)
    tmp = path.with_name(path.name + ".tmp")
    if os.path.lexists(tmp):
        os.unlink(tmp)
    write_new(tmp, (json.dumps(value, indent=2, sort_keys=True) + "\n").encode(), 0o600)
    os.replace(tmp, path)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def audit_public(public, allowed):
    """The public directory holds exactly `allowed`, all regular files."""
    real_directory(public, "public directory")
    names = set(os.listdir(public))
    if names != set(allowed):
        raise RunnerError(f"public directory holds {sorted(names)}, expected {sorted(allowed)}")
    for name in names:
        if not stat.S_ISREG(os.lstat(Path(public) / name).st_mode):
            raise RunnerError(f"public entry is not a regular file: {name}")


def check_private_mode(path, what):
    info = real_directory(path, what)
    if stat.S_IMODE(info.st_mode) & 0o077:
        raise RunnerError(f"{what} is accessible to group/other")


# ---- P1 privacy evidence: the secret scan --------------------------------
def read_limited(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as source:
        info = os.fstat(source.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise RunnerError("secret scan: private file type/size refused")
        data = source.read(limit + 1)
        if len(data) > limit:
            raise RunnerError("secret scan: private file grew beyond size limit")
        return data


def secret_markers(request, output, input_bytes):
    """Search needles for one run's private values, built from the private files.

    The values are the input salt, the output salt, the input words, the output
    words and the whole request. Each contributes its SHA-256 as raw bytes and
    as lowercase and uppercase hex ASCII, plus its raw bytes when they are at
    least MIN_RAW_MARKER_BYTES long (a 4-byte token output would otherwise
    match padding by chance). Returns (markers, skipped_raw, values_covered):
    a list of (kind, needle) pairs, how many raw values were too short to
    search for, and how many of SECRET_MARKER_VALUES produced any needle.

    The needles are secrets. They are returned for searching only; no caller
    may record, log or publish one, and nothing derived from them but a kind
    name and a count leaves this module.
    """
    values = [(kind, request[a:b]) for kind, (a, b) in SALT_OFFSETS.items()]
    values.append(("input_words", request[REQUEST_WORDS_AT:REQUEST_WORDS_AT + input_bytes]))
    values.append(("output_words", output))
    values.append(("request", request))
    markers, skipped, covered, seen = [], 0, 0, set()
    for kind, value in values:
        if not value:
            skipped += 1          # nothing to search for; not covered at all
            continue
        forms = []
        if len(value) >= MIN_RAW_MARKER_BYTES:
            forms.append((kind, value))
        else:
            skipped += 1
        digest = hashlib.sha256(value).digest()
        forms += [(kind + "_sha256", digest),
                  (kind + "_sha256_hex_lower", digest.hex().encode()),
                  (kind + "_sha256_hex_upper", digest.hex().upper().encode())]
        covered += 1
        for name, needle in forms:
            if needle not in seen:       # two equal values search once
                seen.add(needle)
                markers.append((name, needle))
    return markers, skipped, covered


def scan_one_file(path, markers, overlap, chunk=SCAN_CHUNK_BYTES, limit=None):
    """Marker kinds present in one regular file, read `chunk` bytes at a time.

    Consecutive windows overlap by `overlap`, so a marker split across two
    reads is still found. Opened O_NOFOLLOW: a symlink swapped in after the
    caller's lstat is refused rather than followed.
    """
    found = []
    limit = SCAN_MAX_BYTES if limit is None else limit
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, "rb") as f:
        info = os.fstat(f.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            raise RunnerError("secret scan: opened file type/size refused")
        tail, total = b"", 0
        while True:
            data = f.read(min(chunk, limit - total + 1))
            if not data:
                break
            total += len(data)
            if total > limit:
                raise RunnerError("secret scan: file grew beyond size limit")
            window = tail + data
            for kind, needle in markers:
                if kind not in found and needle in window:
                    found.append(kind)
            tail = window[-overlap:] if overlap else b""
    return found


def scan_targets(layout):
    """Every file the runner publishes or writes outside the private directory.

    That is the public directory, the runner's logs and the run's own
    bookkeeping files, as (label, path) pairs. Labels are short and relative,
    so no absolute path of a run can reach the public manifest. The private
    directory, which legitimately holds the secrets, is never scanned.
    """
    targets = []

    def walk(root, label):
        for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
            dirnames.sort()
            for name in sorted(filenames):
                path = Path(dirpath) / name
                targets.append((f"{label}/{os.path.relpath(path, root)}", path))

    for root, label in ((layout.public, "public"), (layout.logs, "logs")):
        if os.path.isdir(root) and not os.path.islink(root):
            walk(root, label)
    if os.path.isdir(layout.out):
        for name in sorted(os.listdir(layout.out)):
            path = layout.out / name
            if stat.S_ISREG(os.lstat(path).st_mode):
                targets.append((f"run/{name}", path))
    return targets


def scan_for_markers(targets, markers, limit=None):
    """Search `targets` for `markers`; returns (files_scanned, found, not_scanned).

    `found` entries name only the marker kind and the file label, never a
    value. A file over the size limit, one that cannot be read, or one that is
    no longer a regular file is listed in `not_scanned` instead: bytes that
    were not read are not evidence, so the caller fails the stage.
    """
    if not markers:
        raise RunnerError("secret scan: no markers to search for")
    limit = SCAN_MAX_BYTES if limit is None else limit
    overlap = max(len(needle) for _, needle in markers) - 1
    scanned, found, not_scanned = 0, [], []
    for label, path in targets:
        try:
            info = os.lstat(path)
        except OSError:
            not_scanned.append(label)
            continue
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit:
            not_scanned.append(label)
            continue
        try:
            kinds = scan_one_file(path, markers, overlap, limit=limit)
        except (OSError, RunnerError):
            not_scanned.append(label)
            continue
        scanned += 1
        found += [{"marker": kind, "file": label} for kind in kinds]
    return scanned, found, not_scanned


# ---- process control -----------------------------------------------------
def scrubbed_env(threads):
    """Drop prover/cloud/debug switches (BONSAI_*, RISC0_*, HL_*, RUST_LOG)."""
    env = {k: v for k, v in os.environ.items() if not k.startswith(SCRUBBED_PREFIXES)}
    removed = sorted(k for k in os.environ if k.startswith(SCRUBBED_PREFIXES))
    for key in ("RAYON_NUM_THREADS", "OMP_NUM_THREADS", "GOMAXPROCS"):
        env[key] = str(threads)
    return env, removed


def _exited(pid):
    """Has `pid` exited? Leaves it unreaped, so its pid/pgid cannot be reused."""
    info = os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT)
    return info is not None


def _signal_group(pgid, sig):
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        pass


def run_bounded(command, log_path, env, timeout, cwd, grace=KILL_GRACE):
    """Run one child in a new session with output to a private 0600 log.

    Returns (exit_code, timed_out). On timeout, or if the runner is
    interrupted, the whole process group gets SIGTERM, then SIGKILL after
    `grace`, before the leader is reaped. Stragglers left in the group after a
    normal exit are killed too.
    """
    fd = os.open(log_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        proc = subprocess.Popen([str(c) for c in command], cwd=str(cwd), env=env,
                                stdin=subprocess.DEVNULL, stdout=fd, stderr=fd,
                                start_new_session=True, close_fds=True)
    finally:
        os.close(fd)
    pgid = proc.pid  # start_new_session makes the child its group leader
    deadline = time.monotonic() + timeout
    timed_out = False
    try:
        delay = 0.02
        while not _exited(proc.pid):
            if time.monotonic() >= deadline:
                timed_out = True
                break
            time.sleep(min(delay, max(0.0, deadline - time.monotonic())))
            delay = min(delay * 2, 1.0)
        if timed_out:
            _signal_group(pgid, signal.SIGTERM)
            stop = time.monotonic() + grace
            while not _exited(proc.pid) and time.monotonic() < stop:
                time.sleep(0.05)
    except BaseException:
        _signal_group(pgid, signal.SIGKILL)
        proc.wait()
        raise
    _signal_group(pgid, signal.SIGKILL)
    code = proc.wait()
    return code, timed_out


def _raise_interrupted(signum, _frame):
    raise Interrupted(f"runner received signal {signum}")


def preflight(c):
    """Every prerequisite is explicit; nothing is built or downloaded here."""
    if c.get("profile") not in PROFILES:
        raise RunnerError(f"unknown profile: {c.get('profile')!r}")
    p = PROFILES[c["profile"]]
    if c.get("expected_image_id") is not None:
        image_id_arg(c["expected_image_id"])
    for key in ("host", "wrap", "r0vm"):
        regular_file(c[key], key, executable=True)
    size, magic = p["model_bytes"], p["model_magic"]
    model = regular_file(c["model"], "MODEL_BIN")
    if model.stat().st_size != size:
        raise RunnerError(f"{c['profile']} MODEL_BIN must be exactly {size} bytes")
    with model.open("rb") as source:
        data = source.read(size + 1)
    if len(data) != size or not data.startswith(magic):
        raise RunnerError(f"{c['profile']} MODEL_BIN must be {size} bytes starting "
                          f"{magic.decode()}")
    if c.get("input"):
        if regular_file(c["input"], "owner input").stat().st_size != p["input_bytes"]:
            raise RunnerError(f"{c['profile']} owner input must be exactly "
                              f"{p['input_bytes']} bytes ({p['input_desc']})")
    tools = Path(c["native_tools"])
    if not tools.is_dir():
        raise RunnerError(f"native tools directory missing: {tools}")
    for name in NATIVE_FILES:
        regular_file(tools / name, f"native tool {name}", executable=name in NATIVE_EXECUTABLES)


# ---- the run -------------------------------------------------------------
class Layout:
    """All paths of one run, derived from the new output directory."""

    def __init__(self, out, public=None):
        self.out = Path(out)
        self.public = Path(public) if public is not None else self.out / "public"
        self.private = self.out / "private"      # created 0700 by the host
        self.logs = self.out / "logs"            # runner, 0700
        self.controls = self.private / "controls"
        self.wrap_work = self.private / "wrap-work"
        self.request = self.private / "request.bin"
        self.inner = self.private / "inner.bin"
        self.config = self.out / "config.json"
        self.status = self.out / "status.json"
        self.done = self.out / "run.done"


class Runner:
    def __init__(self, config, lock_path=DEFAULT_LOCK, grace=KILL_GRACE):
        self.c = config
        # Configs written before profiles existed are block runs.
        self.profile = config.get("profile") or DEFAULT_PROFILE
        if self.profile not in PROFILES:
            raise RunnerError(f"unknown profile: {self.profile!r}")
        self.c["profile"] = self.profile
        self.p = PROFILES[self.profile]
        self.layout = Layout(config["out"], config["public"])
        self.lock_path = lock_path
        self.grace = grace
        self.env, removed = scrubbed_env(config["threads"])
        self.timeouts = dict(DEFAULT_TIMEOUTS, **config.get("timeouts", {}))
        self.flags = {k: False for k in acceptance_flags(self.profile)}
        self.image_id = None     # set only once host == wrap (== the pin, if any)
        self.reported_ids = {}   # what each binary's image-id printed, if well formed
        self.secret_scan_record = None   # counts and kinds only; never a value
        self.status = {"schema": SCHEMA, "profile": self.profile, "state": "starting",
                       "pid": os.getpid(), "removed_env_names": removed, "stages": [],
                       "error": None,
                       "note": "private bookkeeping; seconds are diagnostics, not a benchmark"}
        self.seq = 0

    def save(self):
        write_private_json(self.layout.status, self.status)

    def stage(self, name, command, timeout_key="short", expect_rejection=False):
        """Run one child; returns its log text. Fails closed on any surprise."""
        self.seq += 1
        log = self.layout.logs / f"{self.seq:02d}-{name}.log"
        entry = {"name": name, "command": [str(c) for c in command],
                 "expect": "rejection" if expect_rejection else "success",
                 "log": str(log)}
        self.status["stages"].append(entry)
        self.status["current_stage"] = name
        self.save()
        start = time.monotonic()
        code, timed_out = run_bounded(command, log, self.env, self.timeouts[timeout_key],
                                      self.layout.logs, self.grace)
        entry.update(exit_code=code, timed_out=timed_out,
                     seconds=round(time.monotonic() - start, 3))
        text = Path(log).read_text(errors="replace")
        if timed_out:
            ok = False
            entry["outcome"] = "timeout; process group killed"
        elif expect_rejection:
            # A clean refusal: exit 1, an error line, and no success JSON.
            ok = code == 1 and bool(text.strip()) and not reports(text, "verified")
            entry["outcome"] = "rejected as required" if ok else "NOT cleanly rejected"
        else:
            ok = code == 0
            field = {"prepare": "prepared", "execute": "execution_matches_policy",
                     "prove": "saved_receipt", "inner-verify": "verified",
                     "groth16-wrap": "saved_groth16_receipt",
                     "groth16-verify": "verified"}.get(name)
            if field is not None:
                ok = ok and reports(text, field,
                                    kind="groth16" if name == "groth16-verify" else None)
            entry["outcome"] = "ok" if ok else "failed"
        if reports(text, "mvp_complete"):
            ok = False
            entry["outcome"] = "child claimed mvp_complete; refused"
        self.save()
        if not ok:
            raise RunnerError(f"stage {name}: {entry['outcome']} (exit {code})")
        return text

    # -- stages --
    def check_native_hashes(self):
        """Optional: compare extracted native files to the parent's hash record."""
        self.status["current_stage"] = "native-hashes"
        record = json.loads(Path(self.c["native_hashes"]).read_text())
        if isinstance(record, dict):
            record = record["artifacts"]
        want = {e["file"]: e for e in record}
        if len(want) != len(record):
            raise RunnerError("duplicate native artifact in hash record")
        missing = [n for n in NATIVE_FILES if n not in want]
        if missing:
            raise RunnerError(f"native hash record lacks {missing}")
        tools = Path(self.c["native_tools"])
        deadline = time.monotonic() + self.timeouts["hash"]
        for name in NATIVE_FILES:
            path = tools / name
            if path.stat().st_size != want[name]["bytes"] or sha256_file(path) != want[name]["sha256"]:
                raise RunnerError(f"native tool {name} differs from the hash record")
            if time.monotonic() > deadline:
                raise RunnerError("native hash check timed out")
        self.status["native_hashes_checked"] = True

    def r0vm_version(self):
        text = self.stage("r0vm-version", [self.c["r0vm"], "--version"])
        if not re.search(r"(?<![\d.])" + re.escape(self.c["r0vm_version"]) + r"(?![\d.])", text):
            raise RunnerError(f"r0vm is not version {self.c['r0vm_version']}")

    def image_ids(self):
        """Both binaries' compiled image ids must agree, and equal the caller's
        pin if one was given, before anything is prepared."""
        host = self.stage("host-image-id", [self.c["host"], "image-id"]).strip()
        wrap = self.stage("wrap-image-id", [self.c["wrap"], "image-id"]).strip()
        for role, value in (("host", host), ("wrap", wrap)):
            self.reported_ids[role] = value if IMAGE_ID_RE.fullmatch(value) else "malformed"
        self.status["image_ids_reported"] = dict(self.reported_ids)
        if not IMAGE_ID_RE.fullmatch(host) or host != wrap:
            raise RunnerError("host and wrap guest image ids differ or are malformed")
        pin = self.c.get("expected_image_id")
        if pin is not None and host != pin:
            raise RunnerError("guest image id differs from --expected-image-id")
        self.image_id = host

    def prepare(self):
        L = self.layout
        if self.c.get("input"):
            cmd = [self.c["host"], "prepare-input", self.c["model"], self.c["input"],
                   L.public, L.private]
        else:
            cmd = [self.c["host"], "prepare", self.c["model"], L.public, L.private]
        self.stage("prepare", cmd, "prepare")
        check_private_mode(L.private, "private directory")
        names = set(os.listdir(L.private))
        if names != {"request.bin", self.p["private_output"]}:
            raise RunnerError(f"private directory after prepare holds {sorted(names)}")
        for name in names:
            if not stat.S_ISREG(os.lstat(L.private / name).st_mode):
                raise RunnerError(f"unexpected private entry after prepare: {name}")
            os.chmod(L.private / name, 0o600)
        audit_public(L.public, PUBLIC_INPUTS)
        if (L.public / "model.bin").read_bytes() != Path(self.c["model"]).read_bytes():
            raise RunnerError("public model.bin differs from MODEL_BIN")
        policy = (L.public / "policy.bin").read_bytes()
        if len(policy) != POLICY_BYTES:
            raise RunnerError("policy.bin is not 144 bytes")
        if policy[:16] != self.p["tag"]:
            raise RunnerError(f"policy.bin is not a {self.profile} profile statement")
        self.flags["prepared"] = True

    def host_args(self):
        L = self.layout
        return [L.public / "model.bin", L.request, L.public / "policy.bin", L.inner, self.c["r0vm"]]

    def execute(self):
        self.stage("execute", [self.c["host"], "execute", *self.host_args()], "execute")
        if os.path.lexists(self.layout.inner):
            raise RunnerError("execute unexpectedly wrote a receipt")
        self.flags["execution_matches_policy"] = True

    def prove(self):
        L = self.layout
        self.stage("prove", [self.c["host"], "prove", *self.host_args()], "prove")
        if not stat.S_ISREG(os.lstat(L.inner).st_mode):
            raise RunnerError("prove did not leave a regular inner receipt")
        os.chmod(L.inner, 0o600)
        self.stage("inner-verify", verify_command(self.profile, self.c["host"],
                                                  L.public / "policy.bin", L.inner,
                                                  self.image_id))
        self.flags["inner_receipt_verified_privately"] = True

    def wrap(self):
        L = self.layout
        audit_public(L.public, PUBLIC_INPUTS)
        # The wrap binary removes its private work directory after a verified
        # wrap by default (the safe default for a hand run). This runner owns
        # the whole private tree, keeps it at mode 0700 for diagnosis and never
        # publishes it, so it asks the binary to keep the directory and checks
        # its mode below.
        keep_work = ["--keep-work"] if self.profile == "block" else []
        # The separately versioned token wrapper currently retains private work
        # by default and does not implement this block-only CLI flag.
        self.stage("groth16-wrap", [self.c["wrap"], "wrap", L.public / "policy.bin", L.inner,
                                    L.public / PUBLIC_RECEIPT, self.c["native_tools"],
                                    L.wrap_work, self.c["r0vm"], *keep_work], "wrap")
        audit_public(L.public, PUBLIC_INPUTS + (PUBLIC_RECEIPT,))
        check_private_mode(L.wrap_work, "wrap work directory")
        self.flags["groth16_wrapped"] = True

    def verify(self):
        L = self.layout
        self.stage("groth16-verify", verify_command(self.profile, self.c["wrap"],
                                                    L.public / "policy.bin",
                                                    L.public / PUBLIC_RECEIPT, self.image_id))
        self.flags["groth16_verified_fresh_process"] = True

    def controls(self):
        L = self.layout
        os.mkdir(L.controls, 0o700)
        policy = (L.public / "policy.bin").read_bytes()
        receipt = (L.public / PUBLIC_RECEIPT).read_bytes()

        def refuse(name, p, r, image=None):
            self.stage(name, verify_command(self.profile, self.c["wrap"], p, r,
                                            image or self.image_id),
                       expect_rejection=True)

        for field, pos in POLICY_FIELDS:
            altered = bytearray(policy)
            altered[pos] ^= 1
            path = L.controls / f"wrong-{field}-policy.bin"
            write_new(path, bytes(altered), 0o600)
            refuse(f"reject-wrong-{field}", path, L.public / PUBLIC_RECEIPT)
        self.flags["wrong_policy_rejected"] = True
        refuse("reject-inner-receipt-kind", L.public / "policy.bin", L.inner)
        self.flags["inner_receipt_refused_by_public_verifier"] = True
        if "wrong_image_id_rejected" in self.flags:
            wrong = self.image_id[:-1] + ("1" if self.image_id[-1] == "0" else "0")
            refuse("reject-wrong-image-id", L.public / "policy.bin",
                   L.public / PUBLIC_RECEIPT, wrong)
            self.flags["wrong_image_id_rejected"] = True
        variants = [("truncated", receipt[:-1]), ("trailing-byte", receipt + b"\0"),
                    ("empty", b"")]
        for label, pos in (("first", 0), ("middle", len(receipt) // 2), ("last", len(receipt) - 1)):
            altered = bytearray(receipt)
            altered[pos] ^= 1
            variants.append((f"flipped-{label}-byte", bytes(altered)))
        for label, data in variants:
            path = L.controls / f"{label}-receipt.bin"
            write_new(path, data, 0o600)
            refuse(f"reject-{label}", L.public / "policy.bin", path)
        self.flags["malformed_receipts_rejected"] = True

    def final_audit(self):
        self.status["current_stage"] = "public-audit"
        audit_public(self.layout.public, PUBLIC_INPUTS + (PUBLIC_RECEIPT,))
        self.flags["public_directory_audited"] = True

    def secret_scan(self):
        """P1 evidence, after the wrap and its independent verification: no
        private value of this run, and no SHA-256 of one, is in anything
        published or logged.

        The private request and output are read here only to build search
        needles. Everything recorded afterwards -- the status file, the public
        manifest, the failure message -- carries nothing but marker kinds, file
        labels and counts, so the stage itself never writes a private value.
        A hit fails the run; so does a file that could not be read in full,
        because unread bytes are not evidence.

        Known limits, both fail-closed or documented rather than hidden: a
        degenerate private value (for example an all-zero input) can match
        padding inside a legitimate public artifact and fail the run, and
        `outcome.json` is written after this stage, so it is not scanned --
        it is built only from public file hashes and flags.
        """
        L = self.layout
        self.status["current_stage"] = "secret-scan"
        self.save()
        request = read_limited(L.request, self.p["request_bytes"])
        output = read_limited(L.private / self.p["private_output"], self.p["output_bytes"])
        if len(request) != self.p["request_bytes"] or len(output) != self.p["output_bytes"]:
            raise RunnerError("secret-scan: private request/output framing changed")
        markers, short, covered = secret_markers(request, output, self.p["input_bytes"])
        del request, output
        if covered != len(SECRET_MARKER_VALUES):
            raise RunnerError(f"secret-scan: only {covered} of {len(SECRET_MARKER_VALUES)} "
                              "private values could be read; no privacy evidence")
        scanned, found, not_scanned = scan_for_markers(scan_targets(L), markers)
        record = {"files_scanned": scanned, "markers": len(markers),
                  "marker_values": covered, "raw_values_too_short": short,
                  "found": found, "not_scanned": not_scanned}
        self.secret_scan_record = record
        self.status["secret_scan"] = record
        self.save()
        if not_scanned:
            raise RunnerError("secret-scan: not scanned (too large, unreadable or not a "
                              f"regular file): {', '.join(sorted(not_scanned))}")
        if found:
            raise RunnerError("secret-scan: private marker(s) in published or logged files: "
                              + "; ".join(f"{e['marker']} in {e['file']}" for e in found))
        self.flags["public_secret_scan_clean"] = True

    def public_manifest(self, failed_stage):
        """Minimal outcome: public hashes and flags only; no paths, values, logs or timings."""
        public = self.layout.public
        try:
            real_directory(public, "public directory")
        except RunnerError:
            return
        artifacts = {}
        for name in PUBLIC_INPUTS + (PUBLIC_RECEIPT,):
            path = public / name
            if os.path.lexists(path) and stat.S_ISREG(os.lstat(path).st_mode):
                artifacts[name] = {"bytes": path.stat().st_size, "sha256": sha256_file(path)}
        accepted = failed_stage is None and all(self.flags.values())
        manifest = {
            "schema": SCHEMA,
            "profile": self.profile,
            "policy_profile_tag": self.p["tag"].decode(),
            "experiment": self.p["experiment"],
            "coverage": self.p["coverage"],
            "outcome": "accepted" if accepted else "failed",
            "failed_stage": failed_stage,
            "receipt_kind": "groth16" if self.flags["groth16_verified_fresh_process"] else None,
            "guest_image_id": self.image_id,
            "image_ids_reported": dict(self.reported_ids),
            "expected_image_id_pinned": self.c.get("expected_image_id") is not None,
            "artifacts": artifacts,
            # Counts depend on secret-value equality because marker needles are
            # deduplicated. Keep counts, labels and findings in private status.
            "acceptance": dict(self.flags, all_passed=accepted),
            "not_claimed": not_claimed(self.profile),
            "policy_note": "obtain policy.bin and the image id through an independent "
                           "trusted channel",
        }
        write_new(public / PUBLIC_MANIFEST,
                  (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode(), 0o644)
        if accepted:
            audit_public(public, PUBLIC_INPUTS + (PUBLIC_RECEIPT, PUBLIC_MANIFEST))

    def run(self):
        """Full pipeline under the heavy lock. Returns the exit code (0 = accepted)."""
        failed = None
        try:
            self.save()
            preflight(self.c)
            self.status["state"] = "waiting-for-heavy-lock"
            self.save()
            with open(self.lock_path, "a") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                self.status["state"] = "running"
                self.save()
                if self.c.get("native_hashes"):
                    self.check_native_hashes()
                self.r0vm_version()
                self.image_ids()
                self.prepare()
                self.execute()
                self.prove()
                self.wrap()
                self.verify()
                self.controls()
                self.final_audit()
                self.secret_scan()
        except BaseException as exc:  # includes Interrupted; fail closed
            failed = self.status.get("current_stage") or "preflight"
            self.status["error"] = f"{type(exc).__name__}: {exc}"
            if not isinstance(exc, Exception):
                raise
        finally:
            try:
                self.public_manifest(failed)
            except Exception as exc:
                failed = failed or "public-manifest"
                self.status["error"] = self.status["error"] or f"manifest: {exc}"
            self.status["state"] = "failed" if failed else "succeeded"
            self.status["acceptance"] = dict(self.flags)
            self.save()
        return 1 if failed else 0


# ---- command line --------------------------------------------------------
def build_config(args):
    """Validate CLI paths and create the new private output root (0700)."""
    if not 1 <= args.threads <= 256:
        raise RunnerError("threads must be between 1 and 256")
    if args.expected_image_id is not None:
        image_id_arg(args.expected_image_id)
    for value in [args.prove_timeout, args.wrap_timeout, args.execute_timeout,
                  args.short_timeout, args.kill_grace]:
        if value is not None and (not math.isfinite(value) or value <= 0):
            raise RunnerError("timeouts and kill grace must be finite positive seconds")
    out = new_destination(args.out)
    public = new_destination(args.public_dir) if args.public_dir else out / "public"
    layout = Layout(out, public)
    check_disjoint(layout.public, [layout.private, layout.logs, layout.out]
                   if args.public_dir else [layout.private, layout.logs])
    config = {
        "profile": args.profile,
        "expected_image_id": args.expected_image_id,
        "out": str(out), "public": str(layout.public),
        "model": str(regular_file(args.model, "MODEL_BIN")),
        "input": str(regular_file(args.input, "owner input")) if args.input else None,
        "host": str(regular_file(args.host, "HOST", executable=True)),
        "wrap": str(regular_file(args.wrap, "WRAP", executable=True)),
        "r0vm": str(regular_file(args.r0vm, "R0VM", executable=True)),
        "native_tools": os.path.realpath(args.native_tools),
        "native_hashes": str(regular_file(args.native_hashes, "native hash record"))
                         if args.native_hashes else None,
        "r0vm_version": args.r0vm_version,
        "threads": args.threads,
        "timeouts": {k: v for k, v in (("prove", args.prove_timeout), ("wrap", args.wrap_timeout),
                                       ("execute", args.execute_timeout),
                                       ("short", args.short_timeout)) if v is not None},
    }
    for path in (config["model"], config["input"], config["host"], config["wrap"],
                 config["r0vm"], config["native_tools"]):
        if path and nested(path, layout.public):
            raise RunnerError("inputs must not live inside the public destination")
    preflight(config)
    os.mkdir(out, 0o700)
    os.chmod(out, 0o700)
    os.mkdir(layout.logs, 0o700)
    write_new(layout.config, (json.dumps(config, indent=2) + "\n").encode(), 0o600)
    return config


def load_config(out):
    out = Path(os.path.abspath(out))
    check_private_mode(out, "output root")
    return json.loads((out / "config.json").read_text())


def execute_run(out, lock_path, grace):
    """The (possibly detached) worker: run, then always write the exit marker."""
    for sig in (signal.SIGTERM, signal.SIGHUP, signal.SIGINT):
        signal.signal(sig, _raise_interrupted)
    code = 1
    layout = None
    try:
        config = load_config(out)
        layout = Layout(config["out"], config["public"])
        code = Runner(config, lock_path, grace).run()
    finally:
        done = layout.done if layout else Path(os.path.abspath(out)) / "run.done"
        write_new(done, f"{code}\n".encode(), 0o600)
        dir_fd = os.open(done.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    return code


def add_run_arguments(p):
    p.add_argument("--profile", choices=sorted(PROFILES), default=DEFAULT_PROFILE,
                   help="block (default; 6184-byte Z60MDL01 model) or token "
                        "(13928-byte Z60TOK01 model)")
    p.add_argument("--expected-image-id",
                   help="optional approved guest image id (64 lowercase hex) to pin")
    p.add_argument("--model", required=True, help="MODEL_BIN for the selected profile")
    p.add_argument("--host", required=True, help="prebuilt zk60-{block,token}-host")
    p.add_argument("--wrap", required=True, help="prebuilt zk60-{block,token}-wrap")
    p.add_argument("--r0vm", required=True, help="local r0vm server binary")
    p.add_argument("--native-tools", required=True, help="dir with extracted Groth16 tools")
    p.add_argument("--out", required=True, help="new output root (created 0700)")
    p.add_argument("--public-dir", help="new public dir outside --out (default OUT/public)")
    p.add_argument("--input", help="owner input (block: 1024 bytes of i16; token: 128 "
                                   "bytes of u32 IDs); uses prepare-input")
    p.add_argument("--native-hashes", help="JSON list of {file,bytes,sha256} to check tools")
    p.add_argument("--r0vm-version", default="3.0.6")
    p.add_argument("--threads", type=int, default=2)
    for name in ("prove", "wrap", "execute", "short"):
        p.add_argument(f"--{name}-timeout", type=float, help="seconds")
    p.add_argument("--lock", default=DEFAULT_LOCK, help=argparse.SUPPRESS)
    p.add_argument("--kill-grace", type=float, default=KILL_GRACE, help=argparse.SUPPRESS)


def cmd_launch(args, detach):
    build_config(args)
    out = os.path.abspath(args.out)
    if not detach:
        return execute_run(out, args.lock, args.kill_grace)
    fd = os.open(Path(out) / "logs" / "runner.log",
                 os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        proc = subprocess.Popen([sys.executable, os.path.abspath(__file__), "_worker", out,
                                 "--lock", args.lock, "--kill-grace", str(args.kill_grace)],
                                stdin=subprocess.DEVNULL, stdout=fd, stderr=fd,
                                start_new_session=True, close_fds=True)
    finally:
        os.close(fd)
    print(json.dumps({"launched": True, "pid": proc.pid, "status": str(Path(out) / "status.json"),
                      "done": str(Path(out) / "run.done")}))
    return 0


def cmd_status(args):
    out = Path(os.path.abspath(args.out))
    status = json.loads((out / "status.json").read_text()) if (out / "status.json").exists() else {}
    done = out / "run.done"
    report = {"state": status.get("state", "not-started"),
              "profile": status.get("profile"),
              "current_stage": status.get("current_stage"),
              "error": status.get("error"),
              "acceptance": status.get("acceptance"),
              "exit_code": int(done.read_text()) if done.exists() else None}
    if report["exit_code"] is None and status.get("pid"):
        try:
            os.kill(status["pid"], 0)
            report["runner_alive"] = True
        except ProcessLookupError:
            report["runner_alive"] = False
            report["state"] = "died-without-marker"
        except PermissionError:
            report["runner_alive"] = True
    print(json.dumps(report, indent=2))
    if report["state"] == "died-without-marker":
        return 1
    return 0 if report["exit_code"] == 0 else (2 if report["exit_code"] is None else 1)


def reports(text, field, kind=None):
    """Require an actual JSON true, allowing ordinary JSON whitespace. With
    `kind`, the same JSON line must also name exactly that receipt kind."""
    for line in text.splitlines():
        try:
            value = json.loads(line)
        except ValueError:
            continue
        if (isinstance(value, dict) and value.get(field) is True
                and (kind is None or value.get("kind") == kind)):
            return True
    return False


def cmd_verify(args):
    """Independent fresh-process check of a public receipt for an explicitly
    named profile, against a trusted policy and a trusted image id.

    Nothing is taken from the candidate: the profile is the caller's and the
    policy's tag must already match it; the wrap binary's compiled image id,
    queried in its own fresh process, must equal --expected-image-id exactly
    before verify runs; the token verifier is also handed that same id.
    """
    profile = args.profile
    p = PROFILES[profile]
    expected = image_id_arg(args.expected_image_id)
    wrap = regular_file(args.wrap, "WRAP", executable=True)
    policy = regular_file(args.policy, "policy")
    receipt = regular_file(args.receipt, "receipt")
    env, _ = scrubbed_env(2)
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        raise RunnerError("timeout must be finite positive seconds")
    if policy.stat().st_size != POLICY_BYTES or receipt.stat().st_size > 16 * 1024 * 1024:
        raise RunnerError("policy or receipt size refused")
    with policy.open("rb") as f:
        if f.read(16) != p["tag"]:
            raise RunnerError(f"policy is not a {profile} profile statement")
    result = {"verified": False, "profile": profile, "expected_image_id": expected,
              "kind": None}
    with tempfile.TemporaryDirectory(prefix="zk60-verify-") as work:
        id_log = Path(work) / "image-id.log"
        code, timed_out = run_bounded([wrap, "image-id"], id_log, env, args.timeout, work)
        reported = id_log.read_text(errors="replace").strip()
        if timed_out or code != 0 or reported != expected:
            result["reason"] = ("timeout" if timed_out
                                else "wrap binary's image id differs from --expected-image-id")
            print(json.dumps(result, indent=2))
            return 1
        log = Path(work) / "verify.log"
        code, timed_out = run_bounded(verify_command(profile, wrap, policy, receipt, expected),
                                      log, env, args.timeout, work)
        text = log.read_text(errors="replace")
    if timed_out:
        result["reason"] = "timeout"
        print(json.dumps(result, indent=2))
        return 1
    ok = (code == 0 and reports(text, "verified", kind="groth16")
          and not reports(text, "mvp_complete"))
    result.update(verified=ok, exit_code=code, kind="groth16" if ok else None,
                  receipt_sha256=sha256_file(receipt), policy_sha256=sha256_file(policy))
    if not ok:
        result["verifier_message"] = text.strip()[-500:]
    print(json.dumps(result, indent=2))
    return 0 if ok else 1


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    add_run_arguments(sub.add_parser("launch", help="validate, then run detached"))
    add_run_arguments(sub.add_parser("run", help="validate, then run in the foreground"))
    s = sub.add_parser("status", help="report a run's state and exit marker")
    s.add_argument("out")
    v = sub.add_parser("verify", help="fresh-process Groth16 verification")
    v.add_argument("--profile", required=True, choices=sorted(PROFILES),
                   help="chosen by the verifier; never inferred from the candidate")
    v.add_argument("--expected-image-id", required=True,
                   help="approved guest image id from a trusted channel (64 lowercase hex)")
    v.add_argument("--wrap", required=True)
    v.add_argument("--policy", required=True, help="policy from a trusted channel")
    v.add_argument("--receipt", required=True)
    v.add_argument("--timeout", type=float, default=600)
    w = sub.add_parser("_worker", help=argparse.SUPPRESS)
    w.add_argument("out")
    w.add_argument("--lock", default=DEFAULT_LOCK)
    w.add_argument("--kill-grace", type=float, default=KILL_GRACE)
    args = parser.parse_args(argv)
    try:
        if args.command in ("launch", "run"):
            return cmd_launch(args, detach=args.command == "launch")
        if args.command == "status":
            return cmd_status(args)
        if args.command == "verify":
            return cmd_verify(args)
        return execute_run(args.out, args.lock, args.kill_grace)
    except RunnerError as exc:
        print(f"zk60_zkvm_demo: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
