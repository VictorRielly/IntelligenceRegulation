#!/usr/bin/env python3
"""One-command P1 FFN *component* demo on the public synthetic fixture.

Registers the public weights, proves one bound FFN with private input, output
and intermediate values, then verifies the saved receipt bytes in a separate
process from trusted policy the verifier did not take from the candidate
receipt. Six rejection controls check that the verifier actually refuses.

This is NOT a complete private block and NOT an MVP: whole-proof zero knowledge
for the P1 private set is unresolved, and the tensors are a small synthetic
public fixture, not a real model. See docs/zkmatrix-poc/ZK60_P1_DEMO.md.

CPU only, standard library only. The Rust example is used unchanged. Heavy
runs belong under the shared heavy lock; this script does not take it.
"""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

SCHEMA = 1
PROFILE = "ffn-v3-mr1-fresh-io-poc/2"
EXAMPLE = "zk60_bound_ffn"
FIXTURE = "public-synthetic-T32-d16-f16"
POLICY_MAGIC = b"HFFNEXP1"
POLICY_BYTES = 112
INPUT_SCALE, OUTPUT_SCALE = -3, 0
CONTEXT_BYTES = 32
TEXT_KEPT = 2000


class DemoError(Exception):
    """Any unexpected exit, crash, timeout or malformed output."""


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def tail(text):
    return text[-TEXT_KEPT:] if text else ""


def launch(command, cwd, env, timeout):
    """Run one child process. Tests replace this seam."""
    done = subprocess.run(command, cwd=str(cwd), env=env, capture_output=True,
                          text=True, timeout=timeout)
    return done.returncode, done.stdout, done.stderr


def clean_env(threads):
    """Drop every HL_* switch (fixture randomness, HL_GPU) and bound threads."""
    removed = sorted(k for k in os.environ if k.startswith("HL_"))
    env = {k: v for k, v in os.environ.items() if not k.startswith("HL_")}
    env["RAYON_NUM_THREADS"] = str(threads)
    env["CARGO_BUILD_JOBS"] = str(threads)
    return env, removed


