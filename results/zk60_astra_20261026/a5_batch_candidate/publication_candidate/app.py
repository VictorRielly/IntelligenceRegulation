"""Proven Media: a local demo of a media feed whose posts carry PROVED CONTENT LABELS (one classifier
proof per registered category, made once at creation) and a signed proof manifest; the feed is
filtered per audience by the proved labels (D37 latest: labels are used for distribution).

Run:  apps/proven-media/.venv/bin/python apps/proven-media/serve.py   (see README.md)
"""
from __future__ import annotations

from .quarantine_paths import require_public_receipt_path

import calendar
import hashlib
import json
import logging
import os
import re
import secrets
import tarfile
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, JSONResponse, Response, StreamingResponse
from fastapi.staticfiles import StaticFiles

from . import auth, config, items, manifest, prompting, provers, records
from .jobs import PER_JOB_S, Worker, chunks_of, item_progress, queue_view
from .publisher import AnchorRef, LocalChainPublisher, PublishError, content_commitment, make_publisher
from .store import Store, loads
from .storage_policy import validate_storage

log = logging.getLogger("proven_media")
HANDLE_RE = re.compile(r"^@?[A-Za-z0-9_]{1,24}$")


class State:
    auth: auth.AuthorAuth
    store: Store
    prover: provers.ClassifierProver
    publisher: LocalChainPublisher
    worker: Worker | None = None


S = State()


def init_state(start_worker: bool = True) -> None:
    validate_storage()         # fail before creating a database, key, or worker
    records.categories()      # refuses to start if a registered category policy text changed (design rule 2)
    provers.ensure_private_roots()
    manifest.public_key_hex()  # creates the local dev signing key (0600) on first start
    S.auth = auth.AuthorAuth(config.PRIVATE_DIR / "auth.sqlite3")
    S.store = Store(config.DB_PATH)
    validate_storage(S.store)  # do not revive saved jobs pointing into /tmp
    S.prover = provers.make_prover()
    S.publisher = make_publisher()
    w = Worker(S.store, S.prover, S.publisher)
    migrated = w.migrate_legacy()
    if migrated:
        log.info("re-filed %d pre-chunk post(s) as chunk 0: %s", len(migrated), ", ".join(migrated))
    if start_worker:
        S.worker = w
        S.worker.start()


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_state(start_worker=os.environ.get("PM_NO_WORKER") != "1")
    yield
    if S.worker:
        S.worker.stop()


app = FastAPI(title="Proven Media", lifespan=lifespan)
app.mount("/static", StaticFiles(directory=str(config.STATIC_DIR)), name="static")


@app.middleware("http")
async def private_cache_policy(request: Request, call_next):
    response = await call_next(request)
    if request.url.path.startswith("/api/"):
        response.headers["Cache-Control"] = "no-store"
        response.headers["Vary"] = "Cookie"
    return response


def same_origin(req: Request):
    origin = req.headers.get("origin")
    if origin and origin.rstrip("/") != str(req.base_url).rstrip("/"):
        raise HTTPException(403, "request origin refused")


def current_session(req: Request) -> auth.Session | None:
    return S.auth.session(req.cookies.get(auth.COOKIE))


def require_session(req: Request, *, operator: bool = False) -> auth.Session:
    session = current_session(req)
    if session is None:
        raise HTTPException(401, "sign in to continue")
    if operator and not session.operator:
        raise HTTPException(403, "operator access required")
    if req.method not in ("GET", "HEAD", "OPTIONS"):
        same_origin(req)
        if not secrets.compare_digest(req.headers.get("x-pm-csrf", ""), session.csrf):
            raise HTTPException(403, "request token refused")
    return session


def owns_post(req: Request, p: dict) -> bool:
    session = current_session(req)
    return session is not None and session.author == p["author"]


@app.get("/api/session")
def api_session(req: Request):
    session = current_session(req)
    return session.public() if session else {"author": None, "operator": False}


@app.post("/api/session")
async def api_login(req: Request):
    same_origin(req)
    if req.headers.get("content-type", "").split(";", 1)[0].strip().lower() != "application/json":
        raise HTTPException(415, "JSON required")
    # Bound the unauthenticated request before parsing or hashing credentials.
    raw = bytearray()
    async for chunk in req.stream():
        raw.extend(chunk)
        if len(raw) > 1024:
            raise HTTPException(413, "request too large")
    try:
        body = json.loads(raw)
    except (ValueError, UnicodeError):
        raise HTTPException(400, "invalid request") from None
    result = S.auth.login(body.get("access_key")) if isinstance(body, dict) else None
    if result is None:
        raise HTTPException(401, "invalid access key")
    old = req.cookies.get(auth.COOKIE)
    if old:
        S.auth.logout(old)
    token, session = result
    response = JSONResponse(session.public())
    response.set_cookie(auth.COOKIE, token, max_age=auth.SESSION_SECONDS, httponly=True,
                        secure=req.url.scheme == "https", samesite="strict", path="/")
    return response


