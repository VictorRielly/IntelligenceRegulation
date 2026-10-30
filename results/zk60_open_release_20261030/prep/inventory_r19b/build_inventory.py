#!/usr/bin/env python3
"""Open-release inventory for the IntelligenceRegulation public snapshot (D48).

Read-only over the repository. Writes only into this script's directory:
  candidate_files.tsv        every file of the proposed public tree (public path, bytes, sha256,
                             decision, group, source path, note)
  candidate_summary.json     totals by group / decision, largest files, the tree spec
  secret_scan_hits.tsv       REDACTED hits: public path, line, kind, severity, file decision.
                             No matched value is ever written, only where and what kind.
  secret_scan_summary.json   counts per kind and severity, the patterns used, method notes
  abs_path_counts.tsv        per-file counts of absolute home / Windows-user paths (low risk)
  personal_keyword_counts.tsv per-file counts of personal / business keywords (docs review aid)
  name_flags.json            sensitive file NAMES in and around the candidate tree (no contents)

Usage: python3 -I build_inventory.py   (no arguments; about 35 s, < 100 MB RAM)
       python3 -I build_inventory.py --scan-tree <snapshot dir> <hits.tsv>   (re-scan a built snapshot)
"""
import hashlib
import json
import os
import re
import sys
import time

ROOT = "/home/victor/IntelligenceRegulation"
OUT = os.path.dirname(os.path.abspath(__file__))
R16B = "results/zk60_token_io_r1_20261017/frozen-r19b"  # E1 switch 2026-10-30: token round 19b (name kept)
GATE = "ops/zkp-mvp/gate-tinyllama/frozen_v24"
BIP39 = ROOT + "/apps/proven-media/.venv/lib/python3.10/site-packages/eth_account/hdaccount/wordlist/english.txt"

PRUNE_DIRS = {"target", ".git", ".venv", "venv", "node_modules", "__pycache__", ".testnet-private",
              ".pytest_cache", ".mypy_cache", ".ruff_cache"}
MAX_SCAN = 16 << 20

