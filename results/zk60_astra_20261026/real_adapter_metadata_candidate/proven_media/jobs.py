"""The queue worker: ONE proof job at a time from this app, each a detached guarded pipeline.

D41: a post is split into chunks (deployment profile, deploy.json); each chunk is one job, proved
separately per category (the stub: one run per chunk stands in for that chunk's three category
proofs). When the last chunk of a post finishes, the post is FINALIZED: its labels are aggregated
(yes if any chunk is yes; not proved if any chunk lacks an accepted proof: fail closed), every
accepted (chunk, category) proof is published and anchored, and the signed manifest is issued.

The worker thread lives in the web server, but the jobs do not: a job is launched with
`setsid -f nohup` and reports through files (`step.current`, `pipeline.done`), so a server restart
re-attaches to a running job by reading its directory. It never relaunches a job because a poll
looked old; a job whose pipeline process is gone (same boot, no done marker) or that predates a
reboot counts as a chunk without an accepted proof.
"""
from __future__ import annotations

import json
import hashlib
import logging
import subprocess
import threading
import time
import traceback
from dataclasses import dataclass
from pathlib import Path

from . import config, manifest, prompting, proof_plans, records
from .items import TextItem
from .provers import STEP_LABELS, ClassifierProver, NotSupported, ProverError
from .publisher import Publisher, PublicationRecord, PublishError, content_commitment
from .records import ProofRecord
from .store import Store, loads

log = logging.getLogger("proven_media.jobs")
# Includes preparation, proving and the three native checks; shared-machine wait is extra.
PER_JOB_S = 700.0 if config.prover_mode() == 'shieldstral' else 150.0


def prove_job_dir(post_id: str, chunk: int = 0) -> Path:
    return config.JOBS_DIR / post_id / ("prove" if not chunk else f"prove-c{chunk}")


def chunks_of(post: dict) -> list[dict]:
    """the post's chunk plan (stored at creation; an older post is one chunk)"""
    plan = loads(post.get("chunks"))
    if plan:
        return plan
    from . import tokenizer
    n = len(tokenizer.content_ids(post["text"])) if post.get("text") else 0
    return [{"index": 0, "start": 0, "end": n}]


def prove_attempted(j: dict) -> bool:
    """did any step actually execute on this chunk (beyond waiting for guard admission)? Each item is
    proved once (D37): an item is re-submittable only if nothing ran on it (the machine stayed busy)."""
    d = Path(j["job_dir"]) / "logs" if j.get("job_dir") else None
    if d is None or not d.is_dir():
        return False
    for step in ("seqgen", "prove", "verify", "owner", "inowner"):
        log_ = d / f"{step}.log"
        if log_.exists() and log_.stat().st_size > 0:
            return True
    return False


@dataclass
class PubInfo:
    """what a manifest entry repeats from a published proof"""
    model_id: str
    profile_id: str
    statement_sha256: str


def item_commitment(post: dict) -> str | None:
    salt = records.salt_of(post["id"], post["salt_enc"])
    if salt is None or post.get("text") is None:
        return None
    return content_commitment(salt, post["text"].encode())


def chunk_publication_records(post: dict, rec: dict, chunk: dict, commitment: str) -> list[PublicationRecord]:
    """the report's PublicationRecord, ONE PER CATEGORY with an accepted proof in this chunk; each label
    is published whether it is yes or no"""
    if rec.get("prover", {}).get("development_only"):
        return []
    run = rec["receipt"].get("run_dir")
    zero = "00" * 32
    if run:
        run = Path(run)
        statement = (run / "statement" / "statement.json").read_bytes()
        if hashlib.sha256(statement).hexdigest() != rec.get("statement_sha256"):
            raise PublishError("statement changed after verification")
        inventory = rec["receipt"]["files"]
        segs = []
        for row in inventory:
            name = row["file"]
            if not isinstance(name, str) or Path(name).name != name or name in (".", ".."):
                raise PublishError("invalid verified receipt filename")
            path = run / name
            if path.is_symlink() or path.stat().st_size != row["bytes"] or records.sha256_file(path) != row["sha256"]:
                raise PublishError("receipt changed after verification")
            segs.append(str(path))
        native_inventory = run / "statement" / "segments.json"
        if native_inventory.exists():
            segjson = native_inventory.read_bytes()
            if hashlib.sha256(segjson).hexdigest() != rec["receipt"].get("segments_json_sha256"):
                raise PublishError("native segment manifest changed after verification")
        else:
            if rec["receipt"].get("segments_json_sha256"):
                raise PublishError("verified native segment manifest disappeared")
            segjson = None  # R-C1 has no native segments.json; never invent one.
    else:                      # the FakeProver: no receipt (never shown as proved)
        statement, segjson, segs = records.canonical({"fake": True, "post_id": post["id"], "chunk": chunk["index"]}), None, []
        inventory = None
    pr = rec.get("prover", {})
    out = []
    for cat, lab in rec["labels"].items():
        if cat not in proof_plans.categories_for(chunk):
            raise PublishError('the proof contains a label outside its planned category')
        if lab.get("proof") != "accepted" or lab.get("value") not in ("yes", "no"):
            continue
        out.append(PublicationRecord(
            post_id=post["id"], category=cat, statement=statement, receipt_segments=segs, verdict=lab["value"],
            model_id=pr.get("model_digest") or zero, policy_id=lab["policy_sha256"],
            profile_id=pr.get("token_profile_digest") or zero,
            verifier_id=config.STUB_BIN_SHA256 if pr.get("kind") == "stub-next-token" else pr.get('binary_sha256', zero),
            content_commitment=commitment, segments_json=segjson,
            receipt_inventory=inventory,
            proof_verified=rec.get("checks", {}).get("verify", {}).get("ok") is True,
            verdict_bound=lab.get("bound_by_proof") is True,
            development_only=lab.get("development_only", False),
            chunk=chunk["index"], token_range=(chunk["start"], chunk["end"])))
    return out