@app.delete("/api/session")
def api_logout(req: Request):
    require_session(req)
    S.auth.logout(req.cookies[auth.COOKIE])
    response = JSONResponse({"signed_out": True})
    response.delete_cookie(auth.COOKIE, path="/", httponly=True,
                           secure=req.url.scheme == "https", samesite="strict")
    return response


# ---------------------------------------------------------------- views

def _job_state(pid: str) -> dict | None:
    """a pending item's progress: chunk jobs done / running / queued, the current step, an ETA"""
    jobs = S.store.q("SELECT * FROM jobs WHERE post_id=? AND kind='prove' ORDER BY id", (pid,))
    if not jobs:
        return None
    prog = item_progress(S.store, pid)
    run = next((j for j in jobs if j["status"] == "running"), None)
    out = {"progress": prog, "status": "running" if run else ("queued" if prog["queued"] else "done"),
           "started_at": min((j["started_at"] for j in jobs if j["started_at"]), default=None)}
    running_any = S.store.one("SELECT started_at FROM jobs WHERE status='running' ORDER BY id LIMIT 1")
    run_left = PER_JOB_S
    if running_any and running_any["started_at"]:
        run_left = max(15.0, PER_JOB_S - (time.time() - calendar.timegm(time.strptime(running_any["started_at"], "%Y-%m-%dT%H:%M:%SZ"))))
    first_q = next((j for j in jobs if j["status"] == "queued"), None)
    ahead = 0
    if first_q:
        ahead = S.store.one("SELECT COUNT(*) AS n FROM jobs WHERE status IN ('queued','running') AND id < ? AND post_id != ?",
                            (first_q["id"], pid))["n"]
        out["ahead"] = ahead
    own_left = prog["queued"] + (1 if run else 0)
    out["eta_s"] = ((run_left if running_any else 0) + max(0, ahead - (1 if running_any and not run else 0)) * PER_JOB_S
                    + max(0, own_left - (1 if run else 0)) * PER_JOB_S + (0 if run else 0))
    if run and run["job_dir"]:
        st = S.prover.poll(Path(run["job_dir"]))
        out.update(chunk=int(run.get("chunk") or 0), step=st["step"], step_label=provers.STEP_LABELS.get(st["step"], st["step"]),
                   step_since=st["step_since"], waiting_for_machine=st["waiting_for_machine"])
    return out


def chunks_view(p: dict) -> list[dict]:
    """per chunk: token range, job status (queued / running + step / done / failed), per-category labels"""
    if p["kind"] != "text" or p["status"] == "deleted":
        return []
    plan = chunks_of(p) if p.get("text") else (loads(p.get("chunks")) or [])
    jobs = {int(j.get("chunk") or 0): j for j in S.store.q("SELECT * FROM jobs WHERE post_id=? AND kind='prove' ORDER BY id", (p["id"],))}
    rows = {r["chunk"]: r for r in S.store.q("SELECT * FROM chunk_proofs WHERE post_id=?", (p["id"],))}
    out = []
    for ch in plan:
        j, r = jobs.get(ch["index"]), rows.get(ch["index"])
        st = {**ch, "tokens": ch["end"] - ch["start"]}
        if r:
            rec = loads(r["record"])
            st["status"] = "done" if r["status"] == "done" else "failed"
            st["labels"] = records.effective_labels(rec if r["status"] == "done" else None)
            if 'category' in ch:
                st['labels'] = {ch['category']: st['labels'][ch['category']]}
            if rec:
                st["statement_sha256"] = rec.get("statement_sha256")
        elif j and j["status"] == "running":
            ps = S.prover.poll(Path(j["job_dir"])) if j["job_dir"] else {}
            st.update(status="running", step=ps.get("step"), step_label=provers.STEP_LABELS.get(ps.get("step"), ps.get("step")),
                      waiting_for_machine=ps.get("waiting_for_machine", False))
        else:
            st["status"] = "queued"
        out.append(st)
    return out


