"""Float-reference benchmark runner (resumable, time-boxed).

python3 -I bench_run.py --set toxicchat|openai_mod --template card|cookbook --out OUT.jsonl
                        [--limit N] [--token-budget 4096] [--max-minutes 28] [--seed 20261021]

Items are taken in a fixed pseudo-random order (numpy default_rng(seed).permutation); the first
--limit items of that order form the subset, so a later full run simply continues it.  Items whose
id is already in OUT.jsonl are skipped.  The shared public prefix's K/V is computed once per process;
each item then processes only its content + suffix tokens.  Exits 0 when all requested items are done,
3 when it stopped on the time box with items left (the queue relaunches it).
ToxicChat = toxicchat0124 test, human_annotation == True subset (2,853 rows; the paper's count).
OpenAI Moderation = samples-1680; unsafe = any category label == 1.
"""
import gzip
import json
import os
import sys
import time

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

C.setup_paths()
import numpy as np  # noqa: E402
import shieldstral_ref as R  # noqa: E402


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def load_set(name):
    if name == "toxicchat":
        import pandas as pd
        df = pd.read_csv(C.TOXICCHAT_CSV)
        h = df[df.human_annotation == True]  # noqa: E712
        return [{"id": str(r.conv_id), "content": r.user_input, "label": int(r.toxicity),
                 "jailbreaking": int(r.jailbreaking)} for r in h.itertuples()]
    cats = ["S", "H", "V", "HR", "SH", "S3", "H2", "V2"]
    out = []
    for i, line in enumerate(gzip.open(C.OPENAI_MOD_JSONL_GZ, "rt")):
        r = json.loads(line)
        out.append({"id": str(i), "content": r["prompt"], "label": int(any(r.get(k) == 1 for k in cats)),
                    "cats": [k for k in cats if r.get(k) == 1], "known": [k for k in cats if k in r]})
    return out


def select(items, seed, limit, max_ct, strat_safe):
    """Seeded order; optional content-token cap; optional stratification (all label-1 items + a seeded
    sample of `strat_safe` label-0 items, each row carrying an importance weight for population metrics)."""
    order = np.random.default_rng(seed).permutation(len(items))
    items = [items[i] for i in order]
    for it in items:
        it["weight"] = 1.0
    if max_ct:
        tok = C.hf_tokenizer()
        items = [it for it in items if len(tok.encode(" " + it["content"], add_special_tokens=False).ids) <= max_ct]
    if strat_safe:
        pos = [it for it in items if it["label"] == 1]
        neg = [it for it in items if it["label"] == 0]
        w = len(neg) / min(strat_safe, len(neg))
        neg = neg[:strat_safe]
        for it in neg:
            it["weight"] = w
        keep = {id(it) for it in pos + neg}
        items = [it for it in items if id(it) in keep]
    return items[:limit] if limit else items


def main():
    t_start = time.time()
    setname, template, out = arg("--set"), arg("--template", "card"), arg("--out")
    limit = int(arg("--limit", "0")) or None
    budget = int(arg("--token-budget", "4096"))
    max_min = float(arg("--max-minutes", "28"))
    seed = int(arg("--seed", "20261021"))
    max_ct = int(arg("--max-content-tokens", "0")) or None
    strat_safe = int(arg("--strat-safe", "0")) or None
    items = load_set(setname)
    if max_ct or strat_safe:
        sel = select(items, seed, limit, max_ct, strat_safe)
    else:  # original behaviour (kept bit-identical for the existing subset files)
        order = np.random.default_rng(seed).permutation(len(items))
        sel = [items[i] for i in order[:limit]] if limit else [items[i] for i in order]
    done = set()
    if os.path.exists(out):
        for line in open(out):
            done.add(json.loads(line)["id"])
    todo = [it for it in sel if it["id"] not in done]
    print(f"{setname}/{template}: {len(sel)} selected, {len(done)} done, {len(todo)} to do", flush=True)
    if not todo:
        return 0
    yes_id, no_id, vy, vn = C.verdict_token_ids()
    pre_text_ids = None
    seqs = []
    for it in todo:
        p, c, s = C.ids_split(template, it["content"])
        full = C.ids_full(template, it["content"])
        if p + c + s != full:
            raise SystemExit(f"split mismatch for item {it['id']}")
        if pre_text_ids is None:
            pre_text_ids = p
        assert p == pre_text_ids
        it["_ids"], it["_nc"] = full, len(c)
    P = len(pre_text_ids)
    m = (R.RefBF16 if "--bf16-emul" in sys.argv else R.Ref)("hf")
    t0 = time.time()
    kv = m._prefix_kv(np.asarray(pre_text_ids, np.int64), 2048)
    print(f"prefix {P} tokens K/V in {time.time() - t0:.1f}s", flush=True)
    m_prefix = kv

    # batches by tail-token budget, in selection order
    batches, cur, cur_n = [], [], 0
    for it in todo:
        n = len(it["_ids"]) - P
        if cur and cur_n + n > budget:
            batches.append(cur)
            cur, cur_n = [], 0
        cur.append(it)
        cur_n += n
    if cur:
        batches.append(cur)
    n_done = 0
    with open(out, "a") as fh:
        for bi, b in enumerate(batches):
            if (time.time() - t_start) / 60 > max_min:
                print(f"time box reached after {n_done} items; {len(todo) - n_done} left", flush=True)
                return 3
            tb = time.time()
            res = run_with_prefix(m, b, pre_text_ids, m_prefix)
            for it, row in zip(b, res["logits"]):
                s = R.summarize(row, yes_id, no_id, vy, vn)
                rec = {"set": setname, "template": template, "bf16_emul": "--bf16-emul" in sys.argv,
                       "id": it["id"], "label": it["label"],
                       "n_content_tokens": it["_nc"], "T": len(it["_ids"]), **s}
                for k in ("jailbreaking", "cats", "known", "weight"):
                    if k in it:
                        rec[k] = it[k]
                fh.write(json.dumps(rec) + "\n")
            fh.flush()
            n_done += len(b)
            ntok = sum(len(it["_ids"]) - P for it in b)
            print(f"batch {bi + 1}/{len(batches)}: {len(b)} items, {ntok} tail tokens, "
                  f"{time.time() - tb:.1f}s ({ntok / (time.time() - tb):.1f} tok/s); total done {n_done}",
                  flush=True)
    print(f"all {len(todo)} items done in {(time.time() - t_start) / 60:.1f} min", flush=True)
    return 0


def run_with_prefix(m, batch, prefix_ids, kv):
    """Same as Ref.run(prefix_ids=...) but reusing a precomputed prefix K/V."""
    P = len(prefix_ids)
    tails = [np.asarray(it["_ids"][P:], np.int64) for it in batch]
    lens = [len(t) for t in tails]
    offs = np.concatenate([[0], np.cumsum(lens)]).astype(np.int64)
    pos = np.concatenate([P + np.arange(n) for n in lens]).astype(np.int64)
    m.llama4_scale(pos)
    x = m.embed(np.concatenate(tails))
    for i in range(R.L):
        x = m._layer(x, i, pos, offs, kv[i], 2048)
    hn = m.rmsnorm(x[offs[1:] - 1], m.f.get_f32(m.n["norm"]))
    return {"logits": m.head(hn)}


if __name__ == "__main__":
    sys.exit(main())