class Worker(threading.Thread):
    def __init__(self, store: Store, prover: ClassifierProver, publisher: Publisher, interval: float = 2.0):
        super().__init__(name="proof-queue", daemon=True)
        self.store, self.prover, self.publisher = store, prover, publisher
        self.interval = interval
        self.stop_evt = threading.Event()

    def run(self) -> None:
        while not self.stop_evt.is_set():
            try:
                self.tick()
            except Exception:
                log.error("worker tick failed:\n%s", traceback.format_exc())
            self.stop_evt.wait(self.interval)

    def stop(self) -> None:
        self.stop_evt.set()

    # ------------------------------------------------------------ one step of the queue
    def tick(self) -> None:
        try:
            self.publisher.tick()          # close an anchor batch when due (10 min or 1,000 leaves)
        except Exception:
            log.error("batcher failed:\n%s", traceback.format_exc())
        running = self.store.q("SELECT * FROM jobs WHERE status='running' ORDER BY id")
        for j in running:
            st = self.prover.poll(Path(j["job_dir"]))
            if st["done"]:
                self.finish(j)
            elif st["alive"] is False:
                self.fail(j, "The proof job stopped without finishing (machine restart or the job was ended).",
                          "pipeline gone, no done marker")
            else:
                return          # one at a time: wait for it
        if self.store.q("SELECT id FROM jobs WHERE status='running'"):
            return
        if config.HOLD_FILE.exists():      # the coordinator paused this lane: launch nothing new
            return
        nxt = self.store.one("SELECT * FROM jobs WHERE status='queued' ORDER BY id LIMIT 1")
        if nxt:
            self.start_job(nxt)

    def start_job(self, j: dict) -> None:
        post = self.store.post(j["post_id"])
        ci = int(j.get("chunk") or 0)
        try:
            plan = chunks_of(post)
            if self.prover.separate_categories or proof_plans.is_category_plan(plan):
                proof_plans.check_plan(plan, self.prover.plan_text(post['text']))
            if not post.get("chunks"):
                self.store.update_post(post["id"], chunks=json.dumps(plan))
            chunk = plan[ci]
            if j["kind"] == "prove":
                self.store.check_screening(post)
                d = prove_job_dir(post["id"], ci)
                self.store.update_job(j["id"], status="running", started_at=records.now_iso(), job_dir=str(d))
                self.store.update_post(post["id"], status="screening", status_message="")
                self.prover.start(post["id"], TextItem(post["text"]), d, chunk)
            else:
                d = config.JOBS_DIR / post["id"] / f"check-{j['id']}"
                self.store.update_job(j["id"], status="running", started_at=records.now_iso(), job_dir=str(d))
                row = self.store.one("SELECT * FROM chunk_proofs WHERE post_id=? AND chunk=?", (post["id"], ci))
                rec = ProofRecord.from_dict(loads(row["record"]))
                self.prover.start_recheck(rec, prove_job_dir(post["id"], ci), d)
        except (ValueError, NotSupported, ProverError) as e:
            self.fail(j, getattr(e, "user_message", str(e)), repr(e))
        except Exception as e:  # launching failed: never leave a phantom "running" job
            self.fail(j, "The proof job could not be started.", repr(e))

    def fail(self, j: dict, user_message: str, detail: str) -> None:
        self.store.update_job(j["id"], status="failed", finished_at=records.now_iso(), error=f"{user_message} | {detail}")
        ci = int(j.get("chunk") or 0)
        if j["kind"] == "prove":
            self._set_chunk(j["post_id"], ci, "failed", None, user_message, prove_attempted(j))
            self._maybe_finalize(j["post_id"])
        else:
            self.store.x("INSERT INTO checks(post_id,job_id,at,ok,verdict) VALUES(?,?,?,?,?)",
                         (j["post_id"], j["id"], records.now_iso(), 0,
                          json.dumps({"proof_valid": False, "chunk": ci, "details": {"message": user_message, "detail": detail}})))

    def _set_chunk(self, pid: str, ci: int, status: str, rec: dict | None, error: str | None, attempted: bool) -> None:
        self.store.x("DELETE FROM chunk_proofs WHERE post_id=? AND chunk=?", (pid, ci))
        self.store.x("INSERT INTO chunk_proofs(post_id,chunk,status,record,error,attempted,finished_at) VALUES(?,?,?,?,?,?,?)",
                     (pid, ci, status, json.dumps(rec) if rec else None, error, int(attempted), records.now_iso()))

    def finish(self, j: dict) -> None:
        post = self.store.post(j["post_id"])
        d = Path(j["job_dir"])
        ci = int(j.get("chunk") or 0)
        try:
            plan = chunks_of(post)
            if self.prover.separate_categories or proof_plans.is_category_plan(plan):
                proof_plans.check_plan(plan, self.prover.plan_text(post['text']))
            chunk = plan[ci]
        except (ValueError, ProverError, IndexError) as exc:
            self.fail(j, 'Could not be verified: the stored proof plan changed.', str(exc))
            return
        if j["kind"] == "prove":
            try:
                self.store.check_screening(post)
                rec = self.prover.collect(post["id"], TextItem(post["text"]), d, chunk)
                proof_plans.check_category_record(rec.to_dict(), post['id'], chunk,
                                                  require_verdict=self.prover.proves_verdict)
            except (ProverError, ValueError) as e:
                self.fail(j, getattr(e, 'user_message', str(e)), str(e))
                return
            rd = rec.to_dict()
            self._set_chunk(post["id"], ci, "done", rd, None, True)
            self.store.update_job(j["id"], status="done", finished_at=records.now_iso(),
                                  result=json.dumps({"chunk": ci, "labels": records.effective_labels(rd)}))
            self._maybe_finalize(post["id"])
        else:
            row = self.store.one("SELECT * FROM chunk_proofs WHERE post_id=? AND chunk=?", (post["id"], ci))
            rec = ProofRecord.from_dict(loads(row["record"]))
            verdict = self.prover.collect_recheck(rec, d)
            vd = verdict.to_dict()
            vd["chunk"] = ci
            self.store.x("INSERT INTO checks(post_id,job_id,at,ok,verdict) VALUES(?,?,?,?,?)",
                         (post["id"], j["id"], records.now_iso(), int(verdict.proof_valid), json.dumps(vd)))
            if verdict.details.get("rejected"):
                # fail closed: a proof the verifier now rejects no longer backs this chunk's labels; the
                # item's labels are re-aggregated and the manifest re-issued (nothing is re-proved)
                self._set_chunk(post["id"], ci, "failed", None,
                                "A re-verification rejected this chunk's proof.", True)
                self.finalize(post["id"], note="A re-verification rejected a chunk's proof; its labels now count as not proved.")
            self.store.update_job(j["id"], status="done" if verdict.proof_valid else "failed",
                                  finished_at=records.now_iso(), result=json.dumps(vd))

    # ------------------------------------------------------------ one-off: pre-chunk records
    def migrate_legacy(self) -> list[str]:
        """a post finalized before D41 holds one ProofRecord instead of an item record: file it as its
        chunk 0 and finalize again (re-publishes under the chunked layout; nothing is re-proved)"""
        done = []
        for p in self.store.q("SELECT * FROM posts WHERE status='published' AND record IS NOT NULL"):
            rec = loads(p["record"])
            if rec.get("schema") == "proven-media-item/1" or "receipt" not in rec:
                continue
            if not p.get("chunks"):
                self.store.update_post(p["id"], chunks=json.dumps(chunks_of(p)))
            self._set_chunk(p["id"], 0, "done", rec, None, True)
            self.finalize(p["id"])
            done.append(p["id"])
        return done

    # ------------------------------------------------------------ finalize: labels, publication, manifest
    def _maybe_finalize(self, pid: str) -> None:
        if self.store.one("SELECT id FROM jobs WHERE post_id=? AND kind='prove' AND status IN ('queued','running')", (pid,)):
            return
        self.finalize(pid)

    def finalize(self, pid: str, note: str | None = None) -> None:
        post = self.store.post(pid)
        plan = chunks_of(post)
        rows = {r["chunk"]: r for r in self.store.q("SELECT * FROM chunk_proofs WHERE post_id=?", (pid,))}
        chunk_recs, chunk_items, errors = [], [], []
        plan_error = None
        if self.prover.separate_categories or proof_plans.is_category_plan(plan):
            try:
                proof_plans.check_plan(plan, self.prover.plan_text(post['text']))
            except (ValueError, ProverError) as exc:
                plan_error = str(exc)
        for ch in plan:
            r = rows.get(ch["index"])
            rec = loads(r["record"]) if r and r["status"] == "done" else None
            err = None if rec else ((r or {}).get("error") or "no accepted proof")
            try:
                if plan_error:
                    raise prompting.ContentRefused(plan_error)
                if rec:
                    proof_plans.check_category_record(rec, pid, ch, require_verdict=self.prover.proves_verdict)
            except (ValueError, ProverError) as exc:
                rec, err = None, str(exc)
            chunk_recs.append(rec)
            if err:
                errors.append(f"chunk {ch['index'] + 1}: {err}")
            chunk_items.append({**ch, "record": rec, "error": err})
        agg = records.aggregate_labels(chunk_recs, len(plan), plan)
        context_matches = post.get('screening_context') == records.screening_context()
        accepted = context_matches and all(agg[c]['proof'] == 'accepted' for c in records.category_ids())
        if self.prover.proves_verdict:
            accepted = accepted and all(agg[c]['bound_by_proof'] for c in records.category_ids())
        if accepted:
            try:
                self.prover.check_final_records(TextItem(post['text']), chunk_recs)
            except (ValueError, ProverError, KeyError) as exc:
                accepted = False
                errors.append(str(exc))
                agg = records.aggregate_labels([], len(plan), plan)
        if not context_matches:
            errors.append('policy or threshold differs from the original screening')
            agg = records.aggregate_labels([], len(plan), plan)
        commitment = item_commitment(post)
        anchors, pubs = {}, {}
        for ch, rec in zip(plan, chunk_recs):
            if not rec or not accepted:
                continue
            try:
                publications = chunk_publication_records(post, rec, ch, commitment)
            except Exception as exc:
                log.error("publication bundle refused for %s chunk%d: %r", pid, ch["index"], exc)
                continue
            for pub in publications:
                key = f"c{ch['index']}.{pub.category}"
                try:
                    a = self.publisher.anchor_of(pid, pub.category, ch["index"]) or self.publisher.publish(pub)
                    anchors[key] = a
                    man = self.publisher.resolve(a)["manifest"]
                    pubs[key] = PubInfo(man["model_id"], man["profile_id"], man["statement_sha256"])
                except Exception as e:     # the proofs stand; publication can be retried
                    log.error("publish failed for %s %s: %r", pid, key, e)
        first = next((r for r in chunk_recs if r), None)
        d = config.deploy()
        chunking = {"profile": d["profile"], "chunk_tokens": d["effective_chunk_tokens"],
                    "overlap_tokens": d["effective_overlap_tokens"], "configured_chunk_tokens": d["chunk_tokens"],
                    "n_chunks": len(plan)}
        if proof_plans.is_category_plan(plan):
            chunking = {'profile': 'per-category', 'n_chunks': len(plan), 'categories': {
                c: {'chunks': sum(ch.get('category') == c for ch in plan),
                    'chunk_tokens': next((ch['chunk_tokens'] for ch in plan if ch.get('category') == c), None),
                    'overlap_tokens': next((ch['overlap_tokens'] for ch in plan if ch.get('category') == c), None)}
                for c in records.category_ids()}}
        item = {"schema": "proven-media-item/1", "post_id": pid, "item_kind": post["kind"],
                "prover": (first or {}).get("prover", {"kind": self.prover.kind, "label": self.prover.label}),
                "labels": agg, "policies":
                [{**c["policy"], "category": c["id"], "name": c["name"]} for c in records.categories()],
                "threshold": records.threshold(),
                "chunking": chunking,
                "chunks": chunk_items,
                "content_length": plan[-1]["end"] if plan else 0,
                "proved_at": max((r.get("proved_at") or "" for r in chunk_recs if r), default=None),
                "receipt": {"segments": sum(r["receipt"]["segments"] for r in chunk_recs if r),
                            "bytes": sum(r["receipt"]["bytes"] for r in chunk_recs if r)},
                "timings": {"work_s": round(sum((r.get("timings") or {}).get("work_s") or 0 for r in chunk_recs if r), 1)},
                "created_at": records.now_iso()}
        failure = None
        if errors:
            failure = (f"{len(errors)} of {len(plan)} chunk{'s' if len(plan) > 1 else ''} without an accepted proof "
                       f"({'; '.join(errors)}). Their categories count as the most restrictive label (fail closed).")
        man = manifest.build_manifest(post, item, anchors, pubs, commitment, failure=note or failure)
        eff = {c: v["value"] for c, v in agg.items()}
        attempted = any(r["attempted"] for r in rows.values()) if rows else False
        self.store.update_post(pid, status="published" if accepted else "failed", record=json.dumps(item), labels=json.dumps(eff),
                               manifest=json.dumps(man), prover_kind=item["prover"].get("kind"),
                               published_at=(post.get("published_at") or records.now_iso()) if accepted else post.get('published_at'),
                               status_message=(note or failure or "") if accepted else
                                   'Could not be verified. ' + (note or failure or 'An accepted proof is required.'),
                               prove_attempted=int(attempted),
                               anchor_ref=",".join(a.leaf_hash[:12] for a in anchors.values())[:500])


