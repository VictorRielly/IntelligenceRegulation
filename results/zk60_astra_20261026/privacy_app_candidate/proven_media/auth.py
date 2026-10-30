"""Operator-provisioned author credentials and revocable browser sessions.

Only random access keys are accepted, never a claimed handle or query parameter.
The private database stores hashes of keys and cookies, not their bearer values.
"""
from __future__ import annotations

from dataclasses import dataclass
from contextlib import contextmanager
import hashlib
import os
from pathlib import Path
import re
import secrets
import sqlite3
import time

COOKIE = "pm_session"
SESSION_SECONDS = 12 * 3600
HANDLE = re.compile(r"^@?[A-Za-z0-9_]{1,24}$")


def handle(value: str) -> str:
    if not isinstance(value, str) or not HANDLE.fullmatch(value.strip()):
        raise ValueError("a handle is 1-24 letters, digits or _")
    return "@" + value.strip().lstrip("@")


def digest(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


@dataclass(frozen=True)
class Session:
    author: str
    operator: bool
    csrf: str

    def public(self):
        return {"author": self.author, "operator": self.operator, "csrf": self.csrf}


class AuthorAuth:
    def __init__(self, path: Path):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        if self.path.parent.is_symlink():
            raise ValueError("auth root must not be a symlink")
        os.chmod(self.path.parent, 0o700)
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        os.fchmod(fd, 0o600)
        os.close(fd)
        with self._db() as db:
            db.executescript("""
                CREATE TABLE IF NOT EXISTS authors (
                    author TEXT PRIMARY KEY, key_hash TEXT UNIQUE NOT NULL,
                    operator INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS sessions (
                    token_hash TEXT PRIMARY KEY, author TEXT NOT NULL,
                    csrf TEXT NOT NULL, expires REAL NOT NULL);
            """)

    @contextmanager
    def _db(self):
        db = sqlite3.connect(self.path, timeout=10)
        try:
            with db:
                yield db
        finally:
            db.close()

    def provision(self, author: str, *, operator: bool = False, rotate: bool = False) -> str:
        """Local operator action. Existing identities require explicit rotation."""
        author = handle(author)
        key = secrets.token_urlsafe(32)
        with self._db() as db:
            exists = db.execute("SELECT 1 FROM authors WHERE author=?", (author,)).fetchone()
            if exists and not rotate:
                raise ValueError("author already exists; use explicit key rotation")
            db.execute("INSERT INTO authors VALUES (?,?,?) ON CONFLICT(author) DO UPDATE SET "
                       "key_hash=excluded.key_hash, operator=excluded.operator",
                       (author, digest(key), int(operator)))
            db.execute("DELETE FROM sessions WHERE author=?", (author,))
        return key

    def login(self, key: str) -> tuple[str, Session] | None:
        if not isinstance(key, str) or not 40 <= len(key) <= 128:
            return None
        with self._db() as db:
            row = db.execute("SELECT author,operator FROM authors WHERE key_hash=?", (digest(key),)).fetchone()
            if row is None:
                return None
            token, csrf = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
            db.execute("DELETE FROM sessions WHERE expires<=?", (time.time(),))
            db.execute("INSERT INTO sessions VALUES (?,?,?,?)",
                       (digest(token), row[0], csrf, time.time() + SESSION_SECONDS))
        return token, Session(row[0], bool(row[1]), csrf)

    def session(self, token: str | None) -> Session | None:
        if not isinstance(token, str) or not 40 <= len(token) <= 128:
            return None
        with self._db() as db:
            row = db.execute("SELECT a.author,a.operator,s.csrf FROM sessions s "
                             "JOIN authors a ON a.author=s.author "
                             "WHERE s.token_hash=? AND s.expires>?", (digest(token), time.time())).fetchone()
        return Session(row[0], bool(row[1]), row[2]) if row else None

    def logout(self, token: str):
        with self._db() as db:
            db.execute("DELETE FROM sessions WHERE token_hash=?", (digest(token),))
