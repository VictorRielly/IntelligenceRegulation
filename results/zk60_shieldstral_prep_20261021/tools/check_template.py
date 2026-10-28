"""Template + tokenizer checks for the fixed public Shieldstral template.

python3 -I check_template.py OUT_JSON

For each template: renders the prompt, counts public prefix / suffix tokens, and over every
benchmark item (ToxicChat human-annotated test subset + OpenAI Moderation 1,680):
  (a) HF tokenizer.json + chat_template.jinja ids == mistral_common (tekken.json) ids,
  (b) the split prefix | tokenize(' ' + content) | suffix reproduces the full ids exactly,
  (c) content token-length distribution.
Also records the yes/no token ids and the cookbook variant-token sets.
"""
import gzip
import json
import sys

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

C.setup_paths()
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from mistral_common.protocol.instruct.messages import SystemMessage, UserMessage  # noqa: E402
from mistral_common.protocol.instruct.request import ChatCompletionRequest  # noqa: E402
from mistral_common.tokens.tokenizers.mistral import MistralTokenizer  # noqa: E402


def load_items():
    df = pd.read_csv(C.TOXICCHAT_CSV)
    h = df[df.human_annotation == True]  # noqa: E712
    tc = [{"set": "toxicchat", "id": r.conv_id, "content": r.user_input, "label": int(r.toxicity)}
          for r in h.itertuples()]
    cats = ["S", "H", "V", "HR", "SH", "S3", "H2", "V2"]
    om = []
    for i, line in enumerate(gzip.open(C.OPENAI_MOD_JSONL_GZ, "rt")):
        r = json.loads(line)
        om.append({"set": "openai_mod", "id": i, "content": r["prompt"],
                   "label": int(any(r.get(k) == 1 for k in cats))})
    return tc, om


def pct(a):
    a = np.asarray(a)
    return {"n": int(a.size), "min": int(a.min()), "p10": float(np.percentile(a, 10)),
            "p25": float(np.percentile(a, 25)), "median": float(np.median(a)),
            "mean": float(a.mean()), "p75": float(np.percentile(a, 75)), "p90": float(np.percentile(a, 90)),
            "p95": float(np.percentile(a, 95)), "p99": float(np.percentile(a, 99)), "max": int(a.max()),
            "le64": float((a <= 64).mean()), "le128": float((a <= 128).mean()),
            "le256": float((a <= 256).mean()), "le512": float((a <= 512).mean()),
            "le1024": float((a <= 1024).mean())}


def main():
    out = {"revision": C.REVISION}
    mt = MistralTokenizer.from_file(f"{C.MODEL_DIR}/tekken.json")
    tok = C.hf_tokenizer()
    y, n, vy, vn = C.verdict_token_ids()
    out["verdict_tokens"] = {
        "yes_id": y, "no_id": n,
        "yes_variants": {i: tok.decode([i], skip_special_tokens=False) for i in vy},
        "no_variants": {i: tok.decode([i], skip_special_tokens=False) for i in vn},
    }
    tc, om = load_items()
    out["items"] = {"toxicchat_human": len(tc), "toxicchat_pos": sum(r["label"] for r in tc),
                    "openai_mod": len(om), "openai_mod_pos": sum(r["label"] for r in om)}
    out["templates"] = {}
    for name in C.TEMPLATES:
        pre, suf = C.prefix_suffix_text(name)
        p_ids = tok.encode(pre, add_special_tokens=False).ids
        s_ids = tok.encode(suf, add_special_tokens=False).ids
        rec = {"template": C.TEMPLATES[name], "system_prompt": C.SYSTEM_PROMPT,
               "prefix_text": pre, "suffix_text": suf,
               "prefix_tokens": len(p_ids), "suffix_tokens": len(s_ids),
               "prefix_ids": p_ids, "suffix_ids": s_ids,
               "prefix_pieces": [tok.id_to_token(i) for i in p_ids],
               "suffix_pieces": [tok.id_to_token(i) for i in s_ids]}
        mism_mc, mism_split, lens = [], [], {"toxicchat": [], "openai_mod": []}
        for it in tc + om:
            msgs = C.messages_for(name, it["content"])
            full = C.ids_full(name, it["content"])
            req = ChatCompletionRequest(messages=[SystemMessage(content=msgs[0]["content"]),
                                                  UserMessage(content=msgs[1]["content"])])
            mc = mt.encode_chat_completion(req).tokens
            if mc != full:
                mism_mc.append({"set": it["set"], "id": str(it["id"]), "len_hf": len(full), "len_mc": len(mc)})
            p, c, s = C.ids_split(name, it["content"])
            if p + c + s != full:
                mism_split.append({"set": it["set"], "id": str(it["id"])})
            lens[it["set"]].append(len(c))
        rec["mistral_common_mismatches"] = {"count": len(mism_mc), "first": mism_mc[:20]}
        rec["split_mismatches"] = {"count": len(mism_split), "first": mism_split[:20]}
        rec["content_tokens"] = {k: pct(v) for k, v in lens.items()}
        rec["total_tokens_T"] = {k: pct(np.asarray(v) + len(p_ids) + len(s_ids)) for k, v in lens.items()}
        out["templates"][name] = rec
        print(name, "prefix", len(p_ids), "suffix", len(s_ids), "mc-mismatch", len(mism_mc),
              "split-mismatch", len(mism_split), flush=True)
    # example rendering
    out["example_rendered"] = C.render_chat(C.messages_for("card", "How can I hurt someone without being caught?"))
    with open(sys.argv[1], "w") as f:
        json.dump(out, f, indent=1, ensure_ascii=False)
    print("wrote", sys.argv[1])


if __name__ == "__main__":
    main()
