"""Unit tests for scripts/zk60_zkvm_demo.py.

EVERY host/wrap/r0vm binary here is a MOCK Python script written into a temp
directory. The mocks imitate only the command-line and file contract of
zk60-block-{host,wrap} and zk60-token-{host,wrap} (argument counts, the token
verifiers' trailing image-id argument, the profile tag at the start of
policy.bin, the private output file name, and the token CLIs' refusal of
RISC0_DEV_MODE / RISC0_PROVER / BONSAI_*). They generate NO proof, run no
zkVM and verify nothing cryptographic. A passing test says the runner's
filesystem safety, profile/image binding, timeout cleanup and fail-closed
orchestration behave as specified, not that any receipt is sound. No test
needs network, Rust or r0vm.
"""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "zk60_zkvm_demo.py"
spec = importlib.util.spec_from_file_location("zk60_zkvm_demo", SCRIPT)
demo = importlib.util.module_from_spec(spec)
spec.loader.exec_module(demo)

IMAGE_ID = "ab" * 32
OTHER_IMAGE_ID = "cd" * 32
SECRET = "MOCK-SECRET-REQUEST-7f3a"

MOCK_HOST = r'''#!{python}
# MOCK zk60-{profile}-host: file contract only, NO proving, NO real verification.
import fcntl, json, os, sys
a = sys.argv
if any(k in ("RISC0_DEV_MODE", "RISC0_PROVER") or k.startswith("BONSAI_") for k in os.environ):
    sys.exit("zk60 MOCK: RISC0_DEV_MODE, RISC0_PROVER and BONSAI_* must be unset")
def put(path, data, mode):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    os.write(fd, data); os.close(fd)
def lock_state():
    with open({lock!r}, "a") as f:
        try:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return "free"
        except BlockingIOError:
            return "held"
image_arg = {image_arg!r}
if a[1] == "image-id":
    with open({probe!r}, "a") as p: p.write(lock_state() + "\n")
    print({image!r})
elif a[1] in ("prepare", "prepare-input"):
    model, pub, priv = (a[2], a[4], a[5]) if a[1] == "prepare-input" else (a[2], a[3], a[4])
    if os.path.getsize(model) != {model_bytes!r}:
        sys.exit("zk60 MOCK: invalid public model encoding")
    if os.path.lexists(pub) or os.path.lexists(priv):
        sys.exit("zk60 MOCK: output directories must be new and disjoint")
    os.mkdir(priv, 0o700); os.mkdir(pub)
    put(os.path.join(priv, "request.bin"), {secret!r}.encode(), 0o600)
    put(os.path.join(priv, {output!r}), b"MOCK-PLAINTEXT-OUTPUT", 0o600)
    put(os.path.join(pub, "policy.bin"), {tag!r} + bytes(range(128)), 0o644)
    put(os.path.join(pub, "model.bin"), open(model, "rb").read(), 0o644)
    print('{{"prepared":true,"mock":true,"mvp_complete":false}}')
elif a[1] == "execute":
    print('{{"execution_matches_policy":true,"mock":true}}')
elif a[1] == "prove":
    if {mode!r} == "prove-fail":
        sys.exit("zk60 MOCK: prove failure")
    policy = open(a[4], "rb").read()
    put(a[5], b"MOCK-INNER" + policy, 0o644)
    print('{{"saved_receipt":true,"mock":true}}')
elif a[1] == "verify" and len(a) == (5 if image_arg else 4):
    if image_arg and a[4] != {image!r}:
        sys.exit("zk60 MOCK: compiled image differs from expected image id")
    if open(a[3], "rb").read() != b"MOCK-INNER" + open(a[2], "rb").read():
        sys.exit("zk60 MOCK: refusal")
    print('{{"verified":true,"kind":"succinct","mock":true}}')
else:
    sys.exit("usage")
'''

