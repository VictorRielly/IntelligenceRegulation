#!/usr/bin/env python3
"""E2, proven-media app: parametrise the owner-box paths of a staging tree.

ZK60_REPO (default: this checkout), ZK60_MODELS (default ~/models), ZK60_ARTIFACTS
(default ~/zk60-artifacts). PM_PRIVATE_DIR / PM_PUBLIC_DIR keep precedence. With the
variables at the old locations (or unset on the development box, whose HOME is the old
home) every path equals the old one. Exact replacements with asserted counts.
Usage: python3 -I e2_app_edits.py <staging root>
"""
import hashlib
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
A = ROOT / "apps/proven-media"
changed = {}


def rep(rel, old, new, n=1):
    s = changed.get(rel) or (A / rel).read_text()
    c = s.count(old)
    if c != n:
        sys.exit(f"{rel}: expected {n} x {old[:70]!r}, found {c}")
    changed[rel] = s.replace(old, new)


C = "proven_media/config.py"
rep(C, 'REPO = Path("/home/victor/IntelligenceRegulation")\n',
    '# ZK60_REPO: the repository root (default: this checkout). Lane result folders are $ZK60_REPO/results/<lane>.\n'
    'REPO = Path(os.environ.get("ZK60_REPO") or Path(__file__).resolve().parents[3])\n')
rep(C, 'HOME = Path(os.environ.get("HOME", "/home/victor"))\n',
    'HOME = Path.home()\n'
    '# ZK60_ARTIFACTS: large outputs kept outside any git work tree; ZK60_MODELS: model checkpoints\n'
    'ARTIFACTS = Path(os.environ.get("ZK60_ARTIFACTS") or HOME / "zk60-artifacts")\n'
    'MODELS = Path(os.environ.get("ZK60_MODELS") or HOME / "models")\n')
rep(C, 'PUBLIC_DIR = Path(os.environ.get("PM_PUBLIC_DIR", str(HOME / "zk60-artifacts" / "proven-media")))',
    'PUBLIC_DIR = Path(os.environ.get("PM_PUBLIC_DIR", str(ARTIFACTS / "proven-media")))')
rep(C, 'TINYLLAMA_TOKENIZER = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/tokenizer.model")',
    'TINYLLAMA_TOKENIZER = MODELS / "tinyllama-1.1b-chat-fe8a4ea1" / "tokenizer.model"')
rep(C, 'SPM_BPE_DIR = REPO / "results" / "zk60_1b_calibration_20260929"   # spm_bpe.py, imported read-only\n',
    '# spm_bpe.py, imported read-only: the lifted model-export tools of this checkout when present,\n'
    '# else the calibration lane folder that held it before the lift\n'
    'SPM_BPE_DIR = next((d for d in (APP_DIR.parents[1] / "tools" / "model-export" / "tinyllama-1b-calibration",)\n'
    '                    if (d / "spm_bpe.py").is_file()), REPO / "results" / "zk60_1b_calibration_20260929")\n')

R = "proven_media/shieldstral_runtime.py"
writer = (ROOT / "tools/model-export/shieldstral-export/write_item_activations.py").read_bytes()
new_sha = hashlib.sha256(writer).hexdigest()
rep(R, "WRITER = EXPORT_ROOT / 'write_item_activations.py'\n"
       "WRITER_SHA = '8d6ce81b74316ef36a7b5202376f465611436d980e4a46a51aa0f32e474d922d'\n"
       "TEKKEN = Path('/home/victor/models/shieldstral-1.0-3b/tekken.json')\n",
    "# the activation writer: lifted into tools/model-export/ in the public tree (path parametrisation\n"
    "# only), else the lane copy the reviewed r16b demo ran\n"
    "_LIFTED_WRITER = config.APP_DIR.parents[1] / 'tools/model-export/shieldstral-export/write_item_activations.py'\n"
    "WRITER = _LIFTED_WRITER if _LIFTED_WRITER.is_file() else EXPORT_ROOT / 'write_item_activations.py'\n"
    "WRITER_SHA = '8d6ce81b74316ef36a7b5202376f465611436d980e4a46a51aa0f32e474d922d'  # the lane copy\n"
    f"WRITER_SHA_LIFTED = '{new_sha}'\n"
    "TEKKEN = config.MODELS / 'shieldstral-1.0-3b/tekken.json'\n")
rep(R, "    require(records.sha256_file(WRITER) == WRITER_SHA, 'activation writer differs from tested source')",
    "    require(records.sha256_file(WRITER) in (WRITER_SHA, WRITER_SHA_LIFTED), 'activation writer differs from tested source')")

rep("tools/seqgen.py", 'FP = Path("/home/victor/IntelligenceRegulation/results/zk60_fidelity_parity_20261019")',
    'FP = Path(os.environ.get("ZK60_REPO") or Path(__file__).resolve().parents[3]) / "results/zk60_fidelity_parity_20261019"')
rep("tools/compile_anchor.py", "import subprocess\n", "import shutil\nimport subprocess\n")
rep("tools/compile_anchor.py", "ap.add_argument('--npm', default='/home/victor/.nvm/versions/node/v22.22.3/bin/npm')",
    "ap.add_argument('--npm', default=shutil.which('npm') or 'npm')")
for rel in ("serve.py", "tests/test_app.py"):
    s = (A / rel).read_text()
    changed[rel] = s.replace("/home/victor/IntelligenceRegulation/apps/proven-media/", "apps/proven-media/")
    assert changed[rel] != s, rel
T = "tests/test_storage_policy.py"
rep(T, "private=Path('/home/victor/zk60-owner-private/storage-policy-fixture')",
    "private=Path('/home/someone/zk60-owner-private/storage-policy-fixture')")
rep(T, "'/home/victor/../../tmp'", "'/home/someone/../../tmp'")
rep(T, "Path('/home/victor/elsewhere.key')", "Path('/home/someone/elsewhere.key')")
rep(T, "'/home/victor/another-private-root/job'", "'/home/someone/another-private-root/job'")

for rel, s in sorted(changed.items()):
    (A / rel).write_text(s)
print(len(changed), "files;", "lifted writer sha256", new_sha)
