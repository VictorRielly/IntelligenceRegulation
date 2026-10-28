"""The prover interface and its implementations.

    ClassifierProver.prove(item)   -> ProofRecord   (blocking convenience)
    ClassifierProver.verify(record) -> Verdict      (blocking convenience)

A proof takes minutes, so the web app never blocks on it: the queue worker calls `start` (which
launches a DETACHED pipeline, every heavy leaf through the resource guard), `poll`, and `collect`
(which reads the finished job's files). `prove` / `verify` are `start` + wait + `collect` for
scripts and tests.

Implementations:
  StubProver        today's next-token CLI (TinyLlama-1.1B, 32 tokens) on TEXT posts. It proves
                    that the approved public model ran on the hidden post; it does NOT prove a
                    classifier verdict (the verdict comes from an unproved placeholder and is
                    labelled so everywhere). Images: "proof path in development".
  ShieldstralProver placeholder for the classifier prover the other lanes are building (D38).
  FakeProver        tests / UI development only: no proof at all, shown in red in the UI.
"""
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import time
from abc import ABC, abstractmethod
from pathlib import Path

from . import config, prompting, records
from .items import CANVAS_PX, IMAGE_SPEC_ID, ImageItem, TextItem
from .records import ProofRecord, Verdict

PIPELINE = config.TOOLS_DIR / "stub_pipeline.sh"
SEQGEN = config.TOOLS_DIR / "seqgen.py"

STEP_LABELS = {
    "queued": "Waiting in the app's queue",
    "seqgen": "Preparing the hidden input (integer model activations, private)",
    "prove": "Proving: running the model on the hidden post and sealing every step",
    "verify": "Verifying the proof from the public files only (fresh process)",
    "owner": "Platform opens the sealed output (kept private)",
    "inowner": "Checking the proof's hidden input is this post",
    "held": "Paused by the project coordinator (HOLD file)",
    "done": "Finished",
}


class ProverError(Exception):
    """a refused or failed proof; `user_message` is safe to show (no hidden value)"""

    def __init__(self, user_message: str, code: int | None = None, detail: str = ""):
        super().__init__(user_message)
        self.user_message = user_message
        self.code = code
        self.detail = detail


class NotSupported(ProverError):
    pass


# ---------------------------------------------------------------- helpers

def _mkdir_private(p: Path) -> None:
    p.mkdir(mode=0o700, parents=False, exist_ok=False)
    os.chmod(p, 0o700)


def ensure_private_roots() -> None:
    for p in (config.PRIVATE_DIR, config.JOBS_DIR, config.MEDIA_DIR):
        p.mkdir(mode=0o700, parents=True, exist_ok=True)
        os.chmod(p, 0o700)
    config.RUNS_DIR.mkdir(parents=True, exist_ok=True)


def write_private(path: Path, data: bytes) -> None:
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "wb") as f:
        f.write(data)


def events(log: Path) -> list[dict]:
    out = []
    try:
        for line in log.read_text(errors="replace").splitlines():
            if line.startswith("{"):
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    except FileNotFoundError:
        pass
    return out


def last_event(log: Path, name: str) -> dict:
    ev = [e for e in events(log) if e.get("event") == name]
    return ev[-1] if ev else {}