MOCK_WRAP = r'''#!{python}
# MOCK zk60-{profile}-wrap: file contract only, NO Groth16, NO real verification.
import os, subprocess, sys, time
a = sys.argv
mode = {mode!r}
image_arg = {image_arg!r}
if any(k in ("RISC0_DEV_MODE", "RISC0_PROVER") or k.startswith("BONSAI_") for k in os.environ):
    sys.exit("zk60 MOCK wrap: RISC0_DEV_MODE, RISC0_PROVER and BONSAI_* must be unset")
with open({calls!r}, "a") as c: c.write(" ".join(a[1:2]) + "\n")
if a[1] == "image-id":
    print({wrap_image!r})
elif a[1] == "wrap":
    policy, inner, out, tools, work = [open(a[2], "rb").read()] + a[3:7]
    if mode == "hang":
        child = subprocess.Popen(["sleep", "1000"])
        with open({pidfile!r}, "w") as f: f.write("%d %d\n" % (os.getpid(), child.pid))
        time.sleep(1000)
    if open(inner, "rb").read() != b"MOCK-INNER" + policy:
        sys.exit("zk60 MOCK wrap: input refused")
    os.mkdir(work, 0o700)
    fd = os.open(os.path.join(work, "witness.wtns"), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    os.write(fd, b"MOCK-WITNESS"); os.close(fd)
    fd = os.open(out, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    os.write(fd, b"MOCK-GROTH16" + policy); os.close(fd)
    if mode == "stray":
        open(os.path.join(os.path.dirname(out), "leak.bin"), "wb").write(b"x")
    print('{{"saved_groth16_receipt":true,"mock":true}}')
elif a[1] == "verify" and len(a) == (5 if image_arg else 4):
    if image_arg and a[4] != {wrap_image!r} and mode != "lax-image":
        sys.exit("zk60 MOCK wrap: compiled image differs from expected image id")
    ok = open(a[3], "rb").read() == b"MOCK-GROTH16" + open(a[2], "rb").read()
    if mode == "claims-mvp" and ok:
        print('{{"verified":true,"kind":"groth16","mvp_complete":true,"mock":true}}')
    elif mode == "wrong-kind" and ok:
        print('{{"verified":true,"kind":"succinct","mock":true}}')
    elif ok or mode == "lax":
        print('{{"verified":true,"kind":"groth16","mock":true}}')
    else:
        sys.exit("zk60 MOCK wrap: refusal")
else:
    sys.exit("usage")
'''

MOCK_R0VM = "#!/bin/sh\necho 'risc0-r0vm 3.0.6 (MOCK, runs nothing)'\n"


def executable(path, text):
    path.write_text(text)
    path.chmod(0o755)
    return path


def wait_for(predicate, seconds=30.0):
    stop = time.monotonic() + seconds
    while time.monotonic() < stop:
        if predicate():
            return True
        time.sleep(0.05)
    return False


