"""Hugging Face transformers 5.13.1 forward of Shieldstral's text decoder, layer-streamed.

python3 -I hf_check.py PROMPTS_JSON OUT_NPZ [--threads N]

Runs HF's own Ministral3ForCausalLM.forward (the text model class that Mistral3ForConditionalGeneration
wraps): HF's Ministral3RotaryEmbedding (YaRN via ROPE_INIT_FUNCTIONS['yarn']), HF's causal mask,
HF's eager attention, RMSNorm and MLP, all in float32 on CPU.  The model is built on the meta device;
each decoder layer's weights are loaded by a forward pre-hook through the `safetensors` library
(torch, bf16 -> float32) and released after the layer runs, so one layer is resident at a time.
Inputs: token ids -> embedding rows read with safetensors get_slice.  The tied head (lm_head ==
embed_tokens per HF's _tied_weights_keys) is evaluated at the last position only, in row chunks.
"""
import json
import sys
import time

sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_shieldstral_prep_20261021/tools")
import shieldstral_common as C  # noqa: E402

C.setup_paths(new_hf=True)
import numpy as np  # noqa: E402
import torch  # noqa: E402
from safetensors import safe_open  # noqa: E402
from transformers import AutoConfig  # noqa: E402
import transformers  # noqa: E402
from transformers.models.ministral3 import modeling_ministral3 as M  # noqa: E402

WEIGHTS = f"{C.SNAP}/model.safetensors"
PFX = "language_model.model."


def main():
    prompts = json.load(open(sys.argv[1]))
    out_path = sys.argv[2]
    threads = int(sys.argv[sys.argv.index("--threads") + 1]) if "--threads" in sys.argv else 4
    dt = torch.bfloat16 if "--bf16" in sys.argv else torch.float32
    torch.set_num_threads(threads)
    cfg = AutoConfig.from_pretrained(C.SNAP)
    tcfg = cfg.text_config
    tcfg._attn_implementation = "eager"
    info = {"transformers": transformers.__version__, "torch": torch.__version__,
            "config_class": type(cfg).__name__, "text_config_class": type(tcfg).__name__,
            "tie_word_embeddings_top": bool(cfg.tie_word_embeddings),
            "tie_word_embeddings_text": bool(tcfg.tie_word_embeddings),
            "rope_parameters": dict(tcfg.rope_parameters), "head_dim": tcfg.head_dim,
            "attn_implementation": "eager", "dtype": str(dt)}
    with torch.device("meta"):
        model = M.Ministral3ForCausalLM(tcfg)
    model.eval()
    info["tied_weights_keys"] = getattr(model, "_tied_weights_keys", None)
    # HF's own rotary module, materialized on CPU (YaRN inverse frequencies + attention scaling).
    model.model.rotary_emb = M.Ministral3RotaryEmbedding(tcfg, device="cpu")
    info["hf_attention_scaling"] = float(model.model.rotary_emb.attention_scaling)
    info["hf_inv_freq"] = model.model.rotary_emb.inv_freq.tolist()
    with safe_open(WEIGHTS, framework="pt") as f:
        keys = list(f.keys())
    info["checkpoint_has_lm_head"] = any("lm_head" in k for k in keys)

    def load_into(mod, prefix):
        with safe_open(WEIGHTS, framework="pt") as f:
            sd = {k[len(prefix):]: (f.get_tensor(k).clone() if dt == torch.bfloat16 else f.get_tensor(k).to(dt))
                  for k in keys if k.startswith(prefix)}
        mod.load_state_dict(sd, assign=True, strict=True)

    def make_pre(i):
        def pre(mod, args, kwargs):
            load_into(mod, f"{PFX}layers.{i}.")
        return pre

    def post(mod, args, kwargs, output):
        mod.to("meta")

    for i, layer in enumerate(model.model.layers):
        layer.register_forward_pre_hook(make_pre(i), with_kwargs=True)
        layer.register_forward_hook(post, with_kwargs=True)
    load_into(model.model.norm, f"{PFX}norm.")

    def embed_rows(ids):
        with safe_open(WEIGHTS, framework="pt") as f:
            sl = f.get_slice(f"{PFX}embed_tokens.weight")
            return torch.cat([sl[int(t):int(t) + 1].to(dt) for t in ids], 0)

    def tied_head(h):  # h [..., D] -> logits [..., V], lm_head.weight == embed_tokens.weight
        outs = []
        with safe_open(WEIGHTS, framework="pt") as f:
            sl = f.get_slice(f"{PFX}embed_tokens.weight")
            for a in range(0, tcfg.vocab_size, 8192):
                e = sl[a:a + 8192].to(dt)
                outs.append(h @ e.T)
        return torch.cat(outs, -1)

    model.lm_head.forward = tied_head
    results = []
    for p in prompts:
        ids = p["ids"]
        t0 = time.time()
        with torch.no_grad():
            emb = embed_rows(ids)[None]
            out = model(inputs_embeds=emb, logits_to_keep=1, use_cache=False)
        logits = out.logits[0, -1].float().numpy().astype(np.float32)
        results.append(logits)
        print(f"{p['name']}: T={len(ids)} {time.time() - t0:.1f}s argmax={int(logits.argmax())}", flush=True)
    np.savez(out_path, logits=np.stack(results), names=np.array([p["name"] for p in prompts]))
    with open(out_path.replace(".npz", ".info.json"), "w") as fh:
        json.dump(info, fh, indent=1)
    print("wrote", out_path)


if __name__ == "__main__":
    main()
