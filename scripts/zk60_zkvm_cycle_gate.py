#!/usr/bin/env python3
"""Private cycle diagnostics for the zkVM block host's executor-only stage.

Runs the prebuilt ``zk60-block-host`` over a fixed hostile input set (all
zero, small positive/negative values, alternating values, a row-constant shape, a
fresh random small input, a ramp, and two larger probes that may be refused), and records for every accepted pattern
the executor's total cycles, user cycles and segment count. Identical counts
across every accepted pattern are what "constant cycles" means here; any
difference is recorded as private executor variation, with its spread.
The public Groth16 receipt does not expose segment or cycle counts. No
receipt privacy or constant-time theorem follows from this finite input set.

This is a measurement, not a proof stage: it never proves, never takes
``/tmp/zk-heavy.lock``, and creates no receipt. Only the executor runs, which
is cheap. Standard library only. Every binary (host, r0vm) and the public
model are explicit prerequisites; nothing is built or downloaded. Children run
one at a time, in their own process group, under a bounded timeout, with
``RISC0_*``, ``BONSAI_*`` and ``RUST_LOG*`` removed from their environment.

Inputs, salts and request bytes are witness material: they are written only
into per-pattern 0700 work directories, never printed and never copied into
the output JSON, which carries counts and gate-authored messages only. The
work tree is deleted at the end unless ``--keep`` is given.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import time

SCHEMA = 1
ELEMENTS = 512
INPUT_BYTES = ELEMENTS * 2
ROW = 16
SMALL = 3
PROBE = 64
DEFAULT_TIMEOUT = 900
KILL_GRACE = 10.0
SCRUBBED_PREFIXES = ("BONSAI_", "RISC0_", "RUST_LOG")
# Only these exact host messages are copied into the record. Everything else
# is withheld, so a message that ever carried a value cannot reach the JSON.
STATIC_REFUSALS = (
    "zk60 block: block computation refused input",
    "zk60 block: input must contain exactly 512 little-endian i16 words",
    "zk60 block: file size/type refused",
    "zk60 block: file size refused",
    "zk60 block: output directories must be new and disjoint",
    "zk60 block: invalid public model encoding",
    "zk60 block: invalid private request encoding",
    "zk60 block: receipt output already exists",
)
WITHHELD = "host refused; message withheld (not a recognized static refusal)"


class GateError(Exception):
    """An operational failure. Never used for a leakage verdict."""


# ---- the hostile input set ----------------------------------------------
def _rows(value_of_row):
    return [value_of_row(i // ROW) for i in range(ELEMENTS)]


def pattern_values(name):
    """The 512 i16 values of one named pattern."""
    if name == "zero":
        return [0] * ELEMENTS
    if name == "pos3":
        return [SMALL] * ELEMENTS
    if name == "neg3":
        return [-SMALL] * ELEMENTS
    if name == "alt":
        return [SMALL if i % 2 == 0 else -SMALL for i in range(ELEMENTS)]
    if name == "rows_equal":
        # Every input row is constant; rows differ. This does not assert that
        # the later scores tie (position-dependent RoPE can break that).
        return _rows(lambda r: (r % 7) - 3)
    if name == "random_small":
        return [secrets.randbelow(2 * SMALL + 1) - SMALL for _ in range(ELEMENTS)]
    if name == "ramp":
        return [(i % 7) - 3 for i in range(ELEMENTS)]
    if name == "pos64":
        return [PROBE] * ELEMENTS
    if name == "neg64":
        return [-PROBE] * ELEMENTS
    raise GateError(f"unknown pattern: {name!r}")


PATTERNS = (
    ("zero", "all zero"),
    ("pos3", "all +3 (small fixture input)"),
    ("neg3", "all -3 (small fixture input)"),
    ("alt", "alternating +3/-3"),
    ("rows_equal", "each input row of 16 constant, rows differing"),
    ("random_small", "fresh uniform values in [-3,3] from secrets"),
    ("ramp", "(i mod 7) - 3"),
    ("pos64", "all +64: larger probe, may be refused"),
    ("neg64", "all -64: larger probe, may be refused"),
)


def encode_input(values):
    if len(values) != ELEMENTS:
        raise GateError("an input pattern must have exactly 512 values")
    return b"".join(int(v).to_bytes(2, "little", signed=True) for v in values)


# ---- filesystem helpers --------------------------------------------------
def new_directory(path, mode=0o700):
    """Create a new directory; refuse to reuse or follow an existing one."""
    path = Path(path).absolute()
    if os.path.lexists(path):
        raise GateError(f"{path} already exists; the gate needs a new directory")
    path.mkdir(mode=mode, parents=False)
    return path


def write_private(path, data):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def regular_executable(path, what):
    info = os.stat(path)
    if not stat.S_ISREG(info.st_mode) or not os.access(path, os.X_OK):
        raise GateError(f"{what} must be an executable regular file: {path}")
    return Path(path).absolute()


# ---- process control -----------------------------------------------------
def child_env():
    """The parent environment minus prover, cloud and logging switches.

    Nothing is added back: the host sets its own `RUST_LOG`/`RUST_BACKTRACE`
    and scrubs its environment again before the prover starts.
    """
    return {k: v for k, v in os.environ.items() if not k.startswith(SCRUBBED_PREFIXES)}


def _exited(pid):
    return os.waitid(os.P_PID, pid, os.WEXITED | os.WNOHANG | os.WNOWAIT) is not None


def _signal_group(pgid, sig):
    try:
        os.killpg(pgid, sig)
    except ProcessLookupError:
        pass


def run_bounded(command, out_path, err_path, timeout, grace=KILL_GRACE):
    """Run one child in its own session, output to private 0600 files.

    Returns (exit_code, timed_out, seconds). On timeout or interruption the
    whole process group gets SIGTERM and then SIGKILL, so no r0vm server is
    left behind.
    """
    out = os.open(out_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        err = os.open(err_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        try:
            start = time.monotonic()
            proc = subprocess.Popen([str(c) for c in command], env=child_env(),
                                    stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                    start_new_session=True, close_fds=True)
        finally:
            os.close(err)
    finally:
        os.close(out)
    pgid = proc.pid  # start_new_session makes the child its own group leader
    deadline = start + timeout
    timed_out = False
    try:
        delay = 0.01
        while not _exited(proc.pid):
            if time.monotonic() >= deadline:
                timed_out = True
                break
            time.sleep(min(delay, max(0.0, deadline - time.monotonic())))
            delay = min(delay * 2, 0.5)
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
    return code, timed_out, round(time.monotonic() - start, 3)


def first_line(path):
    try:
        with open(path, "r", errors="replace") as f:
            return f.readline().strip()
    except OSError:
        return ""


def refusal_message(err_path):
    line = first_line(err_path)
    return line if line in STATIC_REFUSALS else WITHHELD


def execute_report(out_path):
    """The single JSON line the host prints in execute mode."""
    found = []
    with open(out_path, "r", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line.startswith("{"):
                continue
            try:
                value = json.loads(line)
            except ValueError:
                continue
            if isinstance(value, dict) and "execution_matches_policy" in value:
                found.append(value)
    if len(found) != 1:
        raise GateError(f"expected exactly one execute JSON line, saw {len(found)}")
    report = found[0]
    if report.get("mvp_complete") is not False:
        raise GateError("child claimed mvp_complete; refused")
    if report.get("execution_matches_policy") is not True:
        raise GateError("execute did not report a policy match")
    if report.get("proof_created") is not False:
        raise GateError("execute did not explicitly report no proof creation")
    for field in ("total_cycles", "user_cycles", "segments"):
        if type(report.get(field)) is not int or report[field] <= 0:
            raise GateError(f"execute report is missing a usable {field}")
    if report["user_cycles"] > report["total_cycles"]:
        raise GateError("user cycles exceed padded total cycles")
    if type(report.get("segment_limit_po2")) is not int or report["segment_limit_po2"] != 18:
        raise GateError("unexpected segment limit for this fixed integration")
    return report


# ---- the gate ------------------------------------------------------------
def host_image_id(host, work, timeout):
    code, timed_out, _ = run_bounded([host, "image-id"], work / "image-id.out",
                                     work / "image-id.err", timeout)
    if timed_out or code != 0:
        raise GateError("host image-id failed")
    line = first_line(work / "image-id.out")
    if len(line) != 64 or any(c not in "0123456789abcdef" for c in line):
        raise GateError("host image-id did not print a 64-hex image id")
    return line


def run_pattern(name, description, host, model, r0vm, work, timeout):
    """prepare-input then execute for one pattern. Returns its record."""
    area = new_directory(work / name)
    write_private(area / "input.i16", encode_input(pattern_values(name)))
    row = {"name": name, "description": description, "accepted": False}
    code, timed_out, seconds = run_bounded(
        [host, "prepare-input", model, area / "input.i16", area / "public", area / "private"],
        area / "prepare.out", area / "prepare.err", timeout)
    row.update(prepare_seconds=seconds)
    if timed_out:
        raise GateError(f"pattern {name}: prepare-input timed out after {timeout}s")
    if code != 0:
        row.update(stage="prepare-input", exit_code=code, refusal=refusal_message(area / "prepare.err"))
        return row
    code, timed_out, seconds = run_bounded(
        [host, "execute", area / "public" / "model.bin", area / "private" / "request.bin",
         area / "public" / "policy.bin", area / "private" / "exec.bin", r0vm],
        area / "execute.out", area / "execute.err", timeout)
    row.update(execute_seconds=seconds)
    if timed_out:
        raise GateError(f"pattern {name}: execute timed out after {timeout}s")
    if code != 0:
        row.update(stage="execute", exit_code=code, refusal=refusal_message(area / "execute.err"))
        return row
    if os.path.lexists(area / "private" / "exec.bin"):
        raise GateError(f"pattern {name}: execute unexpectedly wrote a receipt")
    report = execute_report(area / "execute.out")
    row.update(accepted=True, stage="execute", exit_code=0,
               total_cycles=report["total_cycles"], user_cycles=report["user_cycles"],
               segments=report["segments"],
               segment_limit_po2=report.get("segment_limit_po2"))
    return row


def leakage_sentence(accepted, shapes, totals, users):
    """The declared-leakage sentence, naming the quantity that is not constant."""
    count = len(accepted)
    spread = max(totals) - min(totals)
    user_spread = max(users) - min(users)
    if len(shapes) == 1:
        share = 100.0 * user_spread / max(totals)
        return (
            f"Declared timing leakage: over {count} accepted input patterns the padded total "
            f"({max(totals)} cycles) and the segment count ({accepted[0]['segments']}) are "
            f"identical in this finite private executor sample; the executor's "
            f"unpadded USER cycle count is not, spanning {user_spread} cycles ({min(users)} to "
            f"{max(users)}, {share:.4f}% of the padded total). Anything that observes the "
            f"executor's own work -- host-side timing or r0vm telemetry -- may observe "
            f"input-dependent work. The public Groth16 receipt exposes no cycle or segment counts."
        )
    return (
        f"Declared timing leakage: the executor-only stage is NOT constant-cycle over {count} "
        f"accepted input patterns; padded total cycles span {spread} ({min(totals)} to "
        f"{max(totals)}) across {len(shapes)} distinct (total_cycles, segments) shapes, and user "
        f"cycles span {user_spread} ({min(users)} to {max(users)}). These are private executor "
        f"measurements, not fields of the public Groth16 receipt; they demonstrate input-dependent "
        f"work without quantifying information leakage to a timing observer."
    )


def verdict(rows):
    """Constant-cycle verdict over the accepted patterns.

    Two questions are reported separately, because they have different
    consequences. `constant_total_cycles` covers the padded total and the
    segment count in private executor telemetry. `constant_user_cycles`
    covers the executor's unpadded work, which a host-side observer can time.
    `constant_cycles` is true only when both are.
    """
    accepted = [r for r in rows if r["accepted"]]
    if len(accepted) < 2:
        raise GateError("fewer than two patterns accepted; there is nothing to compare")
    shapes = {}
    for r in accepted:
        shapes.setdefault((r["total_cycles"], r["segments"]), []).append(r["name"])
    totals = [r["total_cycles"] for r in accepted]
    users = [r["user_cycles"] for r in accepted]
    constant_total = len(shapes) == 1
    constant_user = len(set(users)) == 1
    out = {
        "accepted_patterns": [r["name"] for r in accepted],
        "refused_patterns": [r["name"] for r in rows if not r["accepted"]],
        "distinct_cycle_shapes": [
            {"total_cycles": t, "segments": s, "patterns": sorted(names)}
            for (t, s), names in sorted(shapes.items())
        ],
        "distinct_user_cycle_counts": sorted(set(users)),
        "constant_cycles": constant_total and constant_user,
        "constant_total_cycles": constant_total,
        "constant_user_cycles": constant_user,
        "total_cycle_spread": max(totals) - min(totals),
        "user_cycle_spread": max(users) - min(users),
        "declared_leakage": None,
    }
    if not out["constant_cycles"]:
        out["declared_leakage"] = leakage_sentence(accepted, shapes, totals, users)
    return out


def gate(args):
    host = regular_executable(args.host, "--host")
    r0vm = regular_executable(args.r0vm, "--r0vm")
    model = Path(args.model).absolute()
    if not stat.S_ISREG(os.stat(model).st_mode):
        raise GateError(f"--model must be a regular file: {model}")
    out = new_directory(args.out)
    work = new_directory(out / "work")
    started = time.time()
    try:
        image_id = host_image_id(host, work, args.timeout)
        rows = [run_pattern(name, description, host, model, r0vm, work, args.timeout)
                for name, description in PATTERNS]
        record = {
            "schema": SCHEMA,
            "tool": "zk60_zkvm_cycle_gate",
            "coverage": "executor-only cycle and segment counts of one fixed "
                        "T32/d16/f16 integer transformer block; no proof is created",
            "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(started)),
            "host": {"path": str(host), "sha256": sha256_file(host)},
            "model": {"path": str(model), "sha256": sha256_file(model),
                      "bytes": os.stat(model).st_size},
            "r0vm": {"path": str(r0vm), "sha256": sha256_file(r0vm)},
            "image_id": image_id,
            "timeout_seconds": args.timeout,
            "scrubbed_prefixes": list(SCRUBBED_PREFIXES),
            "patterns": rows,
            "mvp_complete": False,
        }
        record.update(verdict(rows))
        write_private(out / "cycle_gate.json", (json.dumps(record, indent=2) + "\n").encode())
    finally:
        if not args.keep:
            shutil.rmtree(work, ignore_errors=True)
    return record


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--host", required=True, help="prebuilt zk60-block-host binary")
    p.add_argument("--model", required=True, help="public model.bin")
    p.add_argument("--r0vm", required=True, help="absolute path to the local r0vm")
    p.add_argument("--out", required=True, help="NEW output directory, created 0700")
    p.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT,
                   help=f"per-child timeout in seconds (default {DEFAULT_TIMEOUT})")
    p.add_argument("--keep", action="store_true",
                   help="keep the private per-pattern work tree (0700) for diagnosis")
    p.add_argument("--require-constant", action="store_true",
                   help="exit 1 when the accepted patterns are not constant-cycle")
    args = p.parse_args(argv)
    if not 1 <= args.timeout <= 3600:
        p.error("--timeout must be between 1 and 3600 seconds")
    try:
        record = gate(args)
    except (GateError, OSError) as err:
        # OSError covers a missing prerequisite or an unusable --out parent:
        # report it the same way and leave no partial record behind.
        print(f"zk60 cycle gate: {err}", file=sys.stderr)
        return 1
    print(json.dumps({
        "cycle_gate": True,
        "constant_cycles": record["constant_cycles"],
        "constant_total_cycles": record["constant_total_cycles"],
        "constant_user_cycles": record["constant_user_cycles"],
        "accepted": len(record["accepted_patterns"]),
        "refused": len(record["refused_patterns"]),
        "total_cycle_spread": record["total_cycle_spread"],
        "user_cycle_spread": record["user_cycle_spread"],
        "out": str(Path(args.out).absolute() / "cycle_gate.json"),
        "mvp_complete": False,
    }))
    if args.require_constant and not record["constant_cycles"]:
        print("zk60 cycle gate: " + record["declared_leakage"], file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