def pid_gone(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return True
    try:  # a reparented zombie awaiting its reaper counts as gone
        return Path(f"/proc/{pid}/stat").read_text().split(") ")[1].startswith("Z")
    except (OSError, IndexError):
        return True


def model_bytes(profile):
    p = demo.PROFILES[profile]
    return p["model_magic"] + bytes(p["model_bytes"] - 8)


class Fixture(unittest.TestCase):
    """Temp tree with MOCK binaries, a model file and native tool stand-ins.

    Defaults to the block profile; `use_profile("token")` switches the model
    file, the mocks and the argv to the token profile."""

    profile = "block"

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(os.path.realpath(self._tmp.name))
        self.lock = self.root / "heavy.lock"
        self.probe = self.root / "lock-probe.txt"
        self.calls = self.root / "wrap-calls.txt"
        self.pidfile = self.root / "hang.pid"
        self.model = self.root / "model.bin"
        self.tools = self.root / "native"
        self.tools.mkdir()
        for name in demo.NATIVE_FILES:
            executable(self.tools / name, "#!/bin/sh\nexit 99  # MOCK native tool, never run\n")
        self.r0vm = executable(self.root / "r0vm", MOCK_R0VM)
        self.out = self.root / "run"
        self.use_profile(self.profile)

    def tearDown(self):
        self._tmp.cleanup()

    def use_profile(self, profile, mock_profile=None):
        """Select the runner profile; `mock_profile` lets the binaries differ."""
        self.profile = profile
        self.model.write_bytes(model_bytes(profile))
        self.mock_profile = mock_profile or profile
        self.mocks()

    def mocks(self, host_mode="ok", wrap_mode="ok", wrap_image=IMAGE_ID):
        p = demo.PROFILES[self.mock_profile]
        fmt = dict(python=sys.executable, lock=str(self.lock), probe=str(self.probe),
                   calls=str(self.calls), image=IMAGE_ID, secret=SECRET,
                   pidfile=str(self.pidfile), profile=self.mock_profile, tag=p["tag"],
                   output=p["private_output"], model_bytes=p["model_bytes"],
                   image_arg=p["verify_takes_image"])
        self.host = executable(self.root / "mock-host", MOCK_HOST.format(mode=host_mode, **fmt))
        self.wrap = executable(self.root / "mock-wrap", MOCK_WRAP.format(
            mode=wrap_mode, wrap_image=wrap_image, **fmt))

    def argv(self, command="run", *extra):
        profile = [] if self.profile == "block" else ["--profile", self.profile]
        return [command, *profile, "--model", str(self.model), "--host", str(self.host),
                "--wrap", str(self.wrap), "--r0vm", str(self.r0vm),
                "--native-tools", str(self.tools), "--out", str(self.out),
                "--lock", str(self.lock), "--kill-grace", "0.5", *extra]

    def outcome(self):
        return json.loads((self.out / "public" / "outcome.json").read_text())

    def status(self):
        return json.loads((self.out / "status.json").read_text())

    def stage(self, name):
        return next(s for s in self.status()["stages"] if s["name"] == name)


class MockedPipelineTests(Fixture):
    def test_nonfinite_or_nonpositive_limits_are_refused_before_output(self):
        for option,value in [("--prove-timeout","nan"),("--wrap-timeout","inf"),
                             ("--short-timeout","-1"),("--threads","0")]:
            with self.subTest(option=option):
                self.assertEqual(demo.main(self.argv("run",option,value)),1)
                self.assertFalse(self.out.exists())

    def test_exit_zero_without_expected_json_does_not_pass(self):
        text=self.host.read_text()
        self.host.write_text(text.replace('"execution_matches_policy":true','"execution_matches_policy":false'))
        self.assertEqual(demo.main(self.argv()),1)
        self.assertEqual(self.outcome()["failed_stage"],"execute")
        self.assertFalse(self.outcome()["acceptance"]["execution_matches_policy"])

    def test_success_json_is_parsed_with_whitespace_and_boolean_type(self):
        self.assertTrue(demo.reports('{"verified": true}',"verified"))
        self.assertFalse(demo.reports('{"verified": "true"}',"verified"))
        self.assertFalse(demo.reports('{"verified": 1}',"verified"))
        self.assertTrue(demo.reports('{"verified": true, "kind": "groth16"}', "verified",
                                     kind="groth16"))
        self.assertFalse(demo.reports('{"verified": true, "kind": "succinct"}', "verified",
                                      kind="groth16"))
        self.assertFalse(demo.reports('{"verified": true}\n{"kind": "groth16"}', "verified",
                                      kind="groth16"))

    def test_mock_pipeline_accepts_and_publishes_only_allowed_files(self):
        self.assertEqual(demo.main(self.argv()), 0)
        public = self.out / "public"
        self.assertEqual(sorted(os.listdir(public)),
                         ["model.bin", "outcome.json", "policy.bin", "receipt.bin"])
        manifest = self.outcome()
        self.assertEqual(manifest["outcome"], "accepted")
        self.assertEqual(manifest["profile"], "block")
        self.assertEqual(manifest["experiment"], "zk60-zkvm-complete-block")
        self.assertEqual(manifest["policy_profile_tag"], "zk60-r0-block-v1")
        self.assertTrue(all(manifest["acceptance"].values()))
        self.assertEqual(set(manifest["acceptance"]),
                         set(demo.ACCEPTANCE_FLAGS) | {"all_passed"})
        self.assertEqual(manifest["guest_image_id"], IMAGE_ID)
        self.assertEqual(manifest["image_ids_reported"], {"host": IMAGE_ID, "wrap": IMAGE_ID})
        self.assertFalse(manifest["expected_image_id_pinned"])
        self.assertEqual(manifest["receipt_kind"], "groth16")
        self.assertEqual(manifest["not_claimed"],
                         {"model_mvp_complete": False, "model_scale_mvp": False,
                          "trained_model": False, "d7_accepted": False, "benchmark": False,
                          "token_generation": False})
        text = (public / "outcome.json").read_text()
        for leak in (str(self.root), SECRET, "MOCK-PLAINTEXT", "inner.bin", "request",
                     "seconds", ".log", "wrap-work"):
            self.assertNotIn(leak, text)
        self.assertEqual((self.out / "run.done").read_text(), "0\n")
        self.assertEqual(self.status()["state"], "succeeded")
        self.assertEqual(self.status()["profile"], "block")
        # Every stage that ran under the runner saw the heavy lock held.
        self.assertEqual(set(self.probe.read_text().split()), {"held"})
        # Block verifiers take no image argument (their CLI refuses a fifth).
        self.assertEqual(len(self.stage("groth16-verify")["command"]), 4)
        self.assertEqual(len(self.stage("inner-verify")["command"]), 4)

    def test_private_modes(self):
        self.assertEqual(demo.main(self.argv()), 0)
        mode = lambda p: stat.S_IMODE(os.lstat(p).st_mode)
        for d in (self.out, self.out / "private", self.out / "logs",
                  self.out / "private" / "controls", self.out / "private" / "wrap-work"):
            self.assertEqual(mode(d), 0o700, d)
        private_files = [self.out / "config.json", self.out / "status.json",
                         self.out / "run.done", self.out / "private" / "inner.bin",
                         self.out / "private" / "request.bin",
                         self.out / "private" / "output.i16"]
        private_files += list((self.out / "logs").iterdir())
        private_files += list((self.out / "private" / "controls").iterdir())
        for f in private_files:
            self.assertEqual(mode(f), 0o600, f)

    def test_controls_cover_policy_fields_kind_and_malformed(self):
        self.assertEqual(demo.main(self.argv()), 0)
        names = [s["name"] for s in self.status()["stages"] if s["expect"] == "rejection"]
        for field, _ in demo.POLICY_FIELDS:
            self.assertIn(f"reject-wrong-{field}", names)
        self.assertIn("reject-wrong-profile", names)
        self.assertIn("reject-inner-receipt-kind", names)
        for label in ("truncated", "trailing-byte", "empty", "flipped-first-byte",
                      "flipped-middle-byte", "flipped-last-byte"):
            self.assertIn(f"reject-{label}", names)
        # The block verifier takes no image argument, so there is no image control.
        self.assertNotIn("reject-wrong-image-id", names)
        kind = self.stage("reject-inner-receipt-kind")
        self.assertIn(str(self.out / "private" / "inner.bin"), kind["command"])

    def test_prove_failure_fails_closed(self):
        self.mocks(host_mode="prove-fail")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["outcome"], "failed")
        self.assertEqual(manifest["failed_stage"], "prove")
        self.assertTrue(manifest["acceptance"]["prepared"])
        self.assertTrue(manifest["acceptance"]["execution_matches_policy"])
        for flag in demo.ACCEPTANCE_FLAGS[2:] + ("all_passed",):
            self.assertFalse(manifest["acceptance"][flag], flag)
        self.assertIsNone(manifest["receipt_kind"])
        self.assertNotIn("receipt.bin", os.listdir(self.out / "public"))
        self.assertEqual((self.out / "run.done").read_text(), "1\n")

    def test_lax_verifier_fails_rejection_controls(self):
        self.mocks(wrap_mode="lax")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["failed_stage"], "reject-wrong-profile")
        self.assertTrue(manifest["acceptance"]["groth16_verified_fresh_process"])
        self.assertFalse(manifest["acceptance"]["wrong_policy_rejected"])
        self.assertFalse(manifest["acceptance"]["all_passed"])

    def test_verifier_reporting_wrong_kind_is_not_groth16(self):
        self.mocks(wrap_mode="wrong-kind")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["failed_stage"], "groth16-verify")
        self.assertIsNone(manifest["receipt_kind"])

    def test_child_claiming_mvp_complete_fails_the_run(self):
        self.mocks(wrap_mode="claims-mvp")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["failed_stage"], "groth16-verify")
        self.assertIn("mvp_complete", self.stage("groth16-verify")["outcome"])
        self.assertNotIn('"mvp_complete": true', (self.out / "public" / "outcome.json").read_text())

    def test_extra_public_file_fails_audit(self):
        self.mocks(wrap_mode="stray")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["failed_stage"], "groth16-wrap")
        self.assertFalse(manifest["acceptance"]["groth16_wrapped"])
        self.assertIn("public directory holds", self.status()["error"])

    def test_image_id_mismatch_stops_before_prepare(self):
        self.mocks(wrap_image=OTHER_IMAGE_ID)
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse((self.out / "public").exists())
        self.assertFalse((self.out / "private").exists())
        self.assertEqual(self.status()["acceptance"],
                         {k: False for k in demo.ACCEPTANCE_FLAGS})
        # Both reported ids are kept privately so the mismatch is diagnosable.
        self.assertEqual(self.status()["image_ids_reported"],
                         {"host": IMAGE_ID, "wrap": OTHER_IMAGE_ID})

    def test_expected_image_pin_mismatch_stops_before_prepare(self):
        self.assertEqual(demo.main(self.argv("run", "--expected-image-id", OTHER_IMAGE_ID)), 1)
        self.assertFalse((self.out / "public").exists())
        self.assertFalse((self.out / "private").exists())
        self.assertIn("--expected-image-id", self.status()["error"])

    def test_expected_image_pin_match_is_recorded(self):
        self.assertEqual(demo.main(self.argv("run", "--expected-image-id", IMAGE_ID)), 0)
        self.assertTrue(self.outcome()["expected_image_id_pinned"])
        self.assertEqual(self.outcome()["guest_image_id"], IMAGE_ID)

    def test_malformed_expected_image_refused_before_output(self):
        for bad in (IMAGE_ID.upper(), IMAGE_ID[:-1], IMAGE_ID + "0", "0x" + IMAGE_ID[2:]):
            with self.subTest(bad=bad):
                self.assertEqual(demo.main(self.argv("run", "--expected-image-id", bad)), 1)
                self.assertFalse(os.path.lexists(self.out))

    def test_stage_timeout_kills_wrap_group(self):
        self.mocks(wrap_mode="hang")
        self.assertEqual(demo.main(self.argv("run", "--wrap-timeout", "1")), 1)
        leader, child = map(int, self.pidfile.read_text().split())
        self.assertTrue(wait_for(lambda: pid_gone(leader) and pid_gone(child), 5))
        stage = self.status()["stages"][-1]
        self.assertEqual(stage["name"], "groth16-wrap")
        self.assertTrue(stage["timed_out"])
        self.assertEqual(self.outcome()["failed_stage"], "groth16-wrap")

    def test_owner_input_uses_prepare_input(self):
        owner = self.root / "input.i16"
        owner.write_bytes(bytes(demo.INPUT_BYTES))
        self.assertEqual(demo.main(self.argv("run", "--input", str(owner))), 0)
        self.assertEqual(self.stage("prepare")["command"][1], "prepare-input")
        self.assertNotIn("input", self.outcome()["artifacts"])

    def test_owner_input_wrong_size_refused_before_output(self):
        owner = self.root / "input.i16"
        owner.write_bytes(bytes(demo.INPUT_BYTES - 2))
        self.assertEqual(demo.main(self.argv("run", "--input", str(owner))), 1)
        self.assertFalse(os.path.lexists(self.out))


