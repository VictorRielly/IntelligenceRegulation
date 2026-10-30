#!/usr/bin/env python3
"""E2, scripts/ and tests/: parametrise owner-box paths in a staging tree.

ZK60_REPO -> the checkout (scripts already use Path(__file__).parents[1]); ZK60_MODELS
(default ~/models); CUDA_ROOT (default ~/cuda-root, the development box's location); old lane
worktrees (/home/victor/wt-*) -> the checkout. On the development box (HOME=/home/victor) the
defaults equal the old literals. NOT edited (byte-pinned records, see E2_NOTES.md):
scripts/zk60_opus_attention_inventory.py (sha dd0b8cde cited by ZK60_OPUS_ATTENTION_INVENTORY.md;
its 'worktree' field is an output record).
Usage: python3 -I e2_scripts_edits.py <staging root>
"""
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
changed = {}


def rep(rel, old, new, n=1):
    s = changed.get(rel) or (ROOT / rel).read_text()
    c = s.count(old)
    if c != n:
        sys.exit(f"{rel}: expected {n} x {old[:70]!r}, found {c}")
    changed[rel] = s.replace(old, new)


S = "scripts/"
# docstring usage examples
rep(S + "m8b_int8_calibration.py", "--ckpt /home/victor/models/125m-best-adamw-val3.0816 \\\n      --tokens /home/victor/shard-00000.npy",
    "--ckpt ~/models/125m-best-adamw-val3.0816 \\\n      --tokens ~/shard-00000.npy")
rep(S + "m8b_export_ffn.py", "--ckpt /home/victor/models/125m-best-adamw-val3.0816/model.safetensors", "--ckpt ~/models/125m-best-adamw-val3.0816/model.safetensors")
rep(S + "m8b_export_ffn.py", "--tokens /home/victor/shard-00000.npy", "--tokens ~/shard-00000.npy")
rep(S + "m8b_export_ffn.py", "--ckpt /home/victor/models/Mistral-7B-v0.1", "--ckpt ~/models/Mistral-7B-v0.1")
rep(S + "m125_int8_calibration.py", "/home/victor/models/...", "~/models/...")
# code defaults (environment overrides kept)
for f in ("m125_attn_gate.py", "m8b_verify_125m.py"):
    rep(S + f, '"/home/victor/models/125m-best-adamw-val3.0816/model.safetensors"))',
        'str(Path(os.environ.get("ZK60_MODELS") or Path.home() / "models") / "125m-best-adamw-val3.0816/model.safetensors")))')
rep(S + "m125_attn_gate.py", '"/home/victor/shard-00000.npy"))', 'str(Path.home() / "shard-00000.npy")))')
rep(S + "m8b_verify_125m.py", '"/home/victor/shard-00000.npy"))', 'str(Path.home() / "shard-00000.npy")))')
rep(S + "m8b_smooth_experiment.py", 'DEF_CKPT = "/home/victor/models/Mistral-7B-v0.1"\nDEF_TEXT = "/home/victor/models/fineweb-edu/sample_text.txt"\n',
    '_MODELS = os.environ.get("ZK60_MODELS") or os.path.expanduser("~/models")\n'
    'DEF_CKPT = os.path.join(_MODELS, "Mistral-7B-v0.1")\nDEF_TEXT = os.path.join(_MODELS, "fineweb-edu/sample_text.txt")\n')
rep(S + "m8b_margins.py", 'Path("/home/victor/IntelligenceRegulation/results/"\n                     "m8b_gemma4_zcol_stats.npz")]',
    'Path(os.environ.get("ZK60_REPO") or ROOT) / "results" / "m8b_gemma4_zcol_stats.npz"]')
# CUDA locations of the development box -> CUDA_ROOT / home-relative
CUDA = 'os.environ.get("CUDA_ROOT") or os.path.expanduser("~/cuda-root")'
NVRTC = 'os.path.expanduser("~/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib")'
rep(S + "hashline_cl_5090_preflight.py", 'parser.add_argument("--cuda-root", default="/home/victor/cuda-root")',
    f'parser.add_argument("--cuda-root", default={CUDA})')
rep(S + "zk60_private_stack_benchmark.py",
    'LD = "/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib"',
    f'CUDA_ROOT = {CUDA}\nLD = ":".join([CUDA_ROOT + "/lib64", {NVRTC}, "/usr/lib/wsl/lib"])')
rep(S + "zk60_private_stack_benchmark.py", 'env.update(CUDA_ROOT="/home/victor/cuda-root", LD_LIBRARY_PATH=LD,',
    'env.update(CUDA_ROOT=CUDA_ROOT, LD_LIBRARY_PATH=LD,')
