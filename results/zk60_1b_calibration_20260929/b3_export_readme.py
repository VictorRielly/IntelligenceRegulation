#!/usr/bin/env python3
"""Lane B3: write export/<variant>/README.md from its profile.json, the run
summary and the independent verification report. Pure file reading.
Usage: b3_export_readme.py <export dir> <run name> <verify report json>"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    root, run, vrep = Path(sys.argv[1]), sys.argv[2], json.loads(Path(sys.argv[3]).read_text())
    prof = json.loads((root / "profile.json").read_text())
    summ = json.loads((HERE / "runs" / f"b3_{run}" / "summary.json").read_text())
    pc = prof["profile_constants"]
    meta = prof["metadata_out_of_proof"]
    L = len(prof["layers"])
    lay0 = json.loads((root / "layer_00" / "manifest.json").read_text())
    per_layer = [json.loads((root / f"layer_{l:02d}" / "manifest.json").read_text())["constants"] for l in range(L)]
    diff = prof["per_layer_constants_differ"]
    ha, hd = summ.get("head_accepted") or {}, summ.get("head_all_diagnostic") or {}
    vo = prof["variant_options"]
    lines = [
        f"# TinyLlama-1.1B calibrated integer blocks — export `{prof['variant']}`",
        "",
        "**Scope: calibration data, not a proof, not a privacy claim, not proof readiness.** These files are the public",
        "integer words (int8 weights, int8 norm gains, exp / SiLU / RoPE tables, per-layer constants) that the native",
        "private-block prover would bind, plus one held-out sequence's exact integer hidden states for a bit-exact",
        "parity check. The fidelity numbers below come from a Python/numpy reference of the native relations",
        "(`tlcalib.i_block`), not from the native prover.",
        "",
        f"Schema `{prof['schema']}`. Model `{prof['model']['repo']}` revision `{prof['model']['revision']}`, "
        f"`model.safetensors` sha256 `{prof['model']['sha256']}`. T = {prof['T']} tokens. {L} layers.",
        "",
        "## Variant",
        "",
        f"`{json.dumps(vo)}`",
        "",
        "* `norm_cn` profile = one Cn per norm type for every layer; layer = per layer.",
        "* `tables` profile = one exp e_s and one SiLU member for every layer; layer = per layer (still native",
        "  generators / frozen registry members, chosen per block).",
        "* `residual` global = one residual scale s_x for the whole stack (residual-2 rescale k = sh_r2 = 0);",
        "  layer = per-layer power-of-two rescale x2 = requant(x1 + (z << k), k), k = sh_r2 >= 0.",
        "* `shifts` native = the toy shifts (SH_QKV 7, rope 7, S 6, O 9, AO 7, G 7, U 0, H 14, Z 6); free = per layer",
        "  inside the structure-preserving windows (one-byte sites 1..8, O and product 9..16); profile = one set.",
        "* `rotate` = seed of a randomized Hadamard rotation of the residual basis (public-weight change only:",
        "  gammas folded into the consumers, gains of the rotated norms carried by the int8 gain vectors).",
        "",
        "## Constants",
        "",
        "Uniform over all layers (`null` = differs per layer; see each `layer_NN/manifest.json`):",
        "",
        "```",
        json.dumps(pc, indent=1, sort_keys=True),
        "```",
        "",
        f"Constants that differ per layer: {diff or 'none'}.",
        "",
        "| layer | Cn_a | Cn_m | Ceps | e_s | SiLU (e_in,e_out) | SH qkv/s/ao/g/h/z | sh_r2 |",
        "|---|---|---|---|---|---|---|---|",
    ]
    for l, c in enumerate(per_layer):
        lines.append(f"| {l} | {c['norm_cn_a']} | {c['norm_cn_m']} | {c['norm_ceps']} | {c['exp_e_s']} | {tuple(c['silu_member'])} | "
                     f"{c['sh_qkv']}/{c['sh_s']}/{c['sh_ao']}/{c['sh_g']}/{c['sh_h']}/{c['sh_z']} | {c['sh_r2']} |")
    lines += [
        "",
        "Notes on constants: `norm_tn` 10 keeps the four-limb norm window (tn + 1 + bits(D_max) = 32 at width 2048,",
        "D_max = isqrt(2048 * 32768^2 + Ceps) < 2^21). `norm_ceps` = round(d * eps / s_x^2) reproduces RMSNorm's",
        "eps = 1e-5 at the layer's residual scale; values above 2684 are outside the bound the 2026-09-30 contract",
        "review checked (`results/zk60_trained_contract_review_20260930/HANDOFF.md`) and need that no-wrap argument",
        "re-run (Ceps only enters the norm's sum of squares). `norm_cn` <= 65536 (the reviewed bound).",
        "",
        "## Files",
        "",
        "* `profile.json` — schema, model pin, calibration tool sha256s, T, constants, layer list (with each",
        "  manifest's sha256), sequences, out-of-proof metadata (residual scales, per-layer float scales, rotation).",
        "* `layer_NN/manifest.json` — the layer's constants, table keys + spec digests, and every array",
        "  `{file, dtype, shape, sha256}`.",
        "* `layer_NN/*.bin` — raw little-endian, UNPADDED, native orientations: `wq` int8 (2048, 2048), `wk`/`wv`",
        "  int8 (256, 2048), `wo` int8 (2048, 2048) — all (output, input); `gamma_a`/`gamma_m` int8 [2048];",
        "  `wg_t`/`wu_t` int8 (2048, 5632) and `wd_t` int8 (5632, 2048) — (input, output); `exp` int64[256];",
        "  `act` int16[256]; `rope_cos`/`rope_sin` int64 (T, 32) (the native generator's tables, for cross-check).",
        "  No int8 word is -128.",
        "* `seq_hoNN/x_in_LNN.bin`, `x_out_LNN.bin` — int16 (T, 2048): the exact integer block's input and output of",
        "  layer NN on held-out sequence NN (chained: x_in of layer N+1 = x_out of layer N), plus `manifest.json`",
        "  with the token ids, source and selection rule (the first held-out sequence(s) accepted at every layer,",
        "  no fidelity-based choice).",
        "",
        "Tables: exp = `tables_attn.rs exp_member(e_s, 64, 9)`; act = `zkp-core tables.rs int16out_member(Silu, e_in,",
        "e_out)` (frozen registry; digest re-checked against the pin); rope = `rope_tables_generate(T, 64, 10000.0, 7)`.",
        "All generators were re-implemented in `b3calib.py` and reproduce the native pins byte for byte",
        "(`verify_tables`: 9/9 SiLU registry digests, exp pins for e_s -1/-2, RoPE t16/t32 pins).",
        "",
        "## Independent check",
        "",
        f"`b3_verify_export.py` (reads only these files): ok = **{vrep['ok']}**, layers {vrep['layers']}, sequences "
        f"{json.dumps(vrep['sequences'])}, errors {vrep['errors'] or 'none'}. It re-hashes every array, regenerates",
        "every table from its key, and re-runs the exact integer block from the binaries: x_out is reproduced bit",
        "for bit at every layer and the chain is continuous.",
        "",
        "## Fidelity (calibration evidence, NOT a proof)",
        "",
        f"Calibration: {len(summ['calib_sequences'])} sequences x T={(meta.get('calibration') or {}).get('T_cal', prof['T'])} "
        "(licence/docstring domain: GPL-3, GFDL-1.3, MPL-2.0 and six Python 3.10 stdlib modules' docstrings"
        + ("; FineWeb-Edu domain: row group 0 of the local shard" if summ.get("by_domain") and len(summ["by_domain"]) > 1 else "")
        + "); held-out: "
        f"{len(summ['heldout_sequences'])} sequences x T={prof['T']} from DISJOINT sources (Apache-2.0, LGPL-2.1,",
        "Artistic and six other stdlib modules" + ("; FineWeb-Edu row group 1" if summ.get("by_domain") and len(summ["by_domain"]) > 1 else "")
        + "). Float reference: float32 HF-Llama semantics; final norm + LM head in float outside the proved stack (D13).",
        "",
        f"* held-out sequences refused by the native relations (never clamped silently): {summ['heldout_refused']} of "
        f"{len(summ['heldout_sequences'])}; calibration refused: {summ['calib_refused']} of {len(summ['calib_sequences'])}.",
        f"* accepted held-out ({ha.get('sequences')} sequences, {ha.get('positions')} predicted positions): top-1 agreement with",
        f"  float {ha.get('top1_agreement')}, perplexity float {ha.get('ppl_float')} vs integer {ha.get('ppl_int')},",
        f"  mean KL(float || integer) {ha.get('kl_float_to_int_mean')} nats.",
        f"* all held-out (refusals clamped to continue: DIAGNOSTIC ONLY): top-1 {hd.get('top1_agreement')}, ppl integer "
        f"{hd.get('ppl_int')}.",
        "",
    ]
    cal = (meta.get("calibration") or {})
    if summ.get("by_domain"):
        lines += ["", f"Calibration: T_cal = {cal.get('T_cal', prof['T'])}, {cal.get('calibration_sequences')} sequences, domains "
                  f"{cal.get('domains')}" + (f"; FineWeb-Edu {cal['fineweb_edu']['dataset']} rev {cal['fineweb_edu']['revision']} "
                                             f"({cal['fineweb_edu']['licence']})" if cal.get("fineweb_edu") else "") + ".", "",
                  "| held-out domain | sequences | refused | top-1 (all) | ppl float / int (all) | KL (all) | top-1 (accepted) |",
                  "|---|---|---|---|---|---|---|"]
        for dom, r in summ["by_domain"].items():
            a, c = r["head_all_diagnostic"] or {}, r["head_accepted"] or {}
            lines.append(f"| {dom} | {r['sequences']} | {r['refused']} | {a.get('top1_agreement', float('nan')):.3f} | "
                         f"{a.get('ppl_float', float('nan')):.2f} / {a.get('ppl_int', float('nan')):.2f} | "
                         f"{a.get('kl_float_to_int_mean', float('nan')):.3f} | {c.get('top1_agreement', float('nan')):.3f} |")
    if (root / "token_io.json").exists():
        tio = json.loads((root / "token_io.json").read_text())
        lines += ["", f"Token I/O: `embedding_int16.bin` (int16 [32000, 2048], sha256 `{tio['embedding_table']['sha256']}`) gives "
                  "x_in_L00 = table[token] exactly; the output side and the rotation are specified in `../TOKEN_IO_SPEC.md`."]
    lines += [
        "",
        f"Residual scale(s): {meta['residual_scales_in'][0]:.6g} at layer 0 input"
        + ("" if prof["variant_options"]["residual"] == "global" else f" ... {meta['residual_scales_out'][-1]:.6g} at the output") + ".",
        "",
        f"Calibration tool: `{prof['calibration_tool']['path']}` with sha256 {json.dumps(prof['calibration_tool']['sha256'])}.",
    ]
    (root / "README.md").write_text("\n".join(lines) + "\n")
    print(hashlib.sha256((root / "README.md").read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