class TokenProfileTests(Fixture):
    profile = "token"

    def test_token_pipeline_binds_image_and_keeps_token_private(self):
        self.assertEqual(demo.main(self.argv()), 0)
        manifest = self.outcome()
        self.assertEqual(manifest["outcome"], "accepted")
        self.assertEqual(manifest["profile"], "token")
        self.assertEqual(manifest["experiment"], "zk60-zkvm-token-model")
        self.assertEqual(manifest["policy_profile_tag"], "zk60-r0-token-v1")
        self.assertIn("synthetic-T32-V32-two-block-greedy-token", manifest["coverage"])
        self.assertIn("untrained", manifest["coverage"])
        self.assertEqual(set(manifest["acceptance"]),
                         set(demo.TOKEN_ACCEPTANCE_FLAGS) | {"all_passed"})
        self.assertTrue(manifest["acceptance"]["wrong_image_id_rejected"])
        self.assertEqual(manifest["receipt_kind"], "groth16")
        self.assertEqual(manifest["not_claimed"],
                         {"model_mvp_complete": False, "model_scale_mvp": False,
                          "trained_model": False, "d7_accepted": False, "benchmark": False,
                          "token_disclosed": False})
        # Every token verify call ends with the bound image id, never another value.
        for s in self.status()["stages"]:
            if s["command"][1] == "verify" and s["name"] != "reject-wrong-image-id":
                self.assertEqual(s["command"][-1], IMAGE_ID, s["name"])
        wrong = self.stage("reject-wrong-image-id")
        self.assertNotEqual(wrong["command"][-1], IMAGE_ID)
        self.assertEqual(wrong["command"][3], str(self.out / "public" / "receipt.bin"))
        # The private token output stays private, 0600, and out of the manifest.
        out_u32 = self.out / "private" / "output.u32"
        self.assertEqual(stat.S_IMODE(os.lstat(out_u32).st_mode), 0o600)
        self.assertEqual(sorted(os.listdir(self.out / "public")),
                         ["model.bin", "outcome.json", "policy.bin", "receipt.bin"])
        text = (self.out / "public" / "outcome.json").read_text()
        for leak in ("output.u32", "MOCK-PLAINTEXT", SECRET, str(self.root)):
            self.assertNotIn(leak, text)
        self.assertNotIn('"mvp_complete": true', text)
        self.assertEqual(self.outcome()["artifacts"]["model.bin"]["bytes"], 13928)

    def test_verifier_ignoring_image_argument_fails_the_image_control(self):
        self.mocks(wrap_mode="lax-image")
        self.assertEqual(demo.main(self.argv()), 1)
        manifest = self.outcome()
        self.assertEqual(manifest["failed_stage"], "reject-wrong-image-id")
        self.assertFalse(manifest["acceptance"]["wrong_image_id_rejected"])
        self.assertFalse(manifest["acceptance"]["all_passed"])

    def test_refused_prover_switches_are_scrubbed_for_token_clis(self):
        # The MOCK token binaries exit 1 if any of these reach them.
        saved = dict(os.environ)
        try:
            os.environ.update(RISC0_DEV_MODE="1", RISC0_PROVER="bonsai",
                              BONSAI_API_KEY="k", BONSAI_API_URL="u")
            self.assertEqual(demo.main(self.argv()), 0)
        finally:
            os.environ.clear()
            os.environ.update(saved)
        self.assertEqual(set(self.status()["removed_env_names"]) &
                         {"RISC0_DEV_MODE", "RISC0_PROVER", "BONSAI_API_KEY", "BONSAI_API_URL"},
                         {"RISC0_DEV_MODE", "RISC0_PROVER", "BONSAI_API_KEY", "BONSAI_API_URL"})
        self.assertNotIn("BONSAI", (self.out / "public" / "outcome.json").read_text())

    def test_block_model_refused_by_token_profile_before_output(self):
        self.model.write_bytes(model_bytes("block"))
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse(os.path.lexists(self.out))

    def test_token_model_refused_by_default_block_profile(self):
        self.profile = "block"  # argv omits --profile: the default must be block
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse(os.path.lexists(self.out))

    def test_token_owner_input_size(self):
        owner = self.root / "tokens.u32"
        owner.write_bytes(bytes(128))
        self.assertEqual(demo.main(self.argv("run", "--input", str(owner))), 0)
        self.assertEqual(self.stage("prepare")["command"][1], "prepare-input")
        self.out = self.root / "run2"
        owner.write_bytes(bytes(demo.INPUT_BYTES))  # the block size is wrong here
        self.assertEqual(demo.main(self.argv("run", "--input", str(owner))), 1)
        self.assertFalse(os.path.lexists(self.out))

    def test_block_binaries_under_token_profile_stop_at_image_pin(self):
        # MOCK block binaries report IMAGE_ID; the caller pinned the approved
        # token image, so the run stops before prepare creates anything.
        self.use_profile("token", mock_profile="block")
        argv = self.argv("run", "--expected-image-id", OTHER_IMAGE_ID)
        self.assertEqual(demo.main(argv), 1)
        self.assertFalse((self.out / "private").exists())
        self.assertFalse((self.out / "public").exists())

    def test_block_binaries_under_token_profile_fail_closed_without_pin(self):
        # Without a pin the image ids agree, but the block host refuses the
        # token model, and nothing is published as accepted.
        self.use_profile("token", mock_profile="block")
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertEqual(self.status()["current_stage"], "prepare")
        self.assertFalse(self.status()["acceptance"]["prepared"])

    def test_policy_with_other_profile_tag_is_refused_after_prepare(self):
        # A host of the right model size but the wrong statement profile.
        text = self.host.read_text().replace(repr(b"zk60-r0-token-v1"),
                                             repr(b"zk60-r0-block-v1"))
        self.host.write_text(text)
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertEqual(self.outcome()["failed_stage"], "prepare")
        self.assertIn("not a token profile statement", self.status()["error"])
        self.assertFalse(self.outcome()["acceptance"]["prepared"])