# (public prefix, source dir relative to ROOT, group, overlay?, note)
# overlay=True: add only files the public tree does not already have (main-tree docs the
# frozen reference copy lacks).
SPEC = [
    ("hashline", R16B + "/hashline", "prover-reference", False,
     "reference prover crate: token round 19b frozen copy (binary 6d65d32e)"),
    ("zkp-core", R16B + "/zkp-core", "prover-reference", False, "reference zkp-core (round 19b)"),
    ("private-block-kernel", R16B + "/private-block-kernel", "prover-reference", False,
     "reference private-block-kernel (identical to main tree's sources)"),
    ("private-block-kernel-shaped", R16B + "/private-block-kernel-shaped", "prover-reference", False,
     "reference shaped kernel (round 19b)"),
    ("results", R16B + "/results", "test-fixtures", False,
     "receipts / statements that the reference tests read by relative path"),
    ("hashline", "hashline", "prover-overlay", True, "main-tree README / .gitignore"),
    ("zkp-core", "zkp-core", "prover-overlay", True, "main-tree design docs and migration maps"),
    ("private-block-kernel", "private-block-kernel", "prover-overlay", True, "main-tree README / lock"),
    ("privacy-gate", GATE, "privacy-gate", False, "privacy gate tools, frozen v24"),
    ("zkvm-block", "zkvm-block", "zkvm-route", False, "RISC Zero route: private block"),
    ("zkvm-model", "zkvm-model", "zkvm-route", False, "RISC Zero route: token model"),
    ("zkvm-native-tools", "zkvm-native-tools", "zkvm-route", False, "Groth16 / receipt tools"),
    ("private-model-kernel", "private-model-kernel", "zkvm-route", False, "kernel used by zkvm-model"),
    ("zkmatrix-rs", "zkmatrix-rs", "research-lattice", False, "earlier lattice / zkMatrix Rust line"),
    ("zk_matrix", "zk_matrix", "research-python", False, "zkMatrix Python reproduction"),
    ("zk_matrix_fast", "zk_matrix_fast", "research-python", False, "zkMatrix C version"),
    ("zk_lattice", "zk_lattice", "research-python", False, "Route Z lattice reference"),
    ("scripts", "scripts", "tools-python", False, "Python tools, demos, resource guard"),
    ("tests", "tests", "tests-python", False, "Python test suite"),
    ("apps/proven-media", "apps/proven-media", "app", False, "proven-media app (no venv, no private state)"),
    ("web/techweek", "web/techweek", "demo-web", False, "demo page"),
    ("docs/zkmatrix-poc", "docs/zkmatrix-poc", "docs", False, "design, checks, statements, status"),
]
# Model export / calibration tools that today live in lane result directories (top-level *.py
# only). They must be lifted into the public tree, and their hard-coded paths parametrised,
# before a stranger can rebuild the real-model exports.
LANE_TOOLS = [
    ("tools/model-export/shieldstral-export", "results/zk60_shieldstral_export_20261026"),
    ("tools/model-export/shieldstral-prep", "results/zk60_shieldstral_prep_20261021/tools"),
    ("tools/model-export/llama3-8b-calibration", "results/zk60_8b_calibration_20261017"),
    ("tools/model-export/tinyllama-1b-calibration", "results/zk60_1b_calibration_20260929"),
    ("tools/model-export/tinyllama-1b-model", "results/zk60_1b_model_20260927"),
]
ROOT_FILES = [
    ("ZKMATRIX_REVIEW_NOTES.md", "root", "review notes (technical)"),
    (".gitignore", "root", "repository ignore rules"),
    ("README.md", "root", "REWRITE before release: placeholder license, personal manifesto"),
]
EVIDENCE = [
    "results/zk60_token_io_r1_20261017/frozen-r19b.FROZEN.txt",
    "results/zk60_token_io_r1_20261017/manifest_final_r19b.sha256",
    "results/zk60_token_io_r1_20261017/cli/binaries_r19b.sha256",
    "results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.BUILD.txt",
    "results/zk60_token_io_r1_20261017/cli/README.md",
    "results/zk60_token_io_r1_20261017/classifier/DESIGN_CLASSIFIER.md",
    "results/zk60_token_io_r1_20261017/classifier/check/CHECK.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R13.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R14.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R16.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R18.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R19.md",
    "results/zk60_token_io_review_r1_20261017/REVIEW_R19B.md",
    "results/zk60_d24_review_20261017/REVIEW_R13.md",
    "results/zk60_privacy_review_20261029/CLASSIFIER_T128_PRIVACY_REVIEW.md",
    "results/zk60_privacy_review_20261029/CLASSIFIER_T128_PRIVACY_REREVIEW_v2.md",
    "results/zk60_privacy_review_20261029/CLASSIFIER_T128_V3_CHECK.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW2.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW3.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW4.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW5.md",
    "results/zk60_privacy_review_trained_t32_20261017/REVIEW6.md",
    "results/zk60_gate_tinyllama_20261017/gate-tinyllama.tools.frozen.v24.sha256",
    "results/zk60_1b_pins_20260929/license_note.md",
    "results/zk60_astra_20261026/real_app_demo_1/RECOVERY_REPORT.md",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/manifest.json",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/audit.json",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/stored_verify_hate.json",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/stored_verify_sexual.json",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/stored_verify_violence.json",
    "results/zk60_astra_20261026/real_app_demo_1/recovery-20261030/stored_verify_complete.json",
    "results/zk60_astra_20261026/real_app_demo_1/sepolia_public_config.json",
    "results/zk60_astra_20261026/real_app_demo_1/publisher_public_key.json",
    "results/zk60_shieldstral_prep_20261021/pins.json",
    "results/zk60_shieldstral_prep_20261021/WEIGHTS.sha256",
    "results/zk60_mvp_20260929/llama3-8b/source.json",
]