# ---------------------------------------------------------------- queue status for the UI

_guard_cache = {"t": 0.0, "v": None}


def guard_status() -> dict:
    """the shared box's guard state (cached 15 s): memory budget and the heavy lock"""
    now = time.time()
    if _guard_cache["v"] is not None and now - _guard_cache["t"] < 15:
        return _guard_cache["v"]
    out = {"ok": False}
    try:
        r = subprocess.run(["python3", str(config.GUARD), "status"], capture_output=True, text=True, timeout=10)
        lines = r.stdout.splitlines()
        out = {"ok": r.returncode == 0,
               "ram": next((x[3:].strip() for x in lines if x.startswith("RAM")), ""),
               "budget": next((x[6:].strip() for x in lines if x.startswith("BUDGET")), ""),
               "locks": next((x[5:].strip() for x in lines if x.startswith("LOCKS")), ""),
               "jobs": sum(1 for x in lines if x.strip().startswith("job "))}
    except Exception as e:
        out = {"ok": False, "error": repr(e)}
    _guard_cache.update(t=now, v=out)
    return out


def item_progress(store: Store, pid: str) -> dict:
    """per item: chunks done / failed / running / queued, and an ETA for what is left"""
    jobs = store.q("SELECT status, chunk FROM jobs WHERE post_id=? AND kind='prove'", (pid,))
    n = {s: sum(1 for j in jobs if j["status"] == s) for s in ("done", "failed", "running", "queued")}
    total = len(jobs)
    return {"total": total, **n, "fraction": (n["done"] + n["failed"]) / total if total else 0.0}