class DestinationSafetyTests(Fixture):
    def test_existing_output_is_never_touched(self):
        self.out.mkdir()
        (self.out / "keep").write_text("mine")
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertEqual(os.listdir(self.out), ["keep"])

    def test_dangling_symlink_destination_refused(self):
        os.symlink(self.root / "elsewhere", self.out)
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse((self.root / "elsewhere").exists())

    def test_symlinked_parent_refused(self):
        (self.root / "real").mkdir()
        os.symlink(self.root / "real", self.root / "link")
        self.out = self.root / "link" / "run"
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertEqual(os.listdir(self.root / "real"), [])

    def test_public_dir_nested_either_way_refused(self):
        # Through the CLI both roots must be new with existing parents, so a
        # nested pair is refused before anything is created.
        for public in (self.out / "inner-public", self.root, self.root / "run"):
            self.assertEqual(demo.main(self.argv("run", "--public-dir", str(public))), 1)
            self.assertFalse(os.path.lexists(self.out))
        # The disjointness rule itself, checked directly.
        with self.assertRaises(demo.RunnerError):
            demo.check_disjoint(self.root / "pub", [self.root / "pub" / "private"])
        with self.assertRaises(demo.RunnerError):
            demo.check_disjoint(self.root / "a" / "pub", [self.root / "a"])
        demo.check_disjoint(self.root / "pub", [self.root / "pubx", self.root / "priv"])

    def test_separate_public_dir_works(self):
        public = self.root / "published"
        self.assertEqual(demo.main(self.argv("run", "--public-dir", str(public))), 0)
        self.assertEqual(sorted(os.listdir(public)),
                         ["model.bin", "outcome.json", "policy.bin", "receipt.bin"])
        self.assertFalse((self.out / "public").exists())

    def test_bad_model_refused_before_output(self):
        self.model.write_bytes(b"Z60MDL01" + bytes(10))
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse(os.path.lexists(self.out))

    def test_missing_native_tool_refused(self):
        (self.tools / "stark_verify_final.pk.dmp").unlink()
        self.assertEqual(demo.main(self.argv()), 1)
        self.assertFalse(os.path.lexists(self.out))

    def test_write_new_refuses_symlink_and_existing(self):
        target = self.root / "target"
        os.symlink(self.root / "victim", target)
        with self.assertRaises(OSError):
            demo.write_new(target, b"x", 0o600)
        self.assertFalse((self.root / "victim").exists())
        demo.write_new(self.root / "f", b"x", 0o600)
        with self.assertRaises(FileExistsError):
            demo.write_new(self.root / "f", b"y", 0o600)

    def test_scrubbed_env_drops_cloud_and_dev_switches(self):
        saved = dict(os.environ)
        try:
            os.environ.update(BONSAI_API_KEY="k", RISC0_DEV_MODE="1", RISC0_PROVER="p",
                              HL_GPU="1", RUST_LOG="x")
            env, removed = demo.scrubbed_env(2)
        finally:
            os.environ.clear()
            os.environ.update(saved)
        for key in ("BONSAI_API_KEY", "RISC0_DEV_MODE", "RISC0_PROVER", "HL_GPU", "RUST_LOG"):
            self.assertNotIn(key, env)
            self.assertIn(key, removed)
        self.assertEqual(env["RAYON_NUM_THREADS"], "2")


