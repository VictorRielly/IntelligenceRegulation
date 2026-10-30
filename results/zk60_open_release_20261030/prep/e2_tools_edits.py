#!/usr/bin/env python3
"""E2, model-export tools: parametrise the lifted lane tools of a staging tree.

Rules (see prep/E2_NOTES.md):
  * CODE = the tool's own directory, tools/model-export/<group>/ (sources, sibling imports,
    the digests a tool records of its own sources).
  * HERE = the group's ORIGINAL lane folder, $ZK60_REPO/results/<lane>/ (all data: inputs,
    runs, exports, generated vendor copies). ZK60_REPO defaults to this checkout.
  * $ZK60_MODELS (default ~/models) replaces /home/victor/models; user-site appends use ~.
  With ZK60_REPO=/home/victor/IntelligenceRegulation and ZK60_MODELS=/home/victor/models every
  data path a tool reads or writes is the path it used before.
  * tlcalib.py / b3_ladder.py are also the INPUT of shieldstral-export/vendor_port.py, which
    rewrites fixed regions of their text: tlcalib edits stay inside [first 'HERE = ', 'TWO53 = ')
    and b3_ladder edits stay inside main(), so the vendored copies come out byte-identical.

Every replacement asserts its match count; a mismatch stops the script.
Usage: python3 -I e2_tools_edits.py <staging root>
"""
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
M = ROOT / "tools/model-export"
LANES = {
    "shieldstral-export": "results/zk60_shieldstral_export_20261026",
    "shieldstral-prep": "results/zk60_shieldstral_prep_20261021",
    "llama3-8b-calibration": "results/zk60_8b_calibration_20261017",
    "tinyllama-1b-calibration": "results/zk60_1b_calibration_20260929",
    "tinyllama-1b-model": "results/zk60_1b_model_20260927",
}
HERE_LINE = re.compile(r"^HERE(\s*)=(\s*)Path\(__file__\)\.resolve\(\)\.parent[ \t]*$", re.M)
CODE_PY = re.compile(r"HERE(\s*)/(\s*)(['\"])([A-Za-z0-9_]+\.py)\3")
changed = {}


def rd(rel):
    return changed.get(rel) if rel in changed else (M / rel).read_text()


def rep(rel, old, new, n=1):
    s = rd(rel)
    c = s.count(old)
    if c != n:
        sys.exit(f"{rel}: expected {n} x {old[:70]!r}, found {c}")
    changed[rel] = s.replace(old, new)


def ensure_os(rel):
    s = rd(rel)
    if re.search(r"^import os\b", s, re.M):
        return
    m = re.search(r"^from pathlib import Path.*$", s, re.M) or re.search(r"^import \w+.*$", s, re.M)
    changed[rel] = s[:m.start()] + "import os\n" + s[m.start():]


def generic(group):
    lane = LANES[group]
    for p in sorted((M / group).glob("*.py")):
        rel = f"{group}/{p.name}"
        s = rd(rel)
        if group == "tinyllama-1b-calibration" and p.name == "tlcalib.py":
            continue  # special-cased (vendor_port region rule)
        m = HERE_LINE.search(s)
        if not m:
            continue
        a, b = m.group(1), m.group(2)
        new = (f"CODE{a}={b}Path(__file__).resolve().parent  # this tool's code: tools/model-export/{group}/\n"
               f"# data: the group's original lane folder under $ZK60_REPO (default: this checkout)\n"
               f"HERE{a}={b}Path(os.environ.get('ZK60_REPO') or CODE.parents[2]) / '{lane}'")
        s = s[:m.start()] + new + s[m.end():]
        s = CODE_PY.sub(lambda k: f"CODE{k.group(1)}/{k.group(2)}{k.group(3)}{k.group(4)}{k.group(3)}", s)
        s = s.replace("sys.path.insert(0, str(HERE))", "sys.path.insert(0, str(CODE))")
        changed[rel] = s
        ensure_os(rel)


# ------------------------------------------------------------------ shieldstral-export
generic("shieldstral-export")
SE = "shieldstral-export"
KEY = "(p.name if p.parent == CODE else str(p.relative_to(HERE)))"
rep(f"{SE}/build_export.py", "'source':{str(p.relative_to(HERE)):sha(p) for p in sources}",
    "'source':{" + KEY + ":sha(p) for p in sources}")
rep(f"{SE}/build_export.py", "'calibration_tool':{'path':str(Path(__file__).relative_to(HERE.parents[1]))",
    "'calibration_tool':{'path':str((HERE/Path(__file__).name).relative_to(HERE.parents[1]))")
rep(f"{SE}/collect_stats.py", "signature={'source':{str(p.relative_to(HERE)):sha(p) for p in files}",
    "signature={'source':{" + KEY + ":sha(p) for p in files}")