def queue_view(store: Store, prover: ClassifierProver) -> dict:
    running = store.q("SELECT * FROM jobs WHERE status='running' ORDER BY id")
    queued = store.q("SELECT * FROM jobs WHERE status='queued' ORDER BY id")
    cur = None
    if running:
        j = running[0]
        st = prover.poll(Path(j["job_dir"])) if j["job_dir"] else {}
        step = st.get("step", "queued")
        label = STEP_LABELS.get(step, step)
        if st.get("waiting_for_machine"):
            label = "Waiting for the machine (the shared box's resource guard) before: " + label
        prog = item_progress(store, j["post_id"])
        cur = {"job_id": j["id"], "post_id": j["post_id"], "kind": j["kind"], "chunk": int(j.get("chunk") or 0),
               "chunks": prog["total"], "progress": prog, "step": step, "label": label,
               "step_since": st.get("step_since"), "started_at": j["started_at"],
               "waiting_for_machine": st.get("waiting_for_machine", False)}
    items, order = {}, []
    for j in queued:
        if j["post_id"] not in items:
            items[j["post_id"]] = {"post_id": j["post_id"], "kind": j["kind"], "jobs": 0}
            order.append(j["post_id"])
        items[j["post_id"]]["jobs"] += 1
    eta, out = (PER_JOB_S if cur else 0.0), []
    for i, pid in enumerate(order):
        eta += items[pid]["jobs"] * PER_JOB_S
        out.append({**items[pid], "position": i + 1, "eta_s": eta, "progress": item_progress(store, pid)})
    return {"running": cur, "queued": out, "queued_jobs": len(queued), "held": config.HOLD_FILE.exists(),
            "guard": guard_status(), "per_job_s": PER_JOB_S, "now": time.time()}
