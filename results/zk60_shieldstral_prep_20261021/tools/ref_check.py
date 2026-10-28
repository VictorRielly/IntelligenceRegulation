"""Run the numpy reference on the cross-check prompts.

python3 -I ref_check.py PROMPTS_JSON OUT_NPZ --fmt hf|consolidated --rope yarn|plain|yarn_notrunc|yarn_f32
                        [--only hf5|all] [--prefix-cache]   (threads: set OPENBLAS_NUM_THREADS outside)

--prefix-cache: only for prompts with a 'template' field; runs them with the shared public prefix's K/V
computed once (the benchmark path) instead of a full forward.
"""
import json
import sys
import time

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

C.setup_paths()
import numpy as np  # noqa: E402
import shieldstral_ref as R  # noqa: E402


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def main():
    prompts = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    fmt, rope, only = arg("--fmt", "hf"), arg("--rope", "yarn"), arg("--only", "all")
    pc = "--prefix-cache" in sys.argv
    if only == "hf5":
        prompts = [p for p in prompts if p["hf5"]]
    if pc:
        prompts = [p for p in prompts if p.get("template")]
    m = (R.RefBF16 if "--bf16-emul" in sys.argv else R.Ref)(fmt, rope_variant=rope)
    t0 = time.time()
    if pc:
        P = prompts[0]["prefix_len"]
        pre = prompts[0]["ids"][:P]
        res = m.run([p["ids"] for p in prompts], prefix_ids=pre, want_layer_last=False,
                    log=lambda s: print(s, flush=True))
    else:
        res = m.run([p["ids"] for p in prompts], want_layer_last=True, log=lambda s: print(s, flush=True))
    y, n, vy, vn = C.verdict_token_ids()
    summ = []
    for p, row in zip(prompts, res["logits"]):
        s = R.summarize(row, y, n, vy, vn)
        s.update({"name": p["name"], "T": len(p["ids"]), "published_score": p["published_score"]})
        summ.append(s)
        print(f"{p['name']:16s} T={len(p['ids']):4d} margin={s['margin']:+.4f} d38={s['d38_score']:.4f} "
              f"ref={s['ref_score']:.4f} published={p['published_score']} argmax={s['argmax']}", flush=True)
    save = {"logits": res["logits"], "names": np.array([p["name"] for p in prompts])}
    if res["layer_last"] is not None:
        save["layer_last"] = np.stack(res["layer_last"], 1)  # [n_prompts, L+1, D]
    np.savez(out, **save)
    meta = {"fmt": fmt, "rope": rope, "bf16_emul": "--bf16-emul" in sys.argv, "prefix_cache": pc, "tied_head": m.tied, "has_lm_head": m.has_lm_head,
            "inv_freq": m.inv_freq.tolist(), "attention_factor": m.att_factor, "seconds": time.time() - t0,
            "tokens_processed": res["tokens_processed"], "yes_id": y, "no_id": n,
            "yes_variant_ids": vy, "no_variant_ids": vn, "summary": summ}
    json.dump(meta, open(out.replace(".npz", ".json"), "w"), indent=1)
    print("wrote", out, f"{time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
