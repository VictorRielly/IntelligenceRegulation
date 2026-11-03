"""fr25 experiment: after `zk60_native_rg_d55nl.load_nl()` (which d55_gate calls
BEFORE it first imports zk60_native_rg_d55hash / _d55ts), which file does the
driver's `import zk60_native_rg_d55hash` load?  ZK60_NL_CHECK_DIR points to a
scratch directory holding byte-identical copies of the two pinned NL files and
one extra module named zk60_native_rg_d55hash.py.  Nothing in the repo is
written."""
import os
import shutil
import sys

SCR = sys.argv[1]
S = "/Users/victorrielly/IntelligenceRegulation/ops/zkp-mvp/gate-tinyllama/staging_v25/scripts"
SRC = "/Users/victorrielly/IntelligenceRegulation/results/zk60_nonlinear_channel_shaped"
d = os.path.join(SCR, "nldir")
os.makedirs(d, exist_ok=True)
for n in ("nl_check.py", "nl_field.py"):
    shutil.copyfile(os.path.join(SRC, n), os.path.join(d, n))
with open(os.path.join(d, "zk60_native_rg_d55hash.py"), "w") as fh:
    fh.write("SHADOW = True\n"
             "def d55_hash(b, controls=True):\n"
             "    return ({'ok': True, 'shadow': True}, {'ok': True, 'shadow': True})\n")
os.environ["ZK60_NL_CHECK_DIR"] = d
sys.path.insert(0, S)
import zk60_native_rg_d55nl as NLX  # noqa: E402
print("zk60_native_rg_d55hash already imported before load_nl:", "zk60_native_rg_d55hash" in sys.modules)
NL, NF, nld = NLX.load_nl()
print("load_nl accepted dir:", nld, "| sys.path[0] now:", sys.path[0])
import zk60_native_rg_d55hash as HSH  # noqa: E402  (the driver's line 983, same process order)
print("HSH loaded from:", HSH.__file__, "| SHADOW:", getattr(HSH, "SHADOW", False))
print("d55_hash() returns:", HSH.d55_hash(None))
import zk60_native_rg_w16 as W  # noqa: E402
print("shadow file listed in the record's tool_sha256 (W.tool_hashes):", "zk60_native_rg_d55hash.py" in W.tool_hashes() and
      W.tool_hashes()["zk60_native_rg_d55hash.py"] != W._sha(HSH.__file__))
