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
  labels TEXT, manifest TEXT, chunks TEXT, screening_context TEXT);
CREATE TABLE IF NOT EXISTS screenings(
  item_key TEXT PRIMARY KEY, context TEXT NOT NULL, post_id TEXT NOT NULL);
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


class ScreeningConflict(ValueError):
    pass


class Store:
    def __init__(self, path: Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(self.path), check_same_thread=False, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.executescript(SCHEMA)
        from batch_registry import SCHEMA as BATCH_SCHEMA
        self.db.executescript(BATCH_SCHEMA)
        cols = {r[1] for r in self.db.execute("PRAGMA table_info(posts)")}
        for col, typ in (("content_key", "TEXT"), ("salt_enc", "TEXT"), ("prove_attempted", "INTEGER"),
                         ("labels", "TEXT"), ("manifest", "TEXT"), ("chunks", "TEXT"),
                         ("screening_context", "TEXT")):
            if col not in cols:                       # an older database: add the column in place
                self.db.execute(f"ALTER TABLE posts ADD COLUMN {col} {typ}")
        jcols = {r[1] for r in self.db.execute("PRAGMA table_info(jobs)")}
        if "chunk" not in jcols:
            self.db.execute("ALTER TABLE jobs ADD COLUMN chunk INTEGER")
        self._migrate_screenings()
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
    def _migrate_screenings(self) -> None:
        """Recover retained text identities; never invent a missing historic policy."""
        rows = self.q("SELECT * FROM posts WHERE kind='text' AND text IS NOT NULL ORDER BY created_at,id")
        if not rows:
            return
        current = records.screening_context()
        with self.lock:
            self.db.execute('BEGIN IMMEDIATE')
            try:
                for post in rows:
                    context = post.get('screening_context')
                    if context is None:
                        context = current if post.get('content_key') == records.content_key(post['text']) else \
                            records.canonical({'schema': 'legacy-screening-unresolved/1'}).decode()
                        self.db.execute('UPDATE posts SET screening_context=? WHERE id=?', (context, post['id']))
                    key = records.screening_key('text', post['text'])
                    claim = self.db.execute('SELECT context,post_id FROM screenings WHERE item_key=?', (key,)).fetchone()
                    if claim is None:
                        self.db.execute('INSERT INTO screenings VALUES(?,?,?)', (key, context, post['id']))
                    elif claim['context'] != context:
                        # Historic conflicting submissions cannot authorize another query.
                        self.db.execute('UPDATE screenings SET context=? WHERE item_key=?',
                                        ('{"schema":"legacy-screening-conflict/1"}', key))
                    else:
                        previous = self.post(claim['post_id'])
                        if (previous and previous['status'] == 'failed' and previous.get('prove_attempted') == 0
                                and not (post['status'] == 'failed' and post.get('prove_attempted') == 0)):
                            # An old pre-admission failure must not hide a later
                            # successful/attempted submission of the same item.
                            self.db.execute('UPDATE screenings SET post_id=? WHERE item_key=?', (post['id'], key))
                self.db.execute('COMMIT')
            except BaseException:
                self.db.execute('ROLLBACK')
                raise

    def add_screened_post(self, identity: str, plan=(), **kw) -> None:
        """Atomically reserve the item, create the post and queue its initial proofs.

        A retry is allowed only under the original context after failure before
        any proof work. Reservations remain after post/receipt deletion.
        """
        context = records.screening_context()
        key = records.screening_key(kw['kind'], identity)
        with self.lock:
            self.db.execute('BEGIN IMMEDIATE')
            try:
                claim = self.one('SELECT * FROM screenings WHERE item_key=?', (key,))
                if claim:
                    if claim['context'] != context:
                        raise ScreeningConflict('This item was already reserved under another policy or threshold. It cannot be screened again.')
                    previous = self.post(claim['post_id'])
                    if not (previous and previous['status'] == 'failed' and previous.get('prove_attempted') == 0):
                        raise ScreeningConflict('This exact content was already submitted. Each item is proved once; it is not proved again.')
                    self.x('UPDATE screenings SET post_id=? WHERE item_key=?', (kw['id'], key))
                else:
                    self.x('INSERT INTO screenings VALUES(?,?,?)', (key, context, kw['id']))
                self.add_post(**kw, screening_context=context)
                for chunk in plan:
                    self.add_job(kw['id'], 'prove', chunk['index'])
                self.db.execute('COMMIT')
            except BaseException:
                self.db.execute('ROLLBACK')
                raise

    def check_screening(self, post: dict) -> None:
        current = records.screening_context()
        claim = self.one('SELECT * FROM screenings WHERE item_key=?',
                         (records.screening_key('text', post['text']),))
        if (post.get('screening_context') != current or not claim or claim['context'] != current
                or claim['post_id'] != post['id']):
            raise ScreeningConflict('The policy or threshold differs from this item\'s original screening. No new proof may run.')

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
