#!/usr/bin/env python3
"""Lane B5: README.md for a Llama-3-8B export (pure file reading).
Usage: b5_export_readme.py <export dir> <run name> <verify report json>"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    root, run, vrep = Path(sys.argv[1]), sys.argv[2], json.loads(Path(sys.argv[3]).read_text())
    prof = json.loads((root / "profile.json").read_text())
    summ = json.loads((HERE / "runs" / run / "summary.json").read_text())
    meta, geo = prof["metadata_out_of_proof"], prof["metadata_out_of_proof"]["geometry"]
    L = len(prof["layers"])
    per = [json.loads((root / f"layer_{l:02d}" / "manifest.json").read_text())["constants"] for l in range(L)]
    d, f, kvw = geo["width"], geo["hidden"], geo["kv_heads"] * geo["head_dim"]
    lines = [
        f"# Llama-3-8B calibrated integer blocks — export `{prof['variant']}`",
        "",
        "**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** Public integer words "
        "(int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) for the native private-block "
        "prover at the Llama-3-8B geometry, plus held-out sequences' exact integer hidden states for bit-exact parity. "
        "Fidelity numbers come from the Python reference of the native relations (`tlcalib.i_block`).",
        "",
        f"Schema `{prof['schema']}`. Model `{prof['model']['repo']}` ({prof['model']['name']}) revision "
        f"`{prof['model']['revision']}`; shard sha256 {json.dumps(prof['model']['shards_sha256'])}. Licence: the repo's "
        "`LICENSE` and `USE_POLICY.md` (Meta Llama 3 Community License + Acceptable Use Policy) are copied here with "
        "`NOTICE` (\"Built with Meta Llama 3\").",
        "",
        f"Geometry: width {d}, FFN {f}, {geo['q_heads']} q / {geo['kv_heads']} kv heads (group {geo['q_heads'] // geo['kv_heads']}), "
        f"head_dim {geo['head_dim']}, {L} layers, RoPE theta {geo['rope_theta']}, RMSNorm eps {geo['rms_norm_eps']}. T = {prof['T']}.",
        "",
        "## What the native lane must take from this export",
        "",
        f"* **RoPE base {geo['rope_theta']}** as this profile's own value (the accepted TinyLlama class pins 10000): every "
        f"`rope_cos/rope_sin` is `rope_tables_generate(T, {geo['head_dim']}, {geo['rope_theta']}, 7)` (tables_attn.rs semantics, "
        "re-implemented in Python; digest in each manifest).",
        f"* **head_dim {geo['head_dim']}**: exp tables are `exp_member(e_s, {geo['head_dim']}, f_e)`; RoPE half-width {geo['head_dim'] // 2}.",
        f"* **norm**: tn 9 (D24 at width {d}); D_max = isqrt(Ceps + {d} * 32768^2) has 22 bits, window 9 + 1 + 22 = 32 (four limbs).",
        "* constants follow the D24 windows (qkv/s/g/z 1..8, o/h 9..16, ao 0..8; Cn <= 2^20; Ceps <= 2^40; per-layer e_s and frozen SiLU member).",
        f"* FFN {f} pads to {1 << (f - 1).bit_length()}; vocabulary 128256 and BOS id 128000 stay outside the block proof.",
        "",
        "## Constants",
        "",
        "Uniform over all layers (`null` = per layer):",
        "",
        "```",
        json.dumps(prof["profile_constants"], indent=1, sort_keys=True),
        "```",
        "",
        "| layer | e_s | SiLU (e_in,e_out) |",
        "|---|---|---|",
    ]
    for l, c in enumerate(per):
        lines.append(f"| {l} | {c['exp_e_s']} | {tuple(c['silu_member'])} |")
    lines += [
        "",
        "## Files",
        "",
        f"* `layer_NN/*.bin` raw little-endian, UNPADDED: `wq` int8 ({d}, {d}), `wk`/`wv` int8 ({kvw}, {d}), `wo` int8 ({d}, {d}) — "
        f"(output, input); `gamma_a`/`gamma_m` int8 [{d}]; `wg_t`/`wu_t` int8 ({d}, {f}), `wd_t` int8 ({f}, {d}) — (input, output); "
        f"`exp` int64[256]; `act` int16[256]; `rope_cos`/`rope_sin` int64 ({prof['T']}, {geo['head_dim'] // 2}). No int8 word is -128.",
        "* `seq_hoNN/` int16 (T, 4096) x_in/x_out per layer of one held-out sequence per domain, continuous chain.",
        "* `rotation.json` / `rotation_sign.bin`: R = H diag(sign)/sqrt(4096), x' = x R^T (public-weight preparation).",
        "",
        "## Independent check",
        "",
        f"`b3_verify_export.py` (ZK60_MODEL=llama3-8b, reads only these files): ok = **{vrep['ok']}**, layers {vrep['layers']}, "
        f"sequences {json.dumps(vrep['sequences'])}, errors {vrep['errors'] or 'none'}.",
        "",
        "## Fidelity (calibration evidence, NOT a proof)",
        "",
        f"Calibration {summ['calibration']['sequences']} sequences x T={summ['calibration']['T_cal']} (licence/docstring + "
        "FineWeb-Edu row group 0); held-out from disjoint sources (licence/docstring held-out files + FineWeb-Edu row group 1). "
        "Tokenizer: the repo's tokenizer.json at the pinned revision (sha256 "
        f"{summ['tokenizer'].get('sha256')}). Float reference: float32; final norm + head in float outside the proof (D13).",
        "",
        "| held-out domain | sequences | refused | top-1 (all) | ppl float / int | KL |",
        "|---|---|---|---|---|---|",
    ]
    for dom, r in summ["by_domain"].items():
        a = r["head_all_diagnostic"]
        lines.append(f"| {dom} | {r['sequences']} | {r['refused']} | {a['top1_agreement']:.3f} | {a['ppl_float']:.2f} / "
                     f"{a['ppl_int']:.2f} | {a['kl_float_to_int_mean']:.3f} |")
    lines += ["", f"Residual scale s_x {meta['residual_scale_s_x']:.6g} (one scale, rotated basis). Calibration tool sha256: "
              f"{json.dumps(prof['calibration_tool']['sha256'])}."]
    (root / "README.md").write_text("\n".join(lines) + "\n")
    print(hashlib.sha256((root / "README.md").read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