def guard_json(job: Path, step: str) -> dict:
    try:
        return json.loads((job / "logs" / f"{step}.guard.json").read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def pins() -> dict:
    r = json.loads(config.STUB_APPROVAL.read_text())
    if r["export"] != str(config.STUB_EXPORT):
        raise ProverError("the approval record is for another export", detail=r["export"])
    return {"expect_statement": r["pins"]["expect_statement"], "expect_token_profile": r["pins"]["expect_token_profile"],
            "approval_record": str(config.STUB_APPROVAL), "approved_by": r.get("approved_by", "")}


def ensure_verifier_copy() -> Path:
    """the verifier's copy of the export: the PUBLIC files only (no seq_*), as hard links"""
    dst = config.STUB_VERIFIER_EXPORT
    if dst.is_dir():
        return dst
    tmp = dst.with_name(dst.name + f".tmp-{os.getpid()}")
    tmp.mkdir(parents=True)
    for e in sorted(config.STUB_EXPORT.iterdir()):
        if e.name.startswith("seq_"):
            continue
        if e.is_dir():
            shutil.copytree(e, tmp / e.name, copy_function=os.link)
        else:
            os.link(e, tmp / e.name)
    os.rename(tmp, dst)
    return dst


def proc_alive(pid: int) -> bool:
    try:
        cmd = Path(f"/proc/{pid}/cmdline").read_bytes()
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return False
    return b"stub_pipeline.sh" in cmd


def boot_id() -> str:
    try:
        return Path("/proc/sys/kernel/random/boot_id").read_text().strip()
    except OSError:
        return ""


def poll(job: Path) -> dict:
    """status of a launched job from its files alone (works across web-server restarts)"""
    st = {"done": False, "exit": None, "step": "queued", "step_since": None, "waiting_for_machine": False,
          "guard_line": "", "alive": None}
    d = job / "pipeline.done"
    if d.exists():
        try:
            st["exit"] = int(d.read_text().strip() or "1")
        except ValueError:
            st["exit"] = 1
        st["done"] = True
        st["step"] = "done"
        return st
    try:
        name, since = (job / "step.current").read_text().split()[:2]
        st["step"], st["step_since"] = name, float(since)
    except (FileNotFoundError, ValueError):
        pass
    go = job / "logs" / f"{st['step']}.guard.out"
    try:
        lines = go.read_text(errors="replace").strip().splitlines()
        if lines:
            st["guard_line"] = lines[-1][-300:]
            st["waiting_for_machine"] = "waiting" in lines[-1] and "START" not in lines[-1]
    except FileNotFoundError:
        pass
    try:
        pid = int((job / "pipeline.pid").read_text().strip())
        same_boot = (job / "pipeline.boot_id").read_text().strip() == boot_id()
        st["alive"] = same_boot and proc_alive(pid)
    except (FileNotFoundError, ValueError):
        st["alive"] = None      # not started yet (launch in progress)
    return st


def launch_detached(job: Path) -> None:
    """setsid -f: the pipeline is re-parented to init at once, survives the web server, no zombie"""
    fd = os.open(job / "pipeline.out", os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
    with os.fdopen(fd, "ab") as out:
        p = subprocess.Popen(["setsid", "-f", "nohup", "bash", str(PIPELINE), str(job)],
                             stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT, close_fds=True)
        p.wait(timeout=30)


def _refusal_text(log: Path) -> str:
    ev = last_event(log, "refused")
    return (ev.get("reason") or ev.get("error") or ev.get("message") or "")[:400]


# ---------------------------------------------------------------- interface

class ClassifierProver(ABC):
    kind = "abstract"
    label = ""
    supports: frozenset = frozenset()
    proves_verdict = False          # True only when the verdict is the proof's public output

    def can_prove(self, item) -> bool:
        return item.kind in self.supports

    def describe(self) -> dict:
        return {"kind": self.kind, "label": self.label, "supports": sorted(self.supports),
                "proves_verdict": self.proves_verdict}

    @abstractmethod
    def start(self, post_id: str, item, job: Path, chunk: dict | None = None) -> None:
        """launch the detached proof job for one CHUNK of `item` ({index, start, end} in content tokens;
        None = the whole item) in the new private directory `job`"""

    @abstractmethod
    def collect(self, post_id: str, item, job: Path, chunk: dict | None = None) -> ProofRecord:
        """read a finished chunk job; raises ProverError on a refused / failed job"""

    @abstractmethod
    def start_recheck(self, record: ProofRecord, prove_job: Path, job: Path) -> None:
        """launch a fresh-process re-verification of a stored record"""

    @abstractmethod
    def collect_recheck(self, record: ProofRecord, job: Path) -> Verdict:
        ...

    def poll(self, job: Path) -> dict:
        return poll(job)

    # blocking conveniences (scripts, tests): the interface the design names
    def prove(self, item, post_id: str | None = None, job: Path | None = None, timeout_s: float = 7200) -> ProofRecord:
        post_id = post_id or f"cli-{int(time.time())}"
        job = job or (config.JOBS_DIR / post_id / "prove")
        self.start(post_id, item, job)
        self._wait(job, timeout_s)
        return self.collect(post_id, item, job)          # one chunk; the app plans and proves every chunk

    def verify(self, record: ProofRecord, prove_job: Path | None = None, job: Path | None = None,
               timeout_s: float = 3600) -> Verdict:
        prove_job = prove_job or (config.JOBS_DIR / record.post_id / "prove")
        job = job or (config.JOBS_DIR / record.post_id / f"check-{int(time.time())}")
        self.start_recheck(record, prove_job, job)
        self._wait(job, timeout_s)
        return self.collect_recheck(record, job)

    def _wait(self, job: Path, timeout_s: float) -> None:
        t0 = time.time()
        while not (job / "pipeline.done").exists():
            if time.time() - t0 > timeout_s:
                raise ProverError("timed out waiting for the proof job", detail=str(job))
            time.sleep(2)


# ---------------------------------------------------------------- the stub

class StubProver(ClassifierProver):
    kind = "stub-next-token"
    label = "demo stub: next-token proof, classifier proof coming"
    supports = frozenset({"text"})
    proves_verdict = False

    def describe(self) -> dict:
        d = super().describe()
        d.update({"model": config.STUB_MODEL_NAME, "T": config.STUB_T,
                  "max_content_tokens": config.STUB_MAX_CONTENT_TOKENS,
                  "binary_sha256": config.STUB_BIN_SHA256,
                  "what_is_proved": ("that the approved public TinyLlama-1.1B integer model ran on the hidden post (at most 31 "
                                     "tokens, padded to the public length 32) and sealed its next token; every layer is proved, "
                                     "the verifier never sees the post. It does NOT prove any category label; one stub run "
                                     "stands in for the three category proofs."),
                  "verdict_source": records.PLACEHOLDER_SOURCE})
        return d

    def _env(self, job: Path, mode: str, run: Path, prove_job: Path, job_id: str) -> str:
        p = pins()
        kv = {
            "MODE": mode, "JOB_ID": job_id, "GUARD": config.GUARD, "HOLD_FILE": config.HOLD_FILE,
            "WAIT_SECS": config.GUARD_WAIT_SECS, "BIN": config.STUB_BIN, "BIN_SHA": config.STUB_BIN_SHA256,
            "EXPORT": config.STUB_EXPORT, "VEXPORT": ensure_verifier_copy(), "HEAD": config.STUB_HEAD,
            "PIN_STATEMENT": p["expect_statement"], "PIN_TOKEN_PROFILE": p["expect_token_profile"],
            "RUN": run, "PROMPT": prove_job / "prompt", "SEQ": prove_job / "seq", "OWNER": prove_job / "owner",
            "SYSPY": config.SYSTEM_PYTHON, "SEQGEN": SEQGEN,
        }
        for step, d in config.GUARD_DECL.items():
            kv[f"DECL_{step}"] = f"{d['cls']} {d['need']} {d['cap']} {d['max']}"
        lines = []
        for k, v in kv.items():
            s = str(v)
            if "'" in s or "\n" in s:
                raise ProverError("unsafe character in a job setting", detail=k)
            lines.append(f"{k}='{s}'")
        return "\n".join(lines) + "\n"

    def run_dir(self, post_id: str, chunk: dict | None = None) -> Path:
        i = (chunk or {}).get("index", 0)
        return config.RUNS_DIR / (f"run-{post_id}" if i == 0 else f"run-{post_id}-c{i}")

    def start(self, post_id: str, item, job: Path, chunk: dict | None = None) -> None:
        if not isinstance(item, TextItem):
            raise NotSupported(f"{item.kind} posts: proof path in development (the stub proves text only)")
        c = chunk or {}
        enc = prompting.build_prompt(self.kind, item.text, start=c.get("start"), end=c.get("end"))  # the ONE encoding function
        ensure_private_roots()
        job.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        _mkdir_private(job)
        write_private(job / "prompt", (",".join(str(i) for i in enc.ids) + "\n").encode())
        del enc
        write_private(job / "job.env", self._env(job, "prove", self.run_dir(post_id, chunk), job,
                                                 f"{post_id[:12]}-c{c.get('index', 0)}").encode())
        launch_detached(job)

    def start_recheck(self, record: ProofRecord, prove_job: Path, job: Path) -> None:
        run = Path(record.receipt["run_dir"])
        ensure_private_roots()
        _mkdir_private(job)
        write_private(job / "job.env", self._env(job, "recheck", run, prove_job, record.post_id[:12]).encode())
        launch_detached(job)

    def _fail(self, job: Path, code: int) -> ProverError:
        L = job / "logs"
        if code == 10:
            return ProverError("Could not be verified: the prover binary is not the pinned build.", code,
                               (L / "fatal.txt").read_text() if (L / "fatal.txt").exists() else "")
        step = {11: "seqgen", 12: "prove", 13: "verify", 14: "owner", 15: "inowner"}.get(code, "")
        gj = guard_json(job, step) if step else {}
        if gj.get("exit") == 70 or gj.get("refused"):
            return ProverError("Could not be verified: the shared machine stayed busy (the resource guard did not admit "
                               "the job in time).", code, str(gj.get("refused")))
        reason = _refusal_text(L / f"{step}.log") if step else ""
        msg = {
            11: "Could not be verified: the demo stub's integer model cannot represent this text (an integer range "
                "would overflow).",
            12: "Could not be verified: the prover refused this chunk.",
            13: "Could not be verified: the verifier rejected the proof.",
            14: "Could not be verified: the platform could not open the proof's sealed output.",
            15: "Could not be verified: the proof's hidden input did not match this chunk.",
        }.get(code, f"Could not be verified: the proof job failed (code {code}).")
        return ProverError(msg, code, reason)

    def collect(self, post_id: str, item, job: Path, chunk: dict | None = None) -> ProofRecord:
        st = poll(job)
        if not st["done"]:
            raise ProverError("the job has not finished", detail=str(job))
        if st["exit"] != 0:
            raise self._fail(job, st["exit"])
        L = job / "logs"
        seq_ev = last_event(L / "seqgen.log", "seq-built")
        proved = last_event(L / "prove.log", "proved")
        verified = last_event(L / "verify.log", "verified")
        opened = last_event(L / "owner.log", "next-token")
        bound = last_event(L / "inowner.log", "input-checked")
        run = Path(proved["run"])
        stmt_path = run / "statement" / "statement.json"
        segs_path = run / "statement" / "segments.json"
        stmt_raw = stmt_path.read_bytes()
        statement = json.loads(stmt_raw)
        segs = json.loads(segs_path.read_text())
        p = pins()
        if statement.get("trained_statement_identity") != p["expect_statement"] or \
                statement.get("token_profile_digest") != p["expect_token_profile"]:
            raise ProverError("the published statement does not carry the approved model pins", 99)
        waits = {s: guard_json(job, s).get("waited_s") or 0 for s in config.GUARD_DECL}
        walls = {s: guard_json(job, s).get("guard_wall_s") for s in config.GUARD_DECL}
        from . import tokenizer
        ids = tokenizer.content_ids(item.text)
        c = chunk or {"index": 0, "start": 0, "end": len(ids)}
        chunk_text = tokenizer.decode(ids[c["start"]:c["end"]])
        values = records.placeholder_labels(chunk_text)        # the chunk's OWN text (stub placeholder)
        n = c["end"] - c["start"]
        cats = records.categories()
        run_ref = {"statement_sha256": hashlib.sha256(stmt_raw).hexdigest(), "run_dir": str(run)}
        work = sum(v for v in walls.values() if v)
        return ProofRecord(
            post_id=post_id, item_kind="text",
            prover={**self.describe(), "cli": "zk60_token_io, frozen round-11 CPU build",
                    "model_digest": statement["trained_statement_identity"],
                    "token_profile_digest": statement["token_profile_digest"],
                    "run_profile": statement.get("run_profile"), "export_variant": statement.get("export_variant"),
                    "approval_record": p["approval_record"], "backend": proved.get("backend")},
            labels={c["id"]: {"value": values[c["id"]], "proof": "accepted", "bound_by_proof": False,
                              "source": records.PLACEHOLDER_SOURCE, "policy_id": c["policy"]["id"],
                              "policy_sha256": c["policy"]["sha256"], "proof_ref": run_ref,
                              "stub_note": f"stub: ONE next-token run stands in for all {len(cats)} category proofs"}
                    for c in cats},
            policies=[{**c["policy"], "category": c["id"], "name": c["name"]} for c in cats],
            threshold=records.threshold(),
            content_commitment={"kind": "hidden-input endpoint root (hiding commitment to the post's tokens)",
                                "value": statement.get("input_token_endpoint_root"),
                                "sealed_output_root": statement.get("output_token_endpoint_root"),
                                "covers": "the whole post (at most 31 tokens), BOS first, padded with newlines to the public length T = 32"},
            chunk={"index": c["index"], "start": c["start"], "end": c["end"]},
            content_length={"tokens": n, "tokenizer": "TinyLlama-1.1B SentencePiece (the stub's encoding)",
                            "status": "public by the classifier design's rule (C-5 / B-5), pending Victor's confirmation; "
                                      "in the stub it is reported by the platform, not bound by the proof"},
            statement=statement, statement_sha256=hashlib.sha256(stmt_raw).hexdigest(),
            receipt={"segments": len(segs), "bytes": sum(int(s["bytes"]) for s in segs),
                     "segments_json_sha256": records.sha256_file(segs_path), "run_dir": str(run),
                     "files": segs},
            timings={"seqgen_s": seq_ev.get("seconds"), "prove_s": proved.get("prove_seconds"),
                     "prove_with_loading_s": proved.get("total_seconds"), "verify_s": verified.get("verify_seconds"),
                     "verify_with_loading_s": verified.get("total_seconds"), "owner_s": opened.get("total_seconds"),
                     "step_wall_s": walls, "waited_for_machine_s": waits, "work_s": round(work, 1),
                     "peak_rss_gib": {s: guard_json(job, s).get("peak_rss_gib") for s in config.GUARD_DECL}},
            security={"whole_run_floor_bits": verified.get("whole_run_floor_bits"),
                      "min_bits_required": verified.get("min_bits"),
                      "note": "MVP soundness level per D27 (about 2^-95 per run); next milestone 100 bits, product target 128"},
            checks={"verify": {"ok": True, "by": "zk60_token_io verify (fresh process, public files only)",
                               "at": records.now_iso()},
                    "output_opened_by_platform": bool(opened),
                    "content_binding": {"ok": bool(bound),
                                        "by": "zk60_token_io input-owner with the platform's private opening (D21: openings stay private)"}},
            proved_at=guard_json(job, "prove").get("ts_end") or records.now_iso(),
            created_at=records.now_iso(),
            notes=["DEMO STUB: this is a next-token proof of TinyLlama-1.1B, not a Shieldstral classifier proof.",
                   "One stub run stands in for the three category proofs; each label comes from an unproved "
                   "placeholder until the classifier prover lands (then: one proof per category, label bound).",
                   "No privacy acceptance covers this artifact (D33 covers a different calibration and not the next-token stages)."],
        )

    def collect_recheck(self, record: ProofRecord, job: Path) -> Verdict:
        st = poll(job)
        if not st["done"]:
            raise ProverError("the check has not finished", detail=str(job))
        if st["exit"] != 0:
            e = self._fail(job, st["exit"])
            # fail closed: did the VERIFIER reject (the proof is bad), or did the check merely not run
            # (machine busy)? A rejection withdraws the post; a check that did not run changes nothing.
            gj = guard_json(job, "verify")
            rejected = st["exit"] == 13 and gj.get("exit") != 70 and not gj.get("refused") and \
                bool(last_event(job / "logs" / "verify.log", "refused"))
            return Verdict(value="re-check", proof_valid=False, bound_by_proof=False,
                           source="re-check failed", checked_at=records.now_iso(),
                           details={"message": e.user_message.replace("Its labels are unproved (fail closed).", "").strip(), "detail": e.detail,
                                    "code": e.code, "rejected": rejected})
        L = job / "logs"
        # a re-verification over an already published statement reports "statement-checked" (it re-checks
        # the published statement byte for byte); a first verification reports "verified"
        v = last_event(L / "verify.log", "statement-checked") or last_event(L / "verify.log", "verified")
        b = last_event(L / "inowner.log", "input-checked")
        return Verdict(value="re-check", proof_valid=True, bound_by_proof=False,
                       source="fresh-process re-verification of the stored run", checked_at=records.now_iso(),
                       details={"verify_seconds": v.get("verify_seconds"), "total_seconds": v.get("total_seconds"),
                                "whole_run_floor_bits": v.get("whole_run_floor_bits") or (record.security or {}).get("whole_run_floor_bits"),
                                "min_bits": v.get("min_bits"), "event": v.get("event"),
                                "statement_rechecked": "byte for byte against the published statement",
                                "content_binding": bool(b),
                                "waited_for_machine_s": {s: guard_json(job, s).get("waited_s") for s in ("verify", "inowner")}})


# ---------------------------------------------------------------- the classifier (placeholder)

class ShieldstralProver(ClassifierProver):
    """Placeholder for the classifier prover (D38). Expected shape, once the other lanes land it:

        zk60_classifier prove  --model-export DIR --policy FILE --content-file FILE(0600) --out DIR --owner-dir DIR
        zk60_classifier verify --model-export DIR --artifact DIR --expect-statement HEX --expect-policy HEX

    with the statement carrying the verdict bit (z_yes - z_no > c at the public threshold), the model
    identity, the policy digest and the hidden-content commitment. Images: one proof per image over
    its canonical 224-px canvas through the Pixtral encoder, bound through the run's hidden input
    endpoint (results/zk60_multimodal_design_20261021/ §2-§3). Video and audio: deferred.
    """
    kind = "shieldstral"
    label = "Shieldstral-1.0-3B classifier proof (not landed yet)"
    supports = frozenset()
    proves_verdict = True

    def _nope(self):
        raise NotSupported("the Shieldstral classifier prover has not landed yet; the app runs the demo stub")

    def start(self, post_id, item, job, chunk=None):
        self._nope()

    def collect(self, post_id, item, job, chunk=None):
        self._nope()

    def start_recheck(self, record, prove_job, job):
        self._nope()

    def collect_recheck(self, record, job):
        self._nope()


# ---------------------------------------------------------------- fake (tests / UI only)

class FakeProver(ClassifierProver):
    """NO PROOF. For unit tests and UI work; every record says FAKE and the UI shows it in red."""
    kind = "fake"
    label = "FAKE PROVER: no proof (development only)"
    supports = frozenset({"text"})

    def _finish(self, job: Path, code: int = 0) -> None:
        (job / "logs").mkdir(exist_ok=True)
        (job / "logs" / "prove.log").write_text('{"event":"fake","note":"FAKE prover: nothing proved"}\n')
        (job / "pipeline.done").write_text(f"{code}\n")

    # test hooks: content containing REFUSE_MARK finishes like a prover refusal (exit 12);
    # reject_rechecks makes the next re-check behave like a verifier rejection
    REFUSE_MARK = "[[fake-refuse]]"
    reject_rechecks = False

    def start(self, post_id, item, job, chunk=None):
        if not isinstance(item, TextItem):
            raise NotSupported(f"{item.kind} posts: proof path in development")
        c = chunk or {}
        prompting.build_prompt("stub-next-token", item.text, start=c.get("start"), end=c.get("end"))  # same limits
        job.parent.mkdir(parents=True, exist_ok=True)
        _mkdir_private(job)
        self._finish(job, 12 if self.REFUSE_MARK in self._chunk_text(item, c) else 0)

    @staticmethod
    def _chunk_text(item, c: dict) -> str:
        from . import tokenizer
        ids = tokenizer.content_ids(item.text)
        return tokenizer.decode(ids[c.get("start", 0):c.get("end", len(ids))])

    def collect(self, post_id, item, job, chunk=None):
        st = poll(job)
        if st["exit"] != 0:
            raise ProverError("Could not be verified: the prover refused this chunk.", st["exit"], "fake")
        ch = chunk or {"index": 0, "start": 0, "end": None}
        vals = records.placeholder_labels(self._chunk_text(item, ch))
        return ProofRecord(
            post_id=post_id, item_kind=item.kind, prover=self.describe(), chunk=ch,
            labels={c["id"]: {"value": vals[c["id"]], "proof": "accepted", "bound_by_proof": False,
                              "source": "FAKE: placeholder keywords, no proof", "policy_id": c["policy_id"],
                              "policy_sha256": c["sha256"], "proof_ref": None}
                    for c in config.CATEGORIES},
            policies=[{**c["policy"], "category": c["id"], "name": c["name"]} for c in records.categories()],
            threshold=records.threshold(),
            content_commitment={"kind": "none (fake)", "value": None}, statement=None, statement_sha256=None,
            receipt={"segments": 0, "bytes": 0, "run_dir": "", "files": []}, timings={}, security={},
            checks={"verify": {"ok": False, "by": "nothing: FAKE prover"}}, created_at=records.now_iso(),
            notes=["FAKE PROVER: nothing was proved."])

    def start_recheck(self, record, prove_job, job):
        job.parent.mkdir(parents=True, exist_ok=True)
        _mkdir_private(job)
        self._finish(job, 0)

    def collect_recheck(self, record, job):
        if self.reject_rechecks:
            return Verdict("re-check", False, False, "re-check failed", records.now_iso(),
                           {"message": "Could not be verified: the verifier rejected the proof.", "code": 13, "rejected": True})
        return Verdict("re-check", False, False, "FAKE: nothing verified", records.now_iso(),
                       {"rejected": False})


def make_prover(mode: str | None = None) -> ClassifierProver:
    mode = mode or config.prover_mode()
    if mode == "fake":
        return FakeProver()
    if mode == "shieldstral":
        return ShieldstralProver()
    return StubProver()


def media_status(item) -> dict:
    """what the app shows for an image the current provers cannot prove yet"""
    if isinstance(item, ImageItem):
        n = len(config.CATEGORIES)
        return {"status": "in-development", "proofs_needed": n, "canvas_px": CANVAS_PX, "spec": IMAGE_SPEC_ID,
                "message": f"Image proof path in development: {n} Shieldstral category proofs over the image's canonical "
                           f"{CANVAS_PX} x {CANVAS_PX} canvas (Pixtral encoder)."}
    return {"status": "n/a"}


def verify_instructions(record: dict) -> dict:
    """how anyone re-checks the proof from a downloaded bundle (public pins only)"""
    p = record.get("prover", {})
    if p.get("kind") != "stub-next-token":
        return {"note": "no CLI check for this prover kind"}
    return {
        "binary": "zk60_token_io (frozen round-11 CPU build), sha256 " + config.STUB_BIN_SHA256,
        "public_model_files": f"the export {config.STUB_EXPORT_NAME} without its seq_* directories "
                              "(+ the head tables of results/zk60_token_io_r1_20261017/r2_inputs)",
        "expect_statement": p.get("model_digest"),
        "expect_token_profile": p.get("token_profile_digest"),
        "command": ("zk60_token_io verify --export <public-model-dir> --emb <public-model-dir> --head <head-dir> "
                    f"--artifact <unpacked-bundle-dir>/run --expect-statement {p.get('model_digest')} "
                    f"--expect-token-profile {p.get('token_profile_digest')}"),
        "accept_if": "exit code 0 and a JSON line {\"event\":\"verified\", ...}; the statement in the bundle is then "
                     "re-checked byte for byte",
        "publication": "apps/proven-media/tools/verify_publication.py --post-id <id> [--run-verifier] checks the anchor, "
                       "the Merkle path, the manifest and every segment from the store, then (optionally) runs this verifier",
    }