class Demo:
    def __init__(self, args):
        self.source = args.source.resolve()
        self.out = args.output
        self.supplied = args.binary
        self.cargo = args.cargo
        self.timeout = args.timeout
        self.build_timeout = args.build_timeout
        self.env, removed = clean_env(args.threads)
        self.binary = None
        self.manifest = {
            "schema": SCHEMA,
            "tool": "scripts/zk60_p1_demo.py",
            "tool_sha256": sha256(Path(__file__).resolve().read_bytes()),
            "profile": PROFILE,
            "privacy_target": "P1 (hidden input, output, intermediate values; public weights)",
            "fixture": FIXTURE,
            "status": "started",
            "path_tokens": {"<source>": "the source checkout root", "<output>": "--output"},
            "environment": {
                "removed_env_prefix": "HL_",
                "removed_env_names": removed,
                "rayon_num_threads": str(args.threads),
                "gpu_requested": False,
                "legacy_privacy_flags": [],
                "modes_invoked": ["p1"],
            },
            "build": {"performed": False},
            "steps": [],
            "artifacts": [],
            "rejection_controls": [],
            "timing_note": "seconds are diagnostics on a shared box, not a benchmark",
            "coverage": {
                "covers": [
                    "public-weight registration executed before any proving",
                    "one P1 bound-FFN proof over the public synthetic fixture",
                    "verification of the saved receipt bytes in a fresh process, from"
                    " caller-held context, registered public weight root and trusted"
                    " endpoint policy",
                    "six verifier rejection controls",
                ],
                "does_not_cover": [
                    "whole-proof zero knowledge for the P1 private set (open)",
                    "a complete transformer block, a multi-layer run or an MVP",
                    "real model weights or a downloaded checkpoint",
                    "attention, normalization, composition, repeated-request behavior",
                    "P3 weight privacy and authenticated private model identity",
                    "any performance or timing claim",
                ],
            },
            "status_claims": {
                "component_demo_only": True,
                "full_private_block": False,
                "mvp": False,
                "privacy_review_complete": False,
                "whole_proof_zero_knowledge_established": False,
            },
        }

    # ---- bookkeeping -----------------------------------------------------
    def display(self, path):
        path = Path(path)
        for root, token in ((self.out, "<output>"), (self.source, "<source>")):
            try:
                return f"{token}/{path.relative_to(root)}"
            except ValueError:
                continue
        return str(path)

    def save(self):
        (self.out / "manifest.json").write_text(json.dumps(self.manifest, indent=2) + "\n")

    def record_artifact(self, name, path):
        data = Path(path).read_bytes()
        self.manifest["artifacts"].append({"name": name, "path": self.display(path),
                                           "bytes": len(data), "sha256": sha256(data)})
        return data

    # ---- process steps ---------------------------------------------------
    def step(self, name, arguments, expect_exit=0):
        command = [str(self.binary)] + [str(a) for a in arguments]
        entry = {"name": name, "command": [self.display(command[0])] + command[1:],
                 "cwd": "<output>", "expected_exit": expect_exit}
        self.manifest["steps"].append(entry)
        start = time.monotonic()
        try:
            code, out, err = launch(command, self.out, self.env, self.timeout)
        except subprocess.TimeoutExpired:
            entry["seconds"] = round(time.monotonic() - start, 3)
            entry["error"] = "timeout"
            self.save()
            raise DemoError(f"{name}: no exit within {self.timeout} s")
        except OSError as exc:
            entry["seconds"] = round(time.monotonic() - start, 3)
            entry["error"] = str(exc)
            self.save()
            raise DemoError(f"{name}: could not run the example: {exc}")
        entry["seconds"] = round(time.monotonic() - start, 3)
        entry["exit_code"] = code
        entry["stderr"] = tail(err)
        if code != expect_exit:
            entry["stdout"] = tail(out)
            self.save()
            if expect_exit == 1 and code == 0:
                raise DemoError(f"{name}: the verifier ACCEPTED a case it must reject")
            if code < 0:
                raise DemoError(f"{name}: killed by signal {-code}")
            raise DemoError(f"{name}: exit {code} (expected {expect_exit}): {tail(err).strip()}")
        if expect_exit != 0:
            if out.strip():
                self.save()
                raise DemoError(f"{name}: a rejected run still printed a result line")
            if not err.strip():
                self.save()
                raise DemoError(f"{name}: rejection carried no verifier message")
            self.manifest["rejection_controls"].append(name)
            self.save()
            return None
        try:
            parsed = json.loads(out)
        except ValueError as exc:
            entry["stdout"] = tail(out)
            self.save()
            raise DemoError(f"{name}: malformed result JSON: {exc}")
        if not isinstance(parsed, dict):
            entry["stdout"] = tail(out)
            self.save()
            raise DemoError(f"{name}: result JSON is not an object")
        entry["stdout_json"] = parsed
        self.save()
        return parsed

    def field(self, name, parsed, key, expected=None):
        if key not in parsed:
            raise DemoError(f"{name}: result JSON has no {key!r}")
        if expected is not None and (type(parsed[key]) is not type(expected)
                                     or parsed[key] != expected):
            raise DemoError(f"{name}: {key} is {parsed[key]!r}, expected {expected!r}")
        return parsed[key]

    # ---- preparation -----------------------------------------------------
    def make_output(self):
        self.out.mkdir(parents=True, exist_ok=False)
        self.out = self.out.resolve()

    def build(self):
        """Build the unchanged CPU example, or adopt a supplied one."""
        if self.supplied is not None:
            self.binary = self.supplied.resolve(strict=True)
            self.manifest["build"] = {"performed": False, "reason": "--binary supplied"}
        else:
            manifest_path = self.source / "hashline" / "Cargo.toml"
            if not manifest_path.is_file():
                raise DemoError(f"no cargo manifest at {self.display(manifest_path)};"
                                " pass --source or --binary")
            options = ["build", "--locked", "--release", "--manifest-path"]
            rest = ["--example", EXAMPLE, "--message-format", "json-render-diagnostics"]
            command = [self.cargo] + options + [str(manifest_path)] + rest
            record = {"performed": True, "flags": ["--locked", "--release"],
                      "features": "default (CPU)", "manifest": self.display(manifest_path),
                      "command": [self.cargo] + options
                                 + [self.display(manifest_path)] + rest}
            self.manifest["build"] = record
            start = time.monotonic()
            try:
                code, out, err = launch(command, self.source, self.env, self.build_timeout)
            except subprocess.TimeoutExpired:
                record["seconds"] = round(time.monotonic() - start, 3)
                raise DemoError(f"cargo build: no exit within {self.build_timeout} s")
            except OSError as exc:
                record["seconds"] = round(time.monotonic() - start, 3)
                raise DemoError(f"cargo build: could not run {self.cargo!r}: {exc}")
            record["seconds"] = round(time.monotonic() - start, 3)
            record["exit_code"] = code
            if code != 0:
                record["stderr"] = tail(err)
                raise DemoError(f"cargo build: exit {code}: {tail(err).strip()}")
            self.binary = self.executable(out)
            record["stderr"] = tail(err)
        data = self.binary.read_bytes()
        self.manifest["binary"] = {"supplied": self.supplied is not None,
                                   "path": self.display(self.binary),
                                   "bytes": len(data), "sha256": sha256(data)}
        example_source = self.source / "hashline" / "examples" / f"{EXAMPLE}.rs"
        if example_source.is_file():
            self.manifest["example_source"] = {
                "path": self.display(example_source),
                "sha256": sha256(example_source.read_bytes()), "modified_by_demo": False}
        self.save()

    def executable(self, stdout):
        """Take the example path out of cargo's JSON messages (target dir agnostic)."""
        for line in stdout.splitlines():
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                message = json.loads(line)
            except ValueError:
                continue
            if not isinstance(message, dict):
                raise DemoError("cargo build emitted a non-object JSON message")
            target = message.get("target") or {}
            if not isinstance(target, dict):
                raise DemoError("cargo build emitted a malformed target")
            kinds = target.get("kind") or []
            if not isinstance(kinds, list) or any(not isinstance(k, str) for k in kinds):
                raise DemoError("cargo build emitted a malformed target kind")
            if (message.get("reason") == "compiler-artifact"
                    and target.get("name") == EXAMPLE
                    and "example" in kinds
                    and message.get("executable")):
                if not isinstance(message["executable"], str):
                    raise DemoError("cargo build emitted a malformed executable path")
                return Path(message["executable"]).resolve(strict=True)
        raise DemoError("cargo build reported no executable for the example")

    # ---- the demo --------------------------------------------------------
    def run(self):
        self.build()

        prepared = self.step("register_public_weights", ["prepare"])
        self.field("register_public_weights", prepared, "proving_executed", False)
        root = self.field("register_public_weights", prepared, "public_weight_root")
        if not (isinstance(root, str) and len(root) == 64
                and all(c in "0123456789abcdefABCDEF" for c in root)):
            raise DemoError("register_public_weights: public weight root is not a digest")
        self.manifest["public_weight_root"] = {
            "value": root,
            "source": "the prepare subcommand, run before any proving",
            "used_for_verification": True}

        context = os.urandom(CONTEXT_BYTES).hex()
        self.manifest["caller_context"] = {
            "value": context, "bytes": CONTEXT_BYTES,
            "source": "fresh OS randomness (os.urandom) in this process",
            "held_by": "caller; supplied to prove and to verify independently"}
        self.save()

        proved = self.step("prove_p1", ["prove", "p1", context, "p1.expected", "p1.receipt"])
        self.field("prove_p1", proved, "mode", "P1")
        self.field("prove_p1", proved, "policy_saved_before_proving", True)
        self.field("prove_p1", proved, "verified_from_bytes", True)
        policy = self.record_artifact("endpoint_policy", self.out / "p1.expected")
        receipt = self.record_artifact("receipt", self.out / "p1.receipt")
        wire_bytes = self.field("prove_p1", proved, "wire_bytes")
        if type(wire_bytes) is not int or wire_bytes <= 0 or len(receipt) != wire_bytes:
            raise DemoError("prove_p1: wire_bytes disagrees with the saved receipt")
        self.check_policy(policy, context, proved)
        self.save()

        accepted = self.step("verify_p1", ["verify", "p1", root, context,
                                           "p1.expected", "p1.receipt"])
        self.field("verify_p1", accepted, "mode", "P1")
        self.field("verify_p1", accepted, "verified_from_bytes", True)
        self.field("verify_p1", accepted, "proving_executed", False)
        self.field("verify_p1", accepted, "wire_bytes", len(receipt))
        self.manifest["verification"] = {
            "process": "separate from proving; reads only saved bytes",
            "trust_inputs": ["caller-held request context",
                             "public weight root from registration",
                             "endpoint policy file written before FFN proving"],
            "policy_derived_from_candidate_receipt": False}
        self.save()

        self.controls(root, context, policy, receipt)

        if (self.out / "p1.receipt").read_bytes() != receipt:
            raise DemoError("the saved receipt changed during the controls")
        if (self.out / "p1.expected").read_bytes() != policy:
            raise DemoError("the saved endpoint policy changed during the controls")
        self.manifest["status"] = "passed"
        self.save()
        return {"status": "passed", "steps": len(self.manifest["steps"]),
                "rejection_controls": len(self.manifest["rejection_controls"]),
                "manifest": str(self.out / "manifest.json")}

    def check_policy(self, policy, context, proved):
        """Check the trusted policy against caller-held values, not the receipt."""
        if len(policy) != POLICY_BYTES or policy[:8] != POLICY_MAGIC:
            raise DemoError("endpoint policy is not a 112-byte HFFNEXP1 record")
        if policy[8:40].hex() != context:
            raise DemoError("endpoint policy does not carry the caller's context")
        scales = (int.from_bytes(policy[40:44], "little", signed=True),
                  int.from_bytes(policy[44:48], "little", signed=True))
        if scales != (INPUT_SCALE, OUTPUT_SCALE):
            raise DemoError(f"endpoint policy scales are {scales}")
        if policy[48:80].hex() != self.field("prove_p1", proved, "input_root"):
            raise DemoError("endpoint policy input root disagrees with the prover")
        if policy[80:112].hex() != self.field("prove_p1", proved, "output_root"):
            raise DemoError("endpoint policy output root disagrees with the prover")

    def controls(self, root, context, policy, receipt):
        """Cases the verifier must refuse. Any acceptance fails the demo."""
        other_context = os.urandom(CONTEXT_BYTES).hex()
        if other_context == context:
            raise DemoError("the control context collided with the caller context")
        wrong_root = "00" * 32
        if wrong_root == root:
            raise DemoError("the control weight root collided with the registered root")

        wrong_policy = bytearray(policy)
        wrong_policy[48] ^= 1
        variants = [("wrong_endpoint_policy", "p1.wrong_policy.expected", bytes(wrong_policy))]
        tampered = bytearray(receipt)
        tampered[-1] ^= 1
        variants += [("tampered_receipt", "p1.tampered.receipt", bytes(tampered)),
                     ("truncated_receipt", "p1.truncated.receipt", receipt[:-1]),
                     ("trailing_receipt", "p1.trailing.receipt", receipt + b"\x00")]
        for name, filename, data in variants:
            (self.out / filename).write_bytes(data)
            self.record_artifact(name, self.out / filename)

        self.step("reject_wrong_context",
                  ["verify", "p1", root, other_context, "p1.expected", "p1.receipt"], 1)
        self.step("reject_wrong_public_weight",
                  ["verify", "p1", wrong_root, context, "p1.expected", "p1.receipt"], 1)
        self.step("reject_wrong_endpoint_policy",
                  ["verify", "p1", root, context, "p1.wrong_policy.expected", "p1.receipt"], 1)
        for name, filename, _ in variants[1:]:
            self.step(f"reject_{name}", ["verify", "p1", root, context, "p1.expected", filename], 1)