rep(f"{SE}/evaluation_export.py", "    return {str(p.relative_to(HERE)):sha(p) for p in files}",
    "    return {" + KEY + ":sha(p) for p in files}")
SP = "CODE.parent/'shieldstral-prep'"
for f in ("prepare_evaluation.py", "prepare_calibration.py"):
    rep(f"{SE}/{f}", "sys.path.insert(0,str(PREP/'tools'))", f"sys.path.insert(0,str({SP}))")
rep(f"{SE}/prepare_category_policies.py", "sys.path.insert(0, str(PREP / 'tools'))",
    "sys.path.insert(0, str(CODE.parent / 'shieldstral-prep'))")
rep(f"{SE}/prepare_category_policies.py", "sha(PREP / 'tools/shieldstral_common.py')",
    "sha(CODE.parent / 'shieldstral-prep/shieldstral_common.py')")
rep(f"{SE}/build_token_io.py", "sys.path.insert(0,str(prep/'tools'))", f"sys.path.insert(0,str({SP}))")
rep(f"{SE}/build_token_io_r12b.py", "sys.path.insert(0, str(prep / 'tools'))",
    "sys.path.insert(0, str(CODE.parent / 'shieldstral-prep'))")
rep(f"{SE}/write_item_activations.py", "sys.path.insert(0, str(ROOT / 'apps/proven-media'))",
    "sys.path.insert(0, str(CODE.parents[2] / 'apps/proven-media'))  # the app's code, in this checkout")
rep(f"{SE}/shieldstral_weights.py", "SNAPSHOT = Path('/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2')",
    "SNAPSHOT = Path(os.environ.get('ZK60_MODELS') or Path.home() / 'models') / 'shieldstral-1.0-3b/snapshot-003ec7e2'")
rep(f"{SE}/test_geometry.py", "ROOT = Path(__file__).resolve().parents[2]",
    "ROOT = Path(os.environ.get('ZK60_REPO') or Path(__file__).resolve().parents[3])")
ensure_os(f"{SE}/test_geometry.py")
# smoke_checkpoint.py has no HERE: data from the lane, the prep reference from its lifted code dir
rep(f"{SE}/smoke_checkpoint.py", "from shieldstral_geometry import MODEL, TIED, Rotation\n",
    "from shieldstral_geometry import MODEL, TIED, Rotation\n\n"
    "CODE = Path(__file__).resolve().parent  # this tool's code: tools/model-export/shieldstral-export/\n"
    "# data: the group's original lane folder under $ZK60_REPO (default: this checkout)\n"
    "HERE = Path(os.environ.get('ZK60_REPO') or CODE.parents[2]) / 'results/zk60_shieldstral_export_20261026'\n")
ensure_os(f"{SE}/smoke_checkpoint.py")
rep(f"{SE}/smoke_checkpoint.py", "np.load(Path(__file__).parent/'calibration_t256/ids.npy')", "np.load(HERE/'calibration_t256/ids.npy')")
rep(f"{SE}/smoke_checkpoint.py", "prep=Path(__file__).resolve().parent.parent/'zk60_shieldstral_prep_20261021/tools'",
    "prep=CODE.parent/'shieldstral-prep'")
# vendor_port.py: the TinyLlama calibration SOURCES are code (tools/model-export/tinyllama-1b-calibration);
# what it records keeps the lane-relative names the original run recorded.
rep(f"{SE}/vendor_port.py", "CAL = ROOT/'results/zk60_1b_calibration_20260929'\n",
    "CAL = CODE.parent/'tinyllama-1b-calibration'  # code (was ROOT/'results/zk60_1b_calibration_20260929')\n")
rep(f"{SE}/vendor_port.py", "FP = ROOT/'results/zk60_fidelity_parity_20261019'\n",
    "FP = ROOT/'results/zk60_fidelity_parity_20261019'  # fp_lib.py: not in the public tree yet\n\n\n"
    "def lane_name(p):\n"
    "    \"\"\"the source's name as the original run recorded it (repo-relative lane path)\"\"\"\n"
    "    return f'results/zk60_1b_calibration_20260929/{p.name}' if p.parent == CAL else str(p.relative_to(ROOT))\n")
rep(f"{SE}/vendor_port.py", "fromfile=str(source.relative_to(ROOT))", "fromfile=lane_name(source)")
rep(f"{SE}/vendor_port.py", "manifest[source.name] = {'source': str(source.relative_to(ROOT)),",
    "manifest[source.name] = {'source': lane_name(source),")