class ProcessControlTests(Fixture):
    def test_timeout_kills_whole_group_even_if_leader_ignores_term(self):
        pidfile = self.root / "grandchild.pid"
        script = f"trap '' TERM; sleep 1000 & echo $! > {pidfile}; while :; do sleep 1; done"
        log = self.root / "t.log"
        start = time.monotonic()
        code, timed_out = demo.run_bounded(["sh", "-c", script], log, dict(os.environ),
                                           timeout=0.5, cwd=self.root, grace=0.3)
        self.assertTrue(timed_out)
        self.assertEqual(code, -signal.SIGKILL)
        self.assertLess(time.monotonic() - start, 10)
        grandchild = int(pidfile.read_text())
        self.assertTrue(wait_for(lambda: pid_gone(grandchild), 5))
        self.assertEqual(stat.S_IMODE(os.lstat(log).st_mode), 0o600)

    def test_normal_exit_reports_code_and_reaps_stragglers(self):
        pidfile = self.root / "straggler.pid"
        code, timed_out = demo.run_bounded(
            ["sh", "-c", f"sleep 1000 & echo $! > {pidfile}; exit 3"],
            self.root / "n.log", dict(os.environ), timeout=30, cwd=self.root)
        self.assertEqual((code, timed_out), (3, False))
        self.assertTrue(wait_for(lambda: pid_gone(int(pidfile.read_text())), 5))

    def test_existing_log_refused(self):
        (self.root / "x.log").write_text("old")
        with self.assertRaises(FileExistsError):
            demo.run_bounded(["true"], self.root / "x.log", dict(os.environ), 5, self.root)
        self.assertEqual((self.root / "x.log").read_text(), "old")


