"""Per-item content token counts and length-cap shares.

python3 -I length_stats.py OUT_JSON
Content tokens = tokenize(' ' + content) (template-independent; see shieldstral_common.ids_split).
Shares at <= 40 / 104 / 168 / 424 content tokens (the coordinator's T128 / T192 / T256 / T512 caps with an
~84-id prefix), per set and per OpenAI category, plus per-item counts for reuse.
"""
import gzip
import json
import sys

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

C.setup_paths()
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

CAPS = [40, 104, 168, 424]
CATS = {"sexual": ["S", "S3"], "violence": ["V", "V2"], "hate_harassment": ["H", "HR", "H2"]}


def main():
    tok = C.hf_tokenizer()
    n = lambda s: len(tok.encode(" " + s, add_special_tokens=False).ids)  # noqa: E731
    df = pd.read_csv(C.TOXICCHAT_CSV)
    out = {"caps": CAPS, "sets": {}, "items": {}}
    for name, frame in (("toxicchat_human", df[df.human_annotation == True]), ("toxicchat_all5083", df)):  # noqa: E712
        lens = np.array([n(s) for s in frame.user_input])
        y = frame.toxicity.values
        out["sets"][name] = {"n": int(lens.size), "share_le": {c: float(np.mean(lens <= c)) for c in CAPS},
                             "share_le_toxic": {c: float(np.mean(lens[y == 1] <= c)) for c in CAPS},
                             "count_le": {c: int(np.sum(lens <= c)) for c in CAPS}}
        if name == "toxicchat_human":
            out["items"]["toxicchat"] = {str(i): int(v) for i, v in zip(frame.conv_id, lens)}
    rows = [json.loads(line) for line in gzip.open(C.OPENAI_MOD_JSONL_GZ, "rt")]
    lens = np.array([n(r["prompt"]) for r in rows])
    out["items"]["openai_mod"] = {str(i): int(v) for i, v in enumerate(lens)}
    unsafe = np.array([any(r.get(k) == 1 for k in sum(CATS.values(), [])) for r in rows])
    rec = {"n": int(lens.size), "share_le": {c: float(np.mean(lens <= c)) for c in CAPS},
           "share_le_unsafe": {c: float(np.mean(lens[unsafe] <= c)) for c in CAPS},
           "count_le": {c: int(np.sum(lens <= c)) for c in CAPS}, "categories": {}}
    for cat, keys in CATS.items():
        pos = np.array([any(r.get(k) == 1 for k in keys) for r in rows])
        known0 = np.array([(not p) and all(r.get(k) in (0, None) for k in keys) and any(r.get(k) == 0 for k in keys)
                           for r, p in zip(rows, pos)])
        rec["categories"][cat] = {"positives": int(pos.sum()), "negatives_some_label_known_0": int(known0.sum()),
                                  "all_labels_missing": int(np.sum(~pos & ~known0)),
                                  "positives_le": {c: int(np.sum(pos & (lens <= c))) for c in CAPS},
                                  "tokens_le168_total": int(lens[lens <= 168].sum())}
    out["sets"]["openai_mod"] = rec
    out["sets"]["openai_mod"]["tokens_total"] = int(lens.sum())
    json.dump(out, open(sys.argv[1], "w"), indent=1)
    s = out["sets"]
    for k in ("toxicchat_human", "toxicchat_all5083", "openai_mod"):
        print(k, {c: round(v, 3) for c, v in s[k]["share_le"].items()})
    print("toxic-only (ToxicChat human)", {c: round(v, 3) for c, v in s["toxicchat_human"]["share_le_toxic"].items()})
    print("unsafe-only (OpenAI)", {c: round(v, 3) for c, v in s["openai_mod"]["share_le_unsafe"].items()})
    print(json.dumps(s["openai_mod"]["categories"], indent=0))


if __name__ == "__main__":
    main()