def parse_args(argv):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, required=True,
                        help="new directory for artifacts and manifest.json;"
                             " an existing path is never written to")
    parser.add_argument("--binary", type=Path,
                        help=f"an already built CPU {EXAMPLE} example; omit to build it")
    parser.add_argument("--source", type=Path, default=Path(__file__).resolve().parents[1],
                        help="source checkout root (default: this script's repository)")
    parser.add_argument("--cargo", default=os.environ.get("CARGO", "cargo"),
                        help="cargo to build with (default: $CARGO or cargo)")
    parser.add_argument("--threads", type=int, default=2, help="RAYON_NUM_THREADS (default 2)")
    parser.add_argument("--timeout", type=float, default=1800.0,
                        help="per-process timeout in seconds (default 1800)")
    parser.add_argument("--build-timeout", type=float, default=3600.0,
                        help="cargo build timeout in seconds (default 3600)")
    args = parser.parse_args(argv)
    if not 1 <= args.threads <= 16:
        parser.error("--threads must be between 1 and 16")
    for flag, value in (("--timeout", args.timeout), ("--build-timeout", args.build_timeout)):
        if not math.isfinite(value) or value <= 0:
            parser.error(f"{flag} must be finite and greater than zero")
    return args


def main(argv=None):
    args = parse_args(argv)
    demo = Demo(args)
    try:
        demo.make_output()
    except OSError as exc:
        print(f"zk60_p1_demo: --output must be a new path: {exc}", file=sys.stderr)
        return 1
    try:
        summary = demo.run()
    except (DemoError, OSError) as exc:
        steps = demo.manifest["steps"]
        demo.manifest["status"] = "failed"
        demo.manifest["failure"] = {"reason": str(exc),
                                    "step": steps[-1]["name"] if steps else "build"}
        demo.save()
        print(f"zk60_p1_demo FAILED: {exc}", file=sys.stderr)
        print(f"details: {demo.out / 'manifest.json'}", file=sys.stderr)
        return 1
    print(json.dumps(summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