class CliMixin:
    def cli(self, *argv):
        return subprocess.run([sys.executable, str(SCRIPT), *argv], capture_output=True,
                              text=True, timeout=60)

    def verify_cli(self, *extra, profile=None, image=IMAGE_ID, receipt=None, policy=None):
        public = self.out / "public"
        argv = ["verify", "--wrap", str(self.wrap),
                "--policy", str(policy or public / "policy.bin"),
                "--receipt", str(receipt or public / "receipt.bin")]
        if profile is not None:
            argv += ["--profile", profile]
        if image is not None:
            argv += ["--expected-image-id", image]
        return self.cli(*argv, *extra)

    def wrap_calls(self):
        return self.calls.read_text().split() if self.calls.exists() else []


class DetachedTests(CliMixin, Fixture):
    def test_launch_status_and_independent_verify(self):
        launched = self.cli(*self.argv("launch"))
        self.assertEqual(launched.returncode, 0, launched.stderr)
        self.assertTrue(json.loads(launched.stdout)["launched"])
        self.assertTrue(wait_for(lambda: (self.out / "run.done").exists()))
        status = self.cli("status", str(self.out))
        self.assertEqual(status.returncode, 0)
        self.assertEqual(json.loads(status.stdout)["state"], "succeeded")
        self.assertEqual(json.loads(status.stdout)["profile"], "block")
        good = self.verify_cli(profile="block")
        self.assertEqual(good.returncode, 0, good.stderr)
        result = json.loads(good.stdout)
        self.assertTrue(result["verified"])
        self.assertEqual((result["kind"], result["profile"], result["expected_image_id"]),
                         ("groth16", "block", IMAGE_ID))
        inner = self.verify_cli(profile="block", receipt=self.out / "private" / "inner.bin")
        self.assertEqual(inner.returncode, 1)
        self.assertFalse(json.loads(inner.stdout)["verified"])
        self.assertIsNone(json.loads(inner.stdout)["kind"])

    def test_waits_on_heavy_lock_then_runs(self):
        with open(self.lock, "a") as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            self.assertEqual(self.cli(*self.argv("launch")).returncode, 0)
            self.assertTrue(wait_for(lambda: (self.out / "status.json").exists()
                                     and self.status()["state"] == "waiting-for-heavy-lock"))
            time.sleep(0.5)
            self.assertEqual(self.status()["stages"], [])
            waiting = self.cli("status", str(self.out))
            self.assertEqual(waiting.returncode, 2)
            self.assertTrue(json.loads(waiting.stdout)["runner_alive"])
        self.assertTrue(wait_for(lambda: (self.out / "run.done").exists()))
        self.assertEqual((self.out / "run.done").read_text(), "0\n")

    def test_sigterm_to_worker_kills_stage_and_writes_marker(self):
        self.mocks(wrap_mode="hang")
        self.assertEqual(self.cli(*self.argv("launch")).returncode, 0)
        self.assertTrue(wait_for(self.pidfile.exists))
        time.sleep(0.2)
        leader, child = map(int, self.pidfile.read_text().split())
        os.kill(self.status()["pid"], signal.SIGTERM)
        self.assertTrue(wait_for(lambda: (self.out / "run.done").exists()))
        self.assertEqual((self.out / "run.done").read_text(), "1\n")
        self.assertTrue(wait_for(lambda: pid_gone(leader) and pid_gone(child), 5))
        self.assertIn("Interrupted", self.status()["error"])
        self.assertEqual(self.outcome()["outcome"], "failed")

    def test_status_before_start(self):
        result = self.cli("status", str(self.root / "nothing"))
        self.assertEqual(result.returncode, 2)
        self.assertEqual(json.loads(result.stdout)["state"], "not-started")