def labels_view(p: dict) -> dict:
    """per category: the effective label (fail closed: unproved counts as the most restrictive)"""
    eff = loads(p["labels"]) or records.effective_labels(None)
    rec = loads(p["record"]) or {}
    out = []
    for c in config.registered_categories():
        lab = (rec.get("labels") or {}).get(c["id"], {})
        out.append({"category": c["id"], "name": c["name"], "short": c["short"], "value": eff.get(c["id"], records.UNPROVED),
                    "proof": lab.get("proof", "none") if eff.get(c["id"]) != records.UNPROVED else "none",
                    "bound_by_proof": bool(lab.get("bound_by_proof")), "policy_id": c["policy_id"], "policy_sha256": c["sha256"]})
    return {"labels": out, "complete": p["status"] == "published"}


def post_view(p: dict, show_text: bool, audience: dict | None = None) -> dict:
    """one item as served: its labels and signed manifest travel with it; an item hidden for the viewer's
    audience is served as a placeholder with the reason, never with its content"""
    if p["status"] != "published":
        # Only authenticated owners may reach this view. Never expose intermediate
        # proof outcomes, failure diagnostics, attempt counts or timings here.
        if p["status"] == "failed":
            return {"id": p["id"], "status": "failed", "status_message": "Could not be verified."}
        status = "pending" if p["status"] in ("queued", "screening") else p["status"]
        return {"id": p["id"], "status": status, "author": p["author"], "kind": p["kind"],
                "text": p["text"] if show_text and p["kind"] == "text" else None,
                **({"media": loads(p["media_meta"]) or {}} if p["kind"] == "image" else {}),
                "status_message": "Verification pending." if status == "pending" else None}
    meta = loads(p["media_meta"]) or {}
    v = {k: p[k] for k in ("id", "created_at", "author", "kind", "status", "status_message",
                           "prover_kind", "published_at")}
    lv = labels_view(p)
    v.update(lv)
    if audience is not None and p["status"] == "published":
        ok, reasons = records.visibility({x["category"]: x["value"] for x in lv["labels"]}, audience)
        if not ok:
            return {"id": p["id"], "kind": p["kind"], "status": p["status"], "created_at": p["created_at"],
                    "hidden": True, "audience": audience, "reasons": reasons, "labels": lv["labels"]}
    v["text"] = p["text"] if (show_text and p["kind"] == "text") else None
    v["text_hidden"] = p["kind"] == "text" and not show_text
    v["media"] = meta
    rec = loads(p["record"])
    if rec:
        v["badge"] = {"prover_kind": (rec.get("prover") or {}).get("kind"), "prover_label": (rec.get("prover") or {}).get("label"),
                      "classifier": config.CLASSIFIER_NAME}
    m = loads(p["manifest"])
    if m and show_text:
        v["manifest"] = m
    if p["status"] in ("queued", "screening"):
        v["job"] = _job_state(p["id"])
    v["chunks"] = chunks_view(p)
    v["retry_allowed"] = p["status"] == "failed" and p.get("prove_attempted") == 0 and \
        p.get('screening_context') == records.screening_context() and \
        all(c.get("status") == "failed" for c in v["chunks"])
    return v


def public_record(p: dict) -> dict | None:
    """the item record (D41: per-chunk proof records inside) plus how to verify each chunk offline"""
    rec = loads(p["record"])
    if not rec:
        return None
    def without_operational_fields(value):
        if isinstance(value, dict):
            return {k: without_operational_fields(v) for k, v in value.items() if k not in ("timings", "proved_at")}
        if isinstance(value, list):
            return [without_operational_fields(v) for v in value]
        return value
    rec = without_operational_fields(rec)
    first = next((c["record"] for c in rec.get("chunks", []) if c.get("record")), None)
    rec["verify_with"] = provers.verify_instructions(first or rec)
    return rec


# ---------------------------------------------------------------- pages

@app.get("/")
def index():
    return FileResponse(config.STATIC_DIR / "index.html", headers={"Cache-Control": "no-store"})


@app.get("/api/config")
def api_config():
    pub = manifest.public_key_hex()
    return {"prover": S.prover.describe(), "prover_mode": config.prover_mode(),
            "classifier": {"name": config.CLASSIFIER_NAME, "source": config.CLASSIFIER_SOURCE,
                           "status": S.prover.describe().get('privacy_status', 'classifier prover in development; the app runs the stub')},
            "categories": records.categories(), "category_set": {"id": config.category_set_id(),
                                                                 "digest": records.category_set_digest()},
            "audiences": {k: {"name": a["name"], "restricted": a["restricted"], "custom": a.get("custom", False)}
                          for k, a in config.AUDIENCES.items()},
            "threshold": records.threshold(),
            "image_spec": {"id": items.IMAGE_SPEC_ID, "text": items.IMAGE_SPEC_TEXT, "canvas_px": items.CANVAS_PX,
                           "fill_rgb": items.FILL_RGB},
            "publisher": {"name": S.publisher.name, "description": S.publisher.description,
                          "key_id": manifest.key_id(pub), "public_key": pub},
            "deploy": config.deploy(),
            "limits": {"max_content_tokens": config.deploy()["max_content_tokens"], "T": 128 if config.prover_mode() == "shieldstral" else config.STUB_T,
                       "stub_chunk_max": config.STUB_MAX_CONTENT_TOKENS, "max_image_bytes": config.MAX_IMAGE_BYTES},
            "expected": {"stub_work_s": "about 150 s of work on a quiet laptop (prepare ~15 s, prove ~85 s, "
                                        "verify + open + bind ~45 s), plus any wait for the shared machine",
                         "shieldstral_est_s": "about 7.5 min proving plus preparation and three checks per category; "
                                              "about 700 s total work per category, plus shared-machine wait"}}