# docs decisions: exclude = never publish; redact = publish only after the named edit;
# review = publish, but read once (names agents / people, coordination chatter)
DOC_EXCLUDE = {
    "ZK60_FUNDING_PLAN.md": "funding strategy (D43/D47): personal / business",
    "ZK60_REMOTE_ACCESS_SETUP.md": "SSH public key with user@host, Tailscale / home-network setup",
    "ZK60_HARDWARE_SETUP.md": "owner's machines and home setup",
    "ZK60_UNATTENDED_WORK.md": "agent sandbox / approval workflow on the owner's box",
    "ZK60_SOL_ASTRA_TODOS_20261026.md": "agent-team todo chatter",
    "ZK60_SOL_TEAM_20260927.md": "agent-team lane map",
    "ZK60_TEAM_TECHWEEK_20260930.md": "agent-team lane map",
    "ZK60_CODEX_FABLE_COORDINATION.md": "agent coordination log",
    "ZK60_FABLE_LANE_HANDOFF.md": "agent handoff log (322 KB)",
    "ZK60_CLAUDE_QUEUE.md": "agent queue", "ZK60_FABLE_QUEUE.md": "agent queue",
    "ZK60_OPUS_QUEUE.md": "agent queue",
    "zk60_claude_tasks.json": "agent task list", "zk60_fable_tasks.json": "agent task list",
}
DOC_REDACT = {
    "ZK60_DECISIONS.md": "drop or reword the personal parts of D43 (funding), D46 (laptop / Windows "
                         "details), D47 (new job, partner) before publishing; keep every technical ruling",
    "MVP_STATUS.md": "remove the crash / Windows-drive notes and agent-session chatter; keep the numbers",
    "START_HERE.md": "check for personal workflow notes (Telegram approvals, laptop specifics)",
    "ZK60_RULINGS_FOR_VICTOR.md": "addressed to the owner; keep the technical content, drop personal asides",
    "ZK60_RULINGS_FOR_VICTOR_20261017.md": "as above",
    "ZK60_RULINGS_FOR_VICTOR_PRIVACY.md": "as above",
    "ZK60_RESOURCE_PROTOCOL.md": "owner-box operations; fine to keep, drop Windows-host specifics",
}
DOC_EXCLUDE_DIRS = {"references": "third-party ePrint PDFs (link to eprint.iacr.org instead)"}

