"""SQLite storage (one file under the PRIVATE data root: it holds post text)."""
from __future__ import annotations

import json
import sqlite3
import threading
from pathlib import Path

from . import records

SCHEMA = """
CREATE TABLE IF NOT EXISTS posts(
  id TEXT PRIMARY KEY, created_at TEXT NOT NULL, author TEXT NOT NULL, kind TEXT NOT NULL,
  text TEXT, media_name TEXT, media_sha256 TEXT, media_mime TEXT, media_bytes INTEGER, media_meta TEXT,
  status TEXT NOT NULL, status_message TEXT, verdict TEXT, prover_kind TEXT,
  record TEXT, anchor_ref TEXT, published_at TEXT, content_key TEXT, salt_enc TEXT, prove_attempted INTEGER,
  labels TEXT, manifest TEXT, chunks TEXT);
CREATE TABLE IF NOT EXISTS jobs(
  id INTEGER PRIMARY KEY AUTOINCREMENT, post_id TEXT NOT NULL, kind TEXT NOT NULL, status TEXT NOT NULL,
  created_at TEXT NOT NULL, started_at TEXT, finished_at TEXT, job_dir TEXT, result TEXT, error TEXT, chunk INTEGER);
CREATE TABLE IF NOT EXISTS checks(
  id INTEGER PRIMARY KEY AUTOINCREMENT, post_id TEXT NOT NULL, job_id INTEGER, at TEXT NOT NULL,
  ok INTEGER NOT NULL, verdict TEXT);
CREATE TABLE IF NOT EXISTS chunk_proofs(
  post_id TEXT NOT NULL, chunk INTEGER NOT NULL, status TEXT NOT NULL, record TEXT, error TEXT, attempted INTEGER,
  finished_at TEXT, PRIMARY KEY(post_id, chunk));
CREATE INDEX IF NOT EXISTS jobs_status ON jobs(status, id);
CREATE INDEX IF NOT EXISTS posts_status ON posts(status, created_at);
CREATE INDEX IF NOT EXISTS posts_key ON posts(content_key);
"""


class Store:
    def __init__(self, path: Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(self.path), check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.executescript(SCHEMA)
        cols = {r[1] for r in self.db.execute("PRAGMA table_info(posts)")}
        for col, typ in (("content_key", "TEXT"), ("salt_enc", "TEXT"), ("prove_attempted", "INTEGER"),
                         ("labels", "TEXT"), ("manifest", "TEXT"), ("chunks", "TEXT")):
            if col not in cols:                       # an older database: add the column in place
                self.db.execute(f"ALTER TABLE posts ADD COLUMN {col} {typ}")
        jcols = {r[1] for r in self.db.execute("PRAGMA table_info(jobs)")}
        if "chunk" not in jcols:
            self.db.execute("ALTER TABLE jobs ADD COLUMN chunk INTEGER")
        try:
            self.path.chmod(0o600)
        except OSError:
            pass

    def q(self, sql: str, args=()) -> list[dict]:
        with self.lock:
            return [dict(r) for r in self.db.execute(sql, args).fetchall()]

    def one(self, sql: str, args=()) -> dict | None:
        r = self.q(sql, args)
        return r[0] if r else None

    def x(self, sql: str, args=()) -> int:
        with self.lock:
            cur = self.db.execute(sql, args)
            return cur.lastrowid

    # ------------------------------------------------------------ posts
    def add_post(self, **kw) -> None:
        kw.setdefault("created_at", records.now_iso())
        cols = ",".join(kw)
        self.x(f"INSERT INTO posts({cols}) VALUES({','.join('?' * len(kw))})", tuple(kw.values()))

    def update_post(self, pid: str, **kw) -> None:
        sets = ",".join(f"{k}=?" for k in kw)
        self.x(f"UPDATE posts SET {sets} WHERE id=?", (*kw.values(), pid))

    def post(self, pid: str) -> dict | None:
        return self.one("SELECT * FROM posts WHERE id=?", (pid,))

    # ------------------------------------------------------------ jobs
    def add_job(self, post_id: str, kind: str, chunk: int = 0) -> int:
        return self.x("INSERT INTO jobs(post_id,kind,status,created_at,chunk) VALUES(?,?,?,?,?)",
                      (post_id, kind, "queued", records.now_iso(), chunk))

    def update_job(self, jid: int, **kw) -> None:
        sets = ",".join(f"{k}=?" for k in kw)
        self.x(f"UPDATE jobs SET {sets} WHERE id=?", (*kw.values(), jid))

    def job(self, jid: int) -> dict | None:
        return self.one("SELECT * FROM jobs WHERE id=?", (jid,))


def loads(s: str | None):
    return json.loads(s) if s else None