rep(S + "zk60_mvp_device_gate.py",
    'ENV.update(CUDA_ROOT="/home/victor/cuda-root", RAYON_NUM_THREADS="2", HL_GPU="1", HL_GPU_REQUIRED="1",\n'
    '           HL_GPU_CHUNK_ROWS="128", LD_LIBRARY_PATH="/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib")',
    f'CUDA_ROOT = {CUDA}\n'
    'ENV.update(CUDA_ROOT=CUDA_ROOT, RAYON_NUM_THREADS="2", HL_GPU="1", HL_GPU_REQUIRED="1",\n'
    f'           HL_GPU_CHUNK_ROWS="128", LD_LIBRARY_PATH=":".join([CUDA_ROOT + "/lib64", {NVRTC}, "/usr/lib/wsl/lib"]))')
# old lane worktrees -> this checkout
rep(S + "zk60_attention_native_inventory.py", '--repo /home/victor/wt-zk60-attention-compile', '--repo <checkout>')
rep(S + "zk60_attention_native_inventory.py", 'ap.add_argument("--repo", default="/home/victor/wt-zk60-attention-compile")',
    'ap.add_argument("--repo", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # first run: the lane worktree wt-zk60-attention-compile')
rep(S + "zk60_private_block_inventory.py", '--repo /home/victor/wt-zk60-private-block', '--repo <checkout>')
rep(S + "zk60_private_block_inventory.py", 'DEFAULT_REPO = "/home/victor/wt-zk60-private-block"',
    'DEFAULT_REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # first run: the lane worktree wt-zk60-private-block')
rep(S + "floors_round13_merge.sh", "R=/home/victor/IntelligenceRegulation\n",
    'R=${ZK60_REPO:-$(cd "$(dirname "$0")/.." && pwd)}\n')
rep(S + "floors_round13_merge.sh", "V3=/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export\n",
    "V3=${HL_EXPORT_DIR:-$R/results/m8b_test/m125_v3_export}   # first run: the lane worktree wt-uperf3-aa\n")
rep(S + "floors_round13_merge.sh", "CUDA_LD=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib\n",
    "CUDA_ROOT=${CUDA_ROOT:-$HOME/cuda-root}\nCUDA_LD=$CUDA_ROOT/lib64:$HOME/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib\n")
rep(S + "floors_round13_merge.sh", "CUDA_ROOT=/home/victor/cuda-root LD_LIBRARY_PATH=$CUDA_LD", "CUDA_ROOT=$CUDA_ROOT LD_LIBRARY_PATH=$CUDA_LD")

T = "tests/"
rep(T + "test_zk60_opus_repaired_capture.py", 'Path("/home/victor/IntelligenceRegulation/results/zk60_round16_validation.json")]',
    'Path(os.environ.get("ZK60_REPO") or Path(__file__).resolve().parents[1]) / "results/zk60_round16_validation.json"]')
rep(T + "test_zk60_opus_io_capture.py", 'Path("/home/victor/IntelligenceRegulation/results/zk60_round19_validation.json")]',
    'Path(os.environ.get("ZK60_REPO") or Path(__file__).resolve().parents[1]) / "results/zk60_round19_validation.json"]')
rep(T + "test_zk60_opus_repeated_view.py", '"/home/victor/IntelligenceRegulation/results/zk60_round22_captures"))',
    'os.path.join(os.environ.get("ZK60_REPO") or os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results", "zk60_round22_captures")))')
rep(T + "test_hashline_cl_artifact_profile.py", '"/home/victor/wt-uperf3-am/results/am_r2_mistral.log")',
    'os.path.join(os.environ.get("ZK60_REPO") or os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "results", "am_r2_mistral.log"))')
rep(T + "test_hashline_cl_artifact_profile.py", '_MAIN = os.environ.get("HL_MAIN_CHECKOUT", "/home/victor/IntelligenceRegulation")',
    '_MAIN = os.environ.get("HL_MAIN_CHECKOUT") or os.environ.get("ZK60_REPO") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))')
rep(T + "test_hashline_cl_5090_preflight.py", 'self.assertNotIn("/home/victor/wt-zk60-cl1", text)', 'self.assertNotIn("wt-zk60-cl1", text)')
rep(T + "test_hashline_cl_gpu_gates.py", 'for needle in ("/home/victor/wt-zk60-cl1/hashline", "/home/victor/wt-zk60-cl1/results"):',
    'for needle in ("wt-zk60-cl1/hashline", "wt-zk60-cl1/results"):')
rep(T + "test_zk60_private_block_inventory.py", "-s /home/victor/wt-zk60-private-block/tests", "-s tests")

import re
for rel in (S + "m8b_smooth_experiment.py", S + "m8b_margins.py"):
    t = changed[rel]
    if not re.search(r"^import os\b", t, re.M):
        m = re.search(r"^from pathlib import Path.*$", t, re.M)
        changed[rel] = t[:m.start()] + "import os\n" + t[m.start():]

for rel, s in sorted(changed.items()):
    (ROOT / rel).write_text(s)
print(len(changed), "files edited:", *sorted(changed), sep="\n  ")