@app.get("/api/publisher-key")
def api_publisher_key():
    pub = manifest.public_key_hex()
    return {"alg": "Ed25519", "public_key": pub, "key_id": manifest.key_id(pub), "note": "local development key"}


@app.post("/api/tokenize")
async def api_tokenize(req: Request):
    require_session(req)
    from . import proof_plans
    body = await req.json()
    text = str(body.get("text", ""))[:4000]
    d = config.deploy()
    n = 0
    try:
        n = S.prover.content_length(text)
        plan = S.prover.plan_text(text) if n else []
        fits = bool(plan)
    except (prompting.ContentRefused, provers.ProverError):
        plan, fits = [], False
    per_category = proof_plans.is_category_plan(plan)
    return {"count": n, "max": None if per_category else d["max_content_tokens"], "fits": fits, "chunks": len(plan),
            "chunk_tokens": None if per_category else d["effective_chunk_tokens"],
            "overlap_tokens": None if per_category else d["effective_overlap_tokens"],
            "proofs": proof_plans.proof_count(plan), "profile": 'per-category' if per_category else d["profile"],
            "category_chunks": {c: sum(c in proof_plans.categories_for(ch) for ch in plan) for c in records.category_ids()}}


@app.get("/api/status")
def api_status(req: Request):
    """the admin / status page: deployment profile (chunking), prover limits, queue, machine, ledger"""
    require_session(req, operator=True)
    counts = {r["status"]: r["n"] for r in S.store.q("SELECT status, COUNT(*) AS n FROM posts GROUP BY status")}
    blocks = S.publisher.blocks_list()
    return {"deploy": config.deploy(), "prover": S.prover.describe(), "queue": queue_view(S.store, S.prover),
            "posts": counts, "ledger": {"blocks": len(blocks), "pending_leaves": len(S.publisher.pending_list()),
                                        "batch_secs": S.publisher.batch_secs},
            "categories": [{"id": c["id"], "name": c["name"], "policy_id": c["policy_id"]} for c in config.registered_categories()],
            "hold": config.HOLD_FILE.exists(), "server_time": records.now_iso()}


