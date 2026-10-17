"""Re-run the speed plan's projection (this directory's copy of projection.py,
changed only so G0 can be overridden) with REFIT coefficients.

usage: python3 -B run_projection_refit.py <refit json> <coefficient key> <tag>
  e.g. refit.json coefficients_cpu onebl  /  refit_stack.json coefficients_cpu stack
Writes projection_<tag>.json and projection_output_<tag>.txt here.
"""
import contextlib
import io
import json
import os
import runpy
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import cost_model as cm  # noqa: E402


def main():
    src, key, tag = sys.argv[1], sys.argv[2], sys.argv[3]
    r = json.load(open(os.path.join(HERE, src)))
    c_cpu = r[key]
    gpu = r.get("gpu") or {}
    orig = cm.coefficients

    def patched(mode, f0=cm.F0_SLOT):
        if mode == "cpu":
            return dict(c_cpu)
        c = dict(orig("gpu", f0))
        if gpu.get("commit_ns"):
            c["commit"] = gpu["commit_ns"] * 1e-9
        return c

    cm.coefficients = patched
    if gpu.get("g0_s") is not None:
        os.environ["REFIT_G0"] = str(gpu["g0_s"])
    if r.get("load_per_layer_s") is not None:
        os.environ["REFIT_LOAD"] = str(r["load_per_layer_s"])
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        runpy.run_path(os.path.join(HERE, "projection.py"), run_name="__main__")
    text = buf.getvalue()
    hdr = f"[REFIT '{tag}': CPU coefficients from {src}:{key}; GPU commit {gpu.get('commit_ns', 'plan 5.06')} ns, G0 {gpu.get('g0_s', 'plan 0.305')} s; load per layer per pass {r.get('load_per_layer_s', 'plan 2.5')} s]\n"
    open(os.path.join(HERE, f"projection_output_{tag}.txt"), "w").write(hdr + text)
    os.replace(os.path.join(HERE, "projection.json"), os.path.join(HERE, f"projection_{tag}.json"))
    print(hdr + text)


if __name__ == "__main__":
    main()