# ---------------------------------------------------------------- patterns (never print a match)
HEX64 = r"(?<![0-9a-fA-F])(?:0x)?[0-9a-fA-F]{64}(?![0-9a-fA-F])"
PATTERNS = [
    ("pem-private-key", "critical", re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----")),
    ("pgp-private-key", "critical", re.compile(r"-----BEGIN PGP PRIVATE KEY BLOCK-----")),
    ("github-token", "critical", re.compile(r"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}\b|\bgithub_pat_[A-Za-z0-9_]{50,}")),
    ("anthropic-api-key", "critical", re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}")),
    ("openai-api-key", "critical", re.compile(r"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{32,}")),
    ("aws-access-key-id", "critical", re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    ("google-api-key", "critical", re.compile(r"\bAIza[0-9A-Za-z_-]{35}\b")),
    ("slack-token", "critical", re.compile(r"\bxox[abposr]-[A-Za-z0-9-]{10,}")),
    ("huggingface-token", "critical", re.compile(r"\bhf_[A-Za-z0-9]{30,}\b")),
    ("telegram-bot-token", "critical", re.compile(r"\b\d{8,10}:[A-Za-z0-9_-]{35}\b")),
    ("jwt", "high", re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}")),
    ("rpc-url-with-key", "high", re.compile(
        r"https?://[^\s\"']*(?:infura\.io|alchemy\.com|quiknode\.pro|ankr\.com/[a-z_]+/[0-9a-f]{20,}|blastapi\.io|drpc\.org|chainstack\.com)/[^\s\"']{12,}")),
    ("secret-assignment", "high", re.compile(
        r"(?i)\b(?:api[_-]?key|secret[_-]?key|client[_-]?secret|access[_-]?token|auth[_-]?token|bot[_-]?token"
        r"|password|passwd|private[_-]?key)\b[\"']?\s*[:=]\s*[\"']([^\"'\s]{12,})[\"']")),
    ("ssh-public-key-userhost", "low", re.compile(r"\bssh-(?:rsa|ed25519|dss) AAAA[0-9A-Za-z+/=]{40,}(?: \S+@\S+)?")),
    ("telegram-api-ref", "low", re.compile(r"api\.telegram\.org|(?i:\btelegram\b)")),
    ("tailscale-ref", "low", re.compile(r"(?i)\btailscale\b|\.ts\.net\b")),
    ("eth-address", "info", re.compile(r"(?<![0-9a-fA-Fx])0x[0-9a-fA-F]{40}(?![0-9a-fA-F])")),
]
KEYWORD_LINE = re.compile(r"(?i)(private[_ -]?key|secret|mnemonic|seed[_ ]phrase|signing[_ ]key|privkey|sk_hex|wallet[_ ]key)")
HASHY_LINE = re.compile(r"(?i)(sha-?256|sha256|digest|hash|root|identity|commit|receipt|tx|transaction|block|blob|manifest|pin|fingerprint|blake|keccak|nonce|public)")
HEX64_RE = re.compile(HEX64)
HEX64_0X = re.compile(r"(?<![0-9a-fA-F])0x[0-9a-fA-F]{64}(?![0-9a-fA-F])")
EMAIL_RE = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
PHONE_RE = re.compile(r"(?<![\w.])(?:\+\d{1,3}[ .-]?)?(?:\(\d{3}\)\s?|\d{3}[ .-])\d{3}[ .-]\d{4}(?![\w.])")
IPV4_RE = re.compile(r"(?<![\w.])(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})(?![\w.])")
HOME_RE = re.compile(r"/home/victor\b|/Users/victor\b|~/zk60-owner-private")
WINUSER_RE = re.compile(r"(?i)C:\\\\?Users\\\\?victo|/mnt/c/Users/victo")
PERSONAL = {
    "employment": re.compile(r"(?i)\bnew job\b|\bemployer\b|invention[- ]assignment|\bsalary\b"),
    "funding": re.compile(r"(?i)\bfunding\b|\bgrant(?:s)?\b|\binvestor|\bY ?Combinator\b|\bYC W2\d|\bForesight\b|Fellows application|\bEA Funds\b|\bDARPA\b|\bNSF\b"),
    "patent": re.compile(r"(?i)\bpatent|\bprovisional\b"),
    "resume": re.compile(r"(?i)\br[eé]sum[eé]\b(?! (?:the|from|a|an|it|each|work|after|when|with|at)\b)|\bcurriculum vitae\b"),
    "telegram": re.compile(r"(?i)\btelegram\b|\btg-notify\b|\bspool\b"),
    "partner": re.compile(r"(?i)\bfind a partner\b|\ba partner to work\b|\bpartner\b"),
    "owner-machine": re.compile(r"(?i)\bMSI\b|\bvmmem\b|\.wslconfig|\bwsl --shutdown\b"),
}
SENSITIVE_NAME = re.compile(
    r"(?i)(^\.env$|\.env\.|\.pem$|\.key$|id_rsa|id_ed25519|\.p12$|\.pfx$|\.sqlite3?$|\.db$|sepolia-key|"
    r"owner-private|\.dec$|secret|credential|wallet|keystore|\.npmrc$|\.pypirc$|netrc)")


def load_bip39():
    try:
        with open(BIP39, encoding="utf-8") as f:
            return set(w.strip() for w in f if w.strip())
    except OSError:
        return set()


BIPWORDS = load_bip39()
WORD_RE = re.compile(r"[a-z]+")


def bip39_run(line):
    if not BIPWORDS:
        return False
    run = 0
    for tok in line.split():
        if tok in BIPWORDS:
            run += 1
            if run >= 12:
                return True
        else:
            run = 0
    return False


def public_ip(m):
    o = [int(x) for x in m.groups()]
    if any(x > 255 for x in o):
        return False
    if o[0] in (0, 10, 127) or o[0] >= 224:
        return False
    if o[0] == 192 and o[1] == 168:
        return False
    if o[0] == 172 and 16 <= o[1] <= 31:
        return False
    if o[0] == 169 and o[1] == 254:
        return False
    if o[0] == 100 and 64 <= o[1] <= 127:      # CGNAT / Tailscale
        return "cgnat"
    return True


def walk(src):
    base = os.path.join(ROOT, src)
    for d, ds, fs in os.walk(base, followlinks=False):
        ds[:] = sorted(x for x in ds if x not in PRUNE_DIRS and not x.startswith("target-")
                       and not x.startswith("target_"))
        for f in sorted(fs):
            if f.endswith((".pyc", ".pyo")):
                continue
            p = os.path.join(d, f)
            yield os.path.relpath(p, base), p


def decide(group, pub, src_abs):
    """(decision, note) for one file."""
    name = os.path.basename(pub)
    if group == "docs":
        rel = os.path.relpath(pub, "docs/zkmatrix-poc")
        top = rel.split("/")[0]
        if top in DOC_EXCLUDE_DIRS:
            return "exclude", DOC_EXCLUDE_DIRS[top]
        if rel in DOC_EXCLUDE:
            return "exclude", DOC_EXCLUDE[rel]
        if rel in DOC_REDACT:
            return "redact", DOC_REDACT[rel]
        if re.match(r"ZK60_(CLAUDE|FABLE|OPUS|PARALLEL_ROUND|SOL|CL\d)", rel):
            return "review", "agent-lane review / delivery note: technical, names agents"
        return "include", ""
    if group == "research-python" and name == "zk_matrix_fast" and "." not in name:
        return "exclude", "compiled binary (build from zk_matrix_fast.c)"
    if group == "app":
        if name in ("PROGRESS.md", "R_C1_DEVELOPMENT.md"):
            return "review", "agent ledger: technical, names agent lanes"
        if name == "deploy.json":
            return "review", "public testnet contract + deployer address (public on-chain anyway)"
    if group == "tools-python" and name in ("zk60_resource_watch.py",):
        return "review", "owner-box Windows host checks (PowerShell); fine but box-specific"
    return "include", ""


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def scan_file(pub, path, decision, hits, abs_counts, personal_counts):
    try:
        size = os.path.getsize(path)
        with open(path, "rb") as f:
            head = f.read(8192)
            if b"\0" in head:
                # binary: only look for a PEM private-key header
                f.seek(0)
                data = f.read(MAX_SCAN)
                if re.search(rb"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----", data):
                    hits.append((pub, 0, "pem-private-key(binary)", "critical", decision))
                if data[:4] == b"\x7fELF":
                    hits.append((pub, 0, "elf-executable", "info", decision))
                return "binary"
            if size > MAX_SCAN:
                hits.append((pub, 0, "text-too-large-not-scanned", "info", decision))
                return "text-large"
            f.seek(0)
            text = f.read().decode("utf-8", "replace")
    except OSError as e:
        hits.append((pub, 0, "unreadable:" + type(e).__name__, "info", decision))
        return "error"
    home = win = 0
    pc = {}
    for i, line in enumerate(text.splitlines(), 1):
        if len(line) > 20000:
            line = line[:20000]
        for kind, sev, rx in PATTERNS:
            if kind == "telegram-api-ref":
                continue                       # counted per file below
            m = rx.search(line)
            if not m:
                continue
            if kind == "secret-assignment":
                v = m.group(1)
                if re.search(r"[<>{}$]|xxx|\.\.\.|example|placeholder|changeme|REDACTED|os\.environ|getenv|_FILE|path", v, re.I):
                    continue
            hits.append((pub, i, kind, sev, decision))
        if KEYWORD_LINE.search(line) and HEX64_RE.search(line):
            hits.append((pub, i, "hex64-near-key-keyword", "high", decision))
        elif HEX64_0X.search(line) and not HASHY_LINE.search(line):
            hits.append((pub, i, "0x-hex64-unlabelled", "medium", decision))
        if bip39_run(line):
            hits.append((pub, i, "bip39-12-word-run", "high", decision))
        for m in EMAIL_RE.finditer(line):
            e = m.group(0).lower()
            if e.endswith("@anthropic.com") and e.startswith("noreply"):
                k = "email-noreply-attribution"
            elif e.startswith("victorrielly@"):
                k = "email-owner"
            elif re.search(r"@(example\.(com|org)|localhost|test)\b", e) or e.endswith((".rs", ".py", ".json", ".md")):
                continue
            elif re.search(r"\.(png|jpg|svg)$", e) or "@" in e and e.split("@")[0] in ("git", "u"):
                continue
            else:
                k = "email-other"
            hits.append((pub, i, k, "low", decision))
        if PHONE_RE.search(line) and not re.search(r"\d{4}-\d{2}-\d{2}|sha|0x|\bv\d", line):
            hits.append((pub, i, "phone-like-number", "low", decision))
        for m in IPV4_RE.finditer(line):
            r = public_ip(m)
            if r is True:
                hits.append((pub, i, "public-ipv4-like", "low", decision))
                break
            if r == "cgnat":
                hits.append((pub, i, "cgnat-or-tailscale-ipv4", "low", decision))
                break
        home += len(HOME_RE.findall(line))
        win += len(WINUSER_RE.findall(line))
        for cat, rx in PERSONAL.items():
            n = len(rx.findall(line))
            if n:
                pc[cat] = pc.get(cat, 0) + n
    if home or win:
        abs_counts.append((pub, home, win, decision))
    if pc:
        personal_counts.append((pub, decision, pc))
    return "text"


def main():
    t0 = time.time()
    files = {}          # public path -> record
    for pub_prefix, src, group, overlay, note in SPEC:
        if not os.path.isdir(os.path.join(ROOT, src)):
            print("missing", src, file=sys.stderr)
            continue
        for rel, absp in walk(src):
            pub = pub_prefix + "/" + rel
            if overlay and pub in files:
                continue
            if os.path.islink(absp):
                files[pub] = dict(pub=pub, src=os.path.relpath(absp, ROOT), group=group, bytes=0,
                                  decision="exclude", note="symlink -> " + os.readlink(absp), sha256="")
                continue
            dec, why = decide(group, pub, absp)
            files[pub] = dict(pub=pub, src=os.path.relpath(absp, ROOT), group=group,
                              bytes=os.path.getsize(absp), decision=dec, note=why or note, sha256="")
    for pub_prefix, src in LANE_TOOLS:
        base = os.path.join(ROOT, src)
        if not os.path.isdir(base):
            print("missing", src, file=sys.stderr)
            continue
        for f in sorted(os.listdir(base)):
            absp = os.path.join(base, f)
            if f.endswith(".py") and os.path.isfile(absp) and not os.path.islink(absp):
                pub = pub_prefix + "/" + f
                files[pub] = dict(pub=pub, src=os.path.relpath(absp, ROOT), group="model-export-tools",
                                  bytes=os.path.getsize(absp), decision="review",
                                  note="lift from lane results; parametrise hard-coded paths", sha256="")
    for name, group, note in ROOT_FILES:
        absp = os.path.join(ROOT, name)
        files[name] = dict(pub=name, src=name, group=group, bytes=os.path.getsize(absp),
                           decision="redact" if name == "README.md" else "include", note=note, sha256="")
    for rel in EVIDENCE:
        absp = os.path.join(ROOT, rel)
        if not os.path.isfile(absp):
            print("missing evidence", rel, file=sys.stderr)
            continue
        pub = "evidence/" + rel[len("results/"):]
        files[pub] = dict(pub=pub, src=rel, group="evidence", bytes=os.path.getsize(absp),
                          decision="include", note="curated evidence (read before publishing)", sha256="")

    hits, abs_counts, personal_counts, kinds = [], [], [], {}
    names_flagged = []
    for pub in sorted(files):
        r = files[pub]
        if r["note"].startswith("symlink"):
            continue
        absp = os.path.join(ROOT, r["src"])
        r["sha256"] = sha256(absp)
        r["content"] = scan_file(pub, absp, r["decision"], hits, abs_counts, personal_counts)
        if SENSITIVE_NAME.search(os.path.basename(pub)):
            names_flagged.append(dict(pub=pub, decision=r["decision"]))
    # per-file telegram refs are folded into personal_keyword_counts (category telegram)

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "candidate_files.tsv"), "w") as f:
        f.write("public_path\tbytes\tsha256\tdecision\tgroup\tcontent\tsource_path\tnote\n")
        for pub in sorted(files):
            r = files[pub]
            f.write("\t".join([pub, str(r["bytes"]), r["sha256"], r["decision"], r["group"],
                               r.get("content", ""), r["src"], r["note"]]) + "\n")
    with open(os.path.join(OUT, "secret_scan_hits.tsv"), "w") as f:
        f.write("public_path\tline\tkind\tseverity\tfile_decision\n")
        for h in hits:
            f.write("\t".join(str(x) for x in h) + "\n")
    with open(os.path.join(OUT, "abs_path_counts.tsv"), "w") as f:
        f.write("public_path\thome_victor_paths\twindows_user_paths\tfile_decision\n")
        for a in sorted(abs_counts):
            f.write("\t".join(str(x) for x in a) + "\n")
    with open(os.path.join(OUT, "personal_keyword_counts.tsv"), "w") as f:
        cats = list(PERSONAL)
        f.write("public_path\tfile_decision\t" + "\t".join(cats) + "\n")
        for pub, dec, pc in sorted(personal_counts):
            f.write("\t".join([pub, dec] + [str(pc.get(c, 0)) for c in cats]) + "\n")

    def agg(keyf):
        out = {}
        for r in files.values():
            k = keyf(r)
            o = out.setdefault(k, {"files": 0, "bytes": 0})
            o["files"] += 1
            o["bytes"] += r["bytes"]
        return dict(sorted(out.items()))

    pubset = [r for r in files.values() if r["decision"] != "exclude"]
    summary = {
        "generated_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "generator": "results/zk60_open_release_20261030/build_inventory.py",
        "reference_prover": {
            "tree": R16B, "source_tree": "ops/zkp-mvp/token-io-r19b",
            "manifest": "results/zk60_token_io_r1_20261017/manifest_final_r19b.sha256 (306 files, list cfae2d1e)",
            "binary": "results/zk60_token_io_r1_20261017/cli/zk60_classify.r19b.release.bin",
            "binary_sha256_prefix": "6d65d32e",
            "status": "frozen 2026-10-30T15:03:30Z; REVIEW_R19B: ACCEPTED WITH FIXES (all low); carries E7 (ZK60_MODELS)",
        },
        "privacy_gate_reference": GATE,
        "totals_all_listed": {"files": len(files), "bytes": sum(r["bytes"] for r in files.values())},
        "totals_publishable": {"files": len(pubset), "bytes": sum(r["bytes"] for r in pubset),
                               "note": "include + redact + review (exclude left out)"},
        "by_decision": agg(lambda r: r["decision"]),
        "by_group": agg(lambda r: r["group"]),
        "by_group_publishable": {k: v for k, v in agg(lambda r: r["group"] if r["decision"] != "exclude" else "_excluded").items()},
        "largest_publishable": sorted(({"pub": r["pub"], "bytes": r["bytes"]} for r in pubset),
                                      key=lambda x: -x["bytes"])[:25],
        "binary_files_publishable": sorted(r["pub"] for r in pubset if r.get("content") == "binary"),
        "spec": [dict(public=p, source=s, group=g, overlay=o, note=n) for p, s, g, o, n in SPEC],
        "evidence": EVIDENCE,
        "doc_exclude": DOC_EXCLUDE, "doc_redact": DOC_REDACT, "doc_exclude_dirs": DOC_EXCLUDE_DIRS,
        "pruned_dir_names": sorted(PRUNE_DIRS) + ["target-*", "target_*"],
        "elapsed_s": round(time.time() - t0, 1),
    }
    with open(os.path.join(OUT, "candidate_summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    for h in hits:
        k = (h[2], h[3])
        kinds.setdefault(k, {"hits": 0, "files": set(), "in_publishable_files": 0})
        kinds[k]["hits"] += 1
        kinds[k]["files"].add(h[0])
        if h[4] != "exclude":
            kinds[k]["in_publishable_files"] += 1
    ss = {
        "generated_utc": summary["generated_utc"],
        "redaction": "no matched value is written anywhere; file:line and kind only",
        "files_scanned": len(files), "bip39_wordlist_loaded": len(BIPWORDS),
        "by_kind": {f"{k[1]}:{k[0]}": {"hits": v["hits"], "files": len(v["files"]),
                                        "hits_in_publishable_files": v["in_publishable_files"]}
                    for k, v in sorted(kinds.items(), key=lambda kv: kv[0][1])},
        "abs_path_files": len(abs_counts),
        "abs_path_home_total": sum(a[1] for a in abs_counts),
        "abs_path_windows_total": sum(a[2] for a in abs_counts),
        "personal_keyword_files": len(personal_counts),
        "patterns": {k: rx.pattern for k, _, rx in PATTERNS},
        "line_rules": {
            "hex64-near-key-keyword": "64 hex digits on a line that also names a private key / secret / mnemonic / seed",
            "0x-hex64-unlabelled": "0x + 64 hex on a line with no hash / root / tx / receipt / identity word",
            "bip39-12-word-run": "12+ consecutive words from the BIP-39 English list",
            "email-*": EMAIL_RE.pattern, "phone-like-number": PHONE_RE.pattern,
            "public-ipv4-like": "dotted quad outside private / loopback / CGNAT ranges",
        },
        "method": "every candidate file read once; binaries (NUL in the first 8 KiB) checked only for a PEM "
                  "private-key header and ELF magic; text over 16 MiB not scanned (listed)",
    }
    with open(os.path.join(OUT, "secret_scan_summary.json"), "w") as f:
        json.dump(ss, f, indent=1)

    # names only, around the candidate tree (never opened)
    around = {}
    tp = os.path.join(ROOT, "apps/proven-media/.testnet-private")
    if os.path.isdir(tp):
        around["apps/proven-media/.testnet-private"] = sorted(
            os.path.relpath(os.path.join(d, x), tp) for d, ds, fs in os.walk(tp) for x in fs)[:200]
    op = os.path.expanduser("~/zk60-owner-private")
    around["~/zk60-owner-private"] = {"exists": os.path.isdir(op),
                                      "entries": len(os.listdir(op)) if os.path.isdir(op) else 0,
                                      "inside_candidate_tree": False}
    deep = []
    for top in ("results", "ops", "research", "local-models"):
        base = os.path.join(ROOT, top)
        for d, ds, fs in os.walk(base):
            depth = os.path.relpath(d, base).count(os.sep)
            ds[:] = [x for x in ds if x not in PRUNE_DIRS and not x.startswith("target")] if depth < 5 else []
            for x in fs + ds:
                if SENSITIVE_NAME.search(x):
                    deep.append(os.path.relpath(os.path.join(d, x), ROOT))
    with open(os.path.join(OUT, "name_flags.json"), "w") as f:
        json.dump({"generated_utc": summary["generated_utc"],
                   "sensitive_names_in_candidate_tree": names_flagged,
                   "around_candidate_tree": around,
                   "sensitive_names_outside_candidate_depth5": {"count": len(deep), "paths": sorted(deep)[:400]},
                   "rule": SENSITIVE_NAME.pattern}, f, indent=1)
    print(json.dumps({"files": len(files), "publishable": summary["totals_publishable"],
                      "hits": len(hits), "elapsed_s": round(time.time() - t0, 1)}))


def scan_tree(tree, out_tsv):
    """Re-scan a built public snapshot (any directory) with the same redacted rules."""
    hits, abs_counts, personal_counts, n = [], [], [], 0
    for d, ds, fs in os.walk(tree):
        ds[:] = sorted(x for x in ds if x != ".git")
        for f in sorted(fs):
            p = os.path.join(d, f)
            if os.path.islink(p) or not os.path.isfile(p):
                hits.append((os.path.relpath(p, tree), 0, "symlink-or-special", "high", "snapshot"))
                continue
            rel = os.path.relpath(p, tree)
            scan_file(rel, p, "snapshot", hits, abs_counts, personal_counts)
            if SENSITIVE_NAME.search(f):
                hits.append((rel, 0, "sensitive-file-name", "high", "snapshot"))
            n += 1
    with open(out_tsv, "w") as fo:
        fo.write("path\tline\tkind\tseverity\tscope\n")
        for h in hits:
            fo.write("\t".join(str(x) for x in h) + "\n")
    sev = {}
    for h in hits:
        sev[h[3]] = sev.get(h[3], 0) + 1
    print(json.dumps({"files": n, "hits_by_severity": sev, "abs_path_files": len(abs_counts),
                      "out": out_tsv}))


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "--scan-tree":
        scan_tree(sys.argv[2], sys.argv[3])     # --scan-tree <snapshot dir> <hits.tsv>
    else:
        main()