def _sniff(head: bytes) -> str | None:
    if head.startswith(b"\x89PNG"):
        return "image/png"
    if head[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    if head[:6] in (b"GIF87a", b"GIF89a"):
        return "image/gif"
    return None


@app.post("/api/posts")
async def api_create_post(req: Request, author: str = Form(...), kind: str = Form("text"), text: str = Form(""),
                          file: UploadFile | None = File(None)):
    from . import proof_plans
    if not HANDLE_RE.match(author.strip()):
        raise HTTPException(400, "a handle is 1-24 letters, digits or _")
    author = "@" + author.strip().lstrip("@")
    if require_session(req).author != author:
        raise HTTPException(403, "author does not match the signed-in account")
    pid = secrets.token_hex(16)        # 128-bit random post id (report §7: never a user id)
    if kind == "text":
        text = text.strip()
        if not text:
            raise HTTPException(400, "the post is empty")
        if len(text) > 1000:
            raise HTTPException(400, "the post is too long")
        try:
            plan = S.prover.plan_text(text)       # same pinned encoding and category geometry as the proof
            proof_plans.check_plan(plan, plan)
        except (prompting.ContentRefused, provers.ProverError) as e:
            raise HTTPException(400, str(e)[:1].upper() + str(e)[1:] + ".")
        # D45: the private item reservation is independent of policy/threshold.
        key = records.content_key(text)
        from .store import ScreeningConflict
        try:
            S.store.add_screened_post(text, plan, id=pid, author=author, kind="text", text=text, status="queued",
                                     prover_kind=S.prover.kind, content_key=key, salt_enc=records.new_salt_enc(pid),
                                     chunks=json.dumps(plan))
        except ScreeningConflict as exc:
            raise HTTPException(409, str(exc)) from None
        return {"post_id": pid, "status": "queued", "chunks": len(plan), "proofs": proof_plans.proof_count(plan)}
    if kind != "image" or file is None:
        raise HTTPException(400, "a post is a text or one image (video and audio are deferred)")
    raw = bytearray()
    while True:
        chunk = await file.read(1 << 20)
        if not chunk:
            break
        raw += chunk
        if len(raw) > config.MAX_IMAGE_BYTES:
            raise HTTPException(413, f"image too large for the demo (limit {config.MAX_IMAGE_BYTES // (1024 * 1024)} MB)")
    mime = _sniff(bytes(raw[:16]))
    if mime not in config.IMAGE_MIME:
        raise HTTPException(400, f"unsupported image type (accepted: {', '.join(config.IMAGE_MIME)})")
    try:
        master, w, h = items.lossless_master(bytes(raw))     # EXIF orientation applied, metadata dropped
    except items.ImageRefused as e:
        raise HTTPException(400, str(e))
    upload_bytes = len(raw)
    del raw                                                  # the original upload is not kept: the master is the post
    canvas = items.canonical_canvas(master)
    tensor = items.canonical_tensor(canvas)
    tsha = hashlib.sha256(tensor).hexdigest()
    key = records.content_key("image:" + items.IMAGE_SPEC_ID + ":" + tsha)
    prev = S.store.one("SELECT id, status FROM posts WHERE content_key=? AND status NOT IN ('failed','deleted') "
                       "ORDER BY created_at LIMIT 1", (key,))
    if prev:
        raise HTTPException(409, f"This exact image (same canonical canvas) was already submitted (post {prev['id']}, "
                                 f"{prev['status']}). It is not screened again.")
    salt_enc = records.new_salt_enc(pid)
    commit = items.image_commitment(records.salt_of(pid, salt_enc), tensor)
    for name, data in ((f"{pid}.png", master), (f"{pid}-canvas.png", None)):
        fd = os.open(config.MEDIA_DIR / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "wb") as out:
            if data is not None:
                out.write(data)
            else:
                canvas.save(out, "PNG")
    sha = hashlib.sha256(master).hexdigest()
    it = items.ImageItem(path=config.MEDIA_DIR / f"{pid}.png", sha256=sha, mime="image/png", bytes=len(master),
                         width=w, height=h, canvas_sha256=tsha)
    ms = provers.media_status(it)
    meta = {"width": w, "height": h, "upload_mime": mime, "upload_bytes": upload_bytes, "spec": items.IMAGE_SPEC_ID,
            "canvas_px": items.CANVAS_PX, "tensor_bytes": len(tensor), "salted_commitment": commit, **ms}
    from .store import ScreeningConflict
    try:
        S.store.add_screened_post(items.IMAGE_SPEC_ID + ':' + tsha,
                         id=pid, author=author, kind="image", media_name=f"{pid}.png", media_sha256=sha, media_mime="image/png",
                         salt_enc=salt_enc, content_key=key, media_bytes=len(master), media_meta=json.dumps(meta),
                         status="in-development", status_message=ms["message"], prover_kind=S.prover.kind)
    except ScreeningConflict as exc:
        (config.MEDIA_DIR / f'{pid}.png').unlink()
        (config.MEDIA_DIR / f'{pid}-canvas.png').unlink()
        raise HTTPException(409, str(exc)) from None
    return {"post_id": pid, "status": "in-development", "message": ms["message"]}


@app.get("/api/feed")
def api_feed(audience: str = "adult", hide: str = ""):
    """published items only (labels complete), filtered for the viewer's audience by the PROVED labels;
    a hidden item is served as a placeholder with the reason, never its content"""
    aud = records.audience_of(audience, hide)
    rows = S.store.q("SELECT * FROM posts WHERE status='published' ORDER BY published_at DESC LIMIT 100")
    return {"audience": aud, "posts": [post_view(p, show_text=True, audience=aud) for p in rows]}


@app.get("/api/submissions")
def api_submissions(req: Request, author: str = ""):
    a = require_session(req).author
    if author and ("@" + author.strip().lstrip("@")) != a:
        raise HTTPException(403, "author does not match the signed-in account")
    rows = S.store.q("SELECT * FROM posts WHERE author=? ORDER BY created_at DESC LIMIT 50", (a,))
    return {"posts": [post_view(p, show_text=True) for p in rows]}


@app.get("/api/posts/{pid}")
def api_post(pid: str, req: Request, audience: str = "adult", hide: str = ""):
    p = S.store.post(pid)
    if not p:
        raise HTTPException(404, "no such post")
    is_author = owns_post(req, p)
    if p["status"] != "published":
        if not is_author:
            raise HTTPException(404, "no such post")
        return post_view(p, show_text=True)
    show = p["status"] == "published" or is_author
    aud = None if is_author else records.audience_of(audience, hide)
    v = post_view(p, show_text=show, audience=aud)
    if v.get("hidden"):
        return v                                   # hidden for this audience: labels and reasons only
    v["record"] = public_record(p) if show else None
    v["checks"] = [{"at": c["at"], "ok": bool(c["ok"]), "verdict": loads(c["verdict"])}
                   for c in S.store.q("SELECT * FROM checks WHERE post_id=? ORDER BY id DESC LIMIT 10", (pid,))]
    pending = S.store.one("SELECT * FROM jobs WHERE post_id=? AND kind='recheck' AND status IN ('queued','running') "
                          "ORDER BY id DESC LIMIT 1", (pid,))
    if pending:
        st = S.prover.poll(Path(pending["job_dir"])) if pending["job_dir"] else {"step": "queued"}
        v["recheck"] = {"job_id": pending["id"], "status": pending["status"], "step": st.get("step"),
                        "step_label": provers.STEP_LABELS.get(st.get("step"), st.get("step")),
                        "waiting_for_machine": st.get("waiting_for_machine", False)}
    v["publication"] = publication_view(p) if show else None
    return v


def publication_view(p: dict) -> dict | None:
    """the item's AnchorRefs (one per proved category) plus what a viewer needs to check the salted
    content commitment"""
    anchors = S.publisher.anchors_of(p["id"])
    if p["status"] != "published" or not anchors:
        return None
    pending = any(a.status == "pending" for a in anchors.values())
    out = {"anchors": {c: a.to_dict() for c, a in anchors.items()},
           "next_batch_in_s": S.publisher.next_batch_in() if pending else None, "batch_secs": S.publisher.batch_secs}
    salt = records.salt_of(p["id"], p["salt_enc"])
    if salt is not None and p["text"] is not None:
        out["salt"] = salt.hex()
        out["content_commitment"] = content_commitment(salt, p["text"].encode())
        out["content_commitment_rule"] = "SHA-256(\"zk60/proven-media/content/v1\" || salt (32 bytes) || u64 big-endian byte length || UTF-8 content)"
    return out


@app.post("/api/posts/{pid}/verify-publication")
def api_verify_publication(pid: str):
    """the publication checks per proved category (store, manifest, leaf, Merkle path, block chain), in
    process; the proof itself is re-verified by the guarded "Re-verify now" job"""
    p = S.store.post(pid)
    anchors = S.publisher.anchors_of(pid) if p else {}
    if not anchors or p["status"] != "published":
        raise HTTPException(404, "this post has no published proof")
    out = {}
    for key, a in anchors.items():                      # "c<chunk>.<category>"
        r = S.publisher.verify_publication(a, rehash_segments=False)
        r.pop("manifest", None)
        out[key] = r
    return {"accepted": all(r["accepted"] for r in out.values()), "pending": any(r.get("pending") for r in out.values()),
            "per_proof": out}


@app.get("/api/posts/{pid}/manifest.json")
def api_manifest(pid: str, req: Request, audience: str = "adult", hide: str = ""):
    """the signed ProofManifest attached to the item (zk60.manifest/1)"""
    p = S.store.post(pid)
    if not p or p["status"] != "published" or not p["manifest"]:
        raise HTTPException(404, "no manifest (labels not complete)")
    is_author = owns_post(req, p)
    if not is_author:
        ok, _ = records.visibility(loads(p["labels"]) or {}, records.audience_of(audience, hide))
        if not ok:
            raise HTTPException(403, "hidden for this audience")
    return Response(json.dumps(loads(p["manifest"]), indent=1, sort_keys=True), media_type="application/json",
                    headers={"Content-Disposition": f'attachment; filename="{pid}.manifest.json"'})


@app.post("/api/posts/{pid}/verify-manifest")
def api_verify_manifest(pid: str):
    """signature (against the publisher's key), then each entry's anchor and Merkle path in the local
    ledger; the proofs themselves are re-run by "Re-verify now" (or tools/verify_manifest.py --run-verifier)"""
    p = S.store.post(pid)
    if not p or p["status"] != "published" or not p["manifest"]:
        raise HTTPException(404, "no manifest")
    return manifest.verify_manifest(loads(p["manifest"]), S.publisher, expected_public_key=manifest.public_key_hex())


@app.delete("/api/posts/{pid}")
def api_delete(pid: str, req: Request):
    """Erase content, salt, receipts and openings. The private D45 reservation
    remains to refuse another screening; it is not an opening of the commitment."""
    session = require_session(req)
    p = S.store.post(pid)
    if not p or session.author != p["author"]:
        raise HTTPException(404, "no such post")
    if p["status"] in ("queued", "screening"):
        raise HTTPException(409, "the post is being screened; delete it when the screening has finished")
    removed = 0
    for a in S.publisher.anchors_of(pid).values():
        try:
            removed += S.publisher.delete_receipt(a)
        except (PublishError, FileNotFoundError):
            pass
    rec = loads(p["record"]) or {}
    for c in rec.get("chunks", []):
        crec = c.get("record") or {}
        run = crec.get("receipt", {}).get("run_dir")
        if run and Path(run).is_dir():
            for seg in crec["receipt"].get("files", []):
                f = Path(run) / seg["file"]
                if f.exists():
                    f.unlink()
                    removed += 1
    jd = config.JOBS_DIR / pid
    if jd.is_dir():
        import shutil
        shutil.rmtree(jd)
    if p["media_name"]:
        (config.MEDIA_DIR / p["media_name"]).unlink(missing_ok=True)
        (config.MEDIA_DIR / f"{pid}-canvas.png").unlink(missing_ok=True)
        for t in (config.MEDIA_DIR / "thumbs").glob(f"{pid}-*"):
            t.unlink()
    S.store.update_post(pid, status="deleted", text=None, salt_enc=None, content_key=None, media_name=None,
                        status_message="Deleted by the author: content, salt and receipt erased. The anchored leaf "
                                       "remains; a private reservation prevents screening the item again.")
    return {"deleted": True}


@app.post("/api/posts/{pid}/verify")
def api_verify(pid: str, req: Request):
    """re-verify every chunk's stored proof in a fresh process (one guarded job per chunk); never re-proves"""
    session = require_session(req)
    p = S.store.post(pid)
    if not p or (session.author != p["author"] and not session.operator):
        raise HTTPException(404, "no such post")
    rows = S.store.q("SELECT chunk FROM chunk_proofs WHERE post_id=? AND status='done' ORDER BY chunk", (pid,)) if p else []
    if not p or p["status"] != "published" or not rows:
        raise HTTPException(400, "only a published item with accepted proofs can be re-checked")
    pending = S.store.one("SELECT id FROM jobs WHERE post_id=? AND kind='recheck' AND status IN ('queued','running')", (pid,))
    if pending:
        return {"status": "already queued"}
    ids = [S.store.add_job(pid, "recheck", r["chunk"]) for r in rows]
    return {"job_ids": ids, "status": "queued", "chunks": len(ids)}


@app.get("/api/posts/{pid}/record.json")
def api_record(pid: str):
    p = S.store.post(pid)
    if not p or p["status"] != "published":
        raise HTTPException(404, "no published record")
    return Response(json.dumps(public_record(p), indent=1, sort_keys=True), media_type="application/json",
                    headers={"Content-Disposition": f'attachment; filename="proven-media-{pid}-record.json"'})


def _tar_member(name: str, size: int, mtime: int) -> bytes:
    ti = tarfile.TarInfo(name)
    ti.size, ti.mtime, ti.mode = size, mtime, 0o644
    return ti.tobuf(format=tarfile.USTAR_FORMAT)


@app.get("/api/posts/{pid}/bundle.tar")
def api_bundle(pid: str):
    p = S.store.post(pid)
    rec = public_record(p) if p and p["status"] == "published" else None
    chunk_runs = [(c["index"], Path(c["record"]["receipt"]["run_dir"]), c["record"])
                  for c in (rec or {}).get("chunks", []) if c.get("record") and c["record"]["receipt"].get("run_dir")]
    if not chunk_runs:
        raise HTTPException(404, "no published proof bundle")
    root = f"proven-media-{pid}"
    vw = rec["verify_with"]
    if any(crec.get('prover', {}).get('kind') == 'shieldstral' for _, _, crec in chunk_runs):
        instructions = []
        for ci, _, crec in chunk_runs:
            check = provers.verify_instructions(crec)
            command = check['command'].replace('<run>', f'{root}/chunk-{ci}/run')
            category = crec['chunk']['category']
            instructions.append(f"Chunk {ci}, category {category}:\n\n    {command}\n")
        readme = (f"# Proven Media proof bundle {pid}\n\n"
                  "Shieldstral-1.0-3B text classifier proofs for the three registered moderate policies.\n"
                  "The category verdicts are bound by their proofs. Privacy statement pending.\n\n"
                  f"Use {vw.get('binary')} and {vw.get('public_model_files')}.\n"
                  "Replace <public-export> with the public export directory. Verify every chunk with its own policy.\n"
                  "Each command must exit 0 with a classified event matching that chunk's recorded verdict.\n\n"
                  + '\n'.join(instructions)
                  + "\nThese commands check individual proofs. The whole-post category label also requires complete "
                    "chunk coverage and the native label --expect-total check used by the app.\n"
                  "Owners' openings and input activations are private and are not in this bundle.\n").encode()
    else:
        readme = (f"# Proven Media proof bundle {pid}\n\n"
                  f"DEMO STUB: a next-token proof of {config.STUB_MODEL_NAME}, not yet a {config.CLASSIFIER_NAME} classifier proof.\n"
                  f"The category labels in record.json are NOT bound by this proof (placeholder); one stub run stands in "
                  f"for the three category proofs.\n\n"
                  f"One proof run per chunk (D41), under chunk-<i>/run/. Verify each (exit 0 = valid):\n\n    {vw.get('command')}\n\n"
                  f"with <unpacked-bundle-dir> = {root}/chunk-<i>, the binary {vw.get('binary')},\n"
                  f"and the public model files: {vw.get('public_model_files')}.\n"
                  f"The owners' openings (decommitments) are private and not in this bundle (D21).\n").encode()
    members: list[tuple[str, object, int]] = [
        (f"{root}/VERIFY.md", readme, len(readme)),
        (f"{root}/record.json", (b := json.dumps(rec, indent=1, sort_keys=True).encode()), len(b)),
    ]
    anc = S.publisher.anchors_of(pid)
    if anc:
        pj = json.dumps({"anchor_refs": {c: a.to_dict() for c, a in anc.items()},
                         "note": S.publisher.description}, indent=1, sort_keys=True).encode()
        members.append((f"{root}/publication.json", pj, len(pj)))
    if p["manifest"]:
        mj = json.dumps(loads(p["manifest"]), indent=1, sort_keys=True).encode()
        members.append((f"{root}/{pid}.manifest.json", mj, len(mj)))
    for ci, run, crec in chunk_runs:
        require_public_receipt_path(run)
        for seg in crec["receipt"]["files"]:
            f = run / seg["file"]
            require_public_receipt_path(f)
            members.append((f"{root}/chunk-{ci}/run/{seg['file']}", f, f.stat().st_size))
        for rel in ("statement/statement.json", "statement/segments.json"):
            f = run / rel
            if rel == "statement/segments.json" and not f.exists():
                continue  # Classifier receipts keep their inventory in the app record.
            require_public_receipt_path(f)
            members.append((f"{root}/chunk-{ci}/run/{rel}", f, f.stat().st_size))
    mtime = int(time.time())
    total = sum(512 + -(-n // 512) * 512 for _, _, n in members) + 1024

    def gen():
        for name, src, n in members:
            yield _tar_member(name, n, mtime)
            if isinstance(src, bytes):
                yield src
            else:
                require_public_receipt_path(src)
                with open(src, "rb") as fh:
                    for blk in iter(lambda: fh.read(1 << 20), b""):
                        yield blk
            if n % 512:
                yield b"\0" * (512 - n % 512)
        yield b"\0" * 1024

    return StreamingResponse(gen(), media_type="application/x-tar",
                             headers={"Content-Disposition": f'attachment; filename="{root}.tar"',
                                      "Content-Length": str(total)})


@app.get("/api/queue")
def api_queue(req: Request):
    require_session(req, operator=True)
    return queue_view(S.store, S.prover)


@app.get("/api/ledger")
def api_ledger():
    blocks = S.publisher.blocks_list()
    return {"publisher": S.publisher.name, "description": S.publisher.description, "chain": S.publisher.chain_name,
            "batch_secs": S.publisher.batch_secs, "pending": len(S.publisher.pending_list()),
            "next_batch_in_s": S.publisher.next_batch_in(), "blocks": blocks[-50:][::-1]}


@app.post("/api/ledger/close-batch")
def api_close_batch(req: Request):
    """presenter convenience: close the pending batch now instead of waiting for the 10-minute timer"""
    require_session(req, operator=True)
    return {"batch_id": S.publisher.tick(force=True)}


@app.get("/api/posts/{pid}/canvas.png")
def api_canvas(pid: str, req: Request):
    """the exact canonical canvas the classifier will see: shown to the AUTHOR only while unscreened"""
    p = S.store.post(pid)
    if not p or p["status"] == "failed" or p["kind"] != "image" or not p["media_name"] or not owns_post(req, p):
        raise HTTPException(404)
    return FileResponse(config.MEDIA_DIR / f"{pid}-canvas.png", media_type="image/png", headers={"Cache-Control": "no-store"})