class IndependentVerifyTests(CliMixin, Fixture):
    """The standalone `verify` binds a caller-chosen profile and image id."""

    def setUp(self):
        super().setUp()
        self.assertEqual(demo.main(self.argv()), 0)
        self.calls.unlink()

    def test_expected_image_id_and_profile_are_required(self):
        for missing in ({"image": None, "profile": "block"}, {"profile": None}):
            with self.subTest(missing=missing):
                result = self.verify_cli(**missing)
                self.assertEqual(result.returncode, 2)  # argparse usage error
                self.assertIn("required", result.stderr)
        self.assertEqual(self.wrap_calls(), [])

    def test_wrong_expected_image_refused_before_verify_runs(self):
        result = self.verify_cli(profile="block", image=OTHER_IMAGE_ID)
        self.assertEqual(result.returncode, 1)
        out = json.loads(result.stdout)
        self.assertFalse(out["verified"])
        self.assertIsNone(out["kind"])
        self.assertIn("image id", out["reason"])
        self.assertEqual(self.wrap_calls(), ["image-id"])

    def test_malformed_expected_image_refused(self):
        result = self.verify_cli(profile="block", image=IMAGE_ID.upper())
        self.assertEqual(result.returncode, 1)
        self.assertIn("64 lowercase hex", result.stderr)
        self.assertEqual(self.wrap_calls(), [])

    def test_wrong_profile_is_refused_not_inferred(self):
        # A block policy/receipt checked as token: refused on the policy tag
        # before any binary runs, whatever the candidate files say.
        result = self.verify_cli(profile="token")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not a token profile statement", result.stderr)
        self.assertEqual(self.wrap_calls(), [])

    def test_block_verify_passes_no_image_argument(self):
        result = self.verify_cli(profile="block")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.wrap_calls(), ["image-id", "verify"])


class TokenIndependentVerifyTests(CliMixin, Fixture):
    profile = "token"

    def setUp(self):
        super().setUp()
        self.assertEqual(demo.main(self.argv()), 0)
        self.calls.unlink()

    def test_token_verify_accepts_with_pinned_image(self):
        result = self.verify_cli(profile="token")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        out = json.loads(result.stdout)
        self.assertEqual((out["verified"], out["kind"], out["profile"]),
                         (True, "groth16", "token"))
        self.assertEqual(self.wrap_calls(), ["image-id", "verify"])

    def test_token_candidate_checked_as_block_is_refused(self):
        result = self.verify_cli(profile="block")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not a block profile statement", result.stderr)
        self.assertEqual(self.wrap_calls(), [])

    def test_token_verify_with_other_image_refused(self):
        result = self.verify_cli(profile="token", image=OTHER_IMAGE_ID)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(json.loads(result.stdout)["verified"])
        self.assertEqual(self.wrap_calls(), ["image-id"])

    def test_token_inner_receipt_refused(self):
        result = self.verify_cli(profile="token", receipt=self.out / "private" / "inner.bin")
        self.assertEqual(result.returncode, 1)
        self.assertIsNone(json.loads(result.stdout)["kind"])


if __name__ == "__main__":
    unittest.main()