# ------------------------------------------------------------------ shieldstral-prep
generic("shieldstral-prep")
SPG = "shieldstral-prep"
LANE_EXPR = ('os.path.join(os.environ.get("ZK60_REPO") or os.path.abspath(os.path.join(os.path.dirname('
             'os.path.abspath(__file__)), "..", "..", "..")), "results", "zk60_shieldstral_prep_20261021")')
for f in ("shieldstral_common.py", "analyze_categories.py", "analyze.py", "record_pins.py"):
    rep(f"{SPG}/{f}", 'LANE = "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021"',
        "# the lane's data folder under $ZK60_REPO (default: this checkout)\nLANE = " + LANE_EXPR)
rep(f"{SPG}/shieldstral_common.py", 'MODEL_DIR = f"{HOME}/models/shieldstral-1.0-3b"',
    'MODEL_DIR = os.path.join(os.environ.get("ZK60_MODELS") or f"{HOME}/models", "shieldstral-1.0-3b")')
for f in ("hf_check.py", "make_prompts.py", "shieldstral_ref.py", "bench_run.py", "ref_check.py",
          "length_stats.py", "check_template.py"):
    rep(f"{SPG}/{f}", 'sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")',
        "sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))  # sibling modules (this directory)")
    ensure_os(f"{SPG}/{f}")
for f in ("analyze_categories.py", "analyze.py", "compare.py"):
    rep(f"{SPG}/{f}", 'sys.path.append("/home/victor/.local/lib/python3.10/site-packages")',
        'sys.path.append(os.path.expanduser("~/.local/lib/python3.10/site-packages"))')
    ensure_os(f"{SPG}/{f}")
rep(f"{SPG}/report_categories.py", "LANE=Path(__file__).resolve().parents[1]",
    "LANE=Path(os.environ.get('ZK60_REPO') or Path(__file__).resolve().parents[3])/'results/zk60_shieldstral_prep_20261021'")
ensure_os(f"{SPG}/report_categories.py")

# ------------------------------------------------------------------ tinyllama-1b-calibration
TL = "tinyllama-1b-calibration"
rep(f"{TL}/tlcalib.py",
    'HERE = Path(__file__).resolve().parent\nREPO = HERE.parents[1]\n',
    "HERE = Path(os.environ.get(\"ZK60_REPO\") or Path(__file__).resolve().parents[3]) / \"results\" / \"zk60_1b_calibration_20260929\"\n"
    "# HERE: this lane's data folder under $ZK60_REPO (default: this checkout); CODE: this file's directory\n"
    "CODE = Path(__file__).resolve().parent\n"
    "REPO = HERE.parents[1]\n")
rep(f"{TL}/tlcalib.py", 'MODEL_DIR = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1")',
    'MODEL_DIR = Path(os.environ.get("ZK60_MODELS") or Path.home() / "models") / "tinyllama-1.1b-chat-fe8a4ea1"')
generic(TL)
rep(f"{TL}/b3_ladder.py", "tool_sha_at_start = {p: sha_file(HERE / p) for p in",
    "tool_sha_at_start = {p: sha_file(tc.CODE / p) for p in")
rep(f"{TL}/corpus4.py", 'PARQUET = Path("/home/victor/models/fineweb-edu/sample/10BT/000_00000.parquet")',
    'MODELS = Path(os.environ.get("ZK60_MODELS") or Path.home() / "models")\n'
    'PARQUET = MODELS / "fineweb-edu/sample/10BT/000_00000.parquet"')
rep(f"{TL}/corpus4.py", 'Source on this box: /home/victor/models/fineweb-edu/sample/10BT/000_00000.parquet',
    'Source: $ZK60_MODELS/fineweb-edu/sample/10BT/000_00000.parquet (default ~/models)')
ensure_os(f"{TL}/corpus4.py")

# ------------------------------------------------------------------ llama3-8b-calibration
L8 = "llama3-8b-calibration"
generic(L8)
rep(f"{L8}/b5_8b.py", 'LANE1B = Path("/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929")',
    'LANE1B = Path(__file__).resolve().parents[1] / "tinyllama-1b-calibration"  # the B3/B4 code it reuses')
rep(f"{L8}/b5_bos.py", 'sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929")',
    'sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tinyllama-1b-calibration"))')
rep(f"{L8}/b5_bos.py", 'Path(__file__).resolve().parent.joinpath("runs", "b5_bos_massive.json")',
    '(Path(os.environ.get("ZK60_REPO") or Path(__file__).resolve().parents[3]) / "results/zk60_8b_calibration_20261017").joinpath("runs", "b5_bos_massive.json")')

# ------------------------------------------------------------------ tinyllama-1b-model
generic("tinyllama-1b-model")

for rel, s in sorted(changed.items()):
    (M / rel).write_text(s)
print(len(changed), "files edited")
for rel in sorted(changed):
    print(" ", rel)
