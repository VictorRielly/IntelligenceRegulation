#!/usr/bin/env python3
"""s1: the token sequences of the B4 calibration run (exactly b3_ladder.py --corpus b4 defaults:
calib_per 6, heldout_per 4, fw_calib 54, fw_heldout 36; calibration at T_cal 128).

Writes data/tokens_heldout_T{128,64,32}.npz (ids, domains) + .json (meta) and
data/tokens_calib_T128.npz; checks the exported sequences' token ids (seq_ho00, seq_ho36)
against the rebuilt held-out sets. Calibration data, not a proof.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fid_common as fc  # noqa: E402
import numpy as np  # noqa: E402

from corpus import sequences  # noqa: E402
import corpus4  # noqa: E402
from spm_bpe import SpmBpe, tokenizer_selfcheck  # noqa: E402


def heldout(tok, T):
    ho, ho_meta = sequences(tok, "heldout", T, 4)
    for m in ho_meta:
        m.setdefault("domain", "licence-docstring")
    h2, n2 = corpus4.fineweb_sequences(tok, "heldout", T, 36)
    return ho + h2, ho_meta + n2


def calib(tok, T):
    cal, cal_meta = sequences(tok, "calib", T, 6)
    for m in cal_meta:
        m.setdefault("domain", "licence-docstring")
    c2, m2 = corpus4.fineweb_sequences(tok, "calib", T, 54)
    return cal + c2, cal_meta + m2


def main():
    fc.DATA.mkdir(parents=True, exist_ok=True)
    tok = SpmBpe(fc.tc.MODEL_DIR / "tokenizer.model")
    chk = tokenizer_selfcheck(tok)
    assert all(c["ok"] for c in chk["cases"].values()), "tokenizer selfcheck failed"
    report = {"tokenizer_selfcheck": True, "sets": {}}
    cal, cal_meta = calib(tok, 128)
    cal_ids = np.array(cal, dtype=np.int64)
    np.savez(fc.DATA / "tokens_calib_T128.npz", ids=cal_ids, domains=np.array([m["domain"] for m in cal_meta]))
    (fc.DATA / "tokens_calib_T128.json").write_text(json.dumps(cal_meta, indent=1))
    report["sets"]["calib_T128"] = {"shape": list(cal_ids.shape)}
    fc.log(f"calibration set {cal_ids.shape}")
    for T in (128, 64, 32):
        ho, meta = heldout(tok, T)
        ids = np.array(ho, dtype=np.int64)
        assert not (set(map(tuple, cal)) & set(map(tuple, ho))) or T != 128, "calibration / held-out overlap"
        dom = np.array([m["domain"] for m in meta])
        checks = {}
        for sname, (idx, tids, _, _) in fc.exported_sequences(T).items():
            checks[sname] = {"heldout_index": idx, "token_ids_equal": bool(np.array_equal(ids[idx], tids))}
            assert checks[sname]["token_ids_equal"], f"T{T} {sname}: rebuilt held-out tokens differ from the export"
        np.savez(fc.DATA / f"tokens_heldout_T{T}.npz", ids=ids, domains=dom)
        (fc.DATA / f"tokens_heldout_T{T}.json").write_text(json.dumps(meta, indent=1))
        report["sets"][f"heldout_T{T}"] = {"shape": list(ids.shape), "domains": {k: int(v) for k, v in zip(*np.unique(dom, return_counts=True))},
                                          "export_checks": checks}
        fc.log(f"held-out T{T}: {ids.shape}, export checks {checks}")
    (fc.DATA / "s1_tokens_report.json").write_text(json.dumps(report, indent=1))
    print(json.dumps(report, indent=1))


if __name__ == "__main__":
    main()
