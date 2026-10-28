"""Count prompt-template tokens for open guard models (scratchpad research aid).

Run with: python3 -I count_tokens.py <dl_dir> <pylib_dir>
Renders each model's own chat template (or the model card's documented prompt)
around a sample user post, tokenizes with the model's own tokenizer.json, and
reports total / user-content / fixed-overhead token counts plus how the verdict
words tokenize.
"""
import json
import sys
from datetime import datetime

DL, PYLIB = sys.argv[1], sys.argv[2]
sys.path.insert(0, PYLIB)
from tokenizers import Tokenizer  # noqa: E402
import jinja2  # noqa: E402

SAMPLE = ("Just saw the new trailer and honestly I can't wait for the release next month. "
          "Anyone else planning to go opening night? Drop your favorite scene from the first "
          "movie below and let's talk about it.")


def env():
    e = jinja2.Environment(trim_blocks=True, lstrip_blocks=True, extensions=["jinja2.ext.loopcontrols"])
    def raise_exception(msg):
        raise RuntimeError(msg)
    e.globals["raise_exception"] = raise_exception
    e.globals["strftime_now"] = lambda fmt: datetime(2026, 10, 21).strftime(fmt)
    e.filters["tojson"] = lambda v, **k: json.dumps(v)
    return e


def tok(repo):
    return Tokenizer.from_file(f"{DL}/{repo}/tokenizer.json")


def tmpl(repo):
    try:
        return open(f"{DL}/{repo}/chat_template.jinja").read()
    except FileNotFoundError:
        return json.load(open(f"{DL}/{repo}/tokenizer_config.json"))["chat_template"]


def count(t, text):
    return len(t.encode(text, add_special_tokens=False).ids)


def pieces(t, words):
    out = {}
    for w in words:
        out[repr(w)] = t.encode(w, add_special_tokens=False).tokens
    return out


rows = []


def report(name, repo, prompt, sample, verdict_words, note=""):
    t = tok(repo)
    total = count(t, prompt)
    content = count(t, sample)
    i = prompt.index(sample)
    rows.append({"model": name, "tokenizer_source": repo.replace("__", "/"),
                 "total_tokens": total, "user_content_tokens": content,
                 "fixed_template_tokens": total - content,
                 "template_tokens_before_content": count(t, prompt[:i]),
                 "template_tokens_after_content": count(t, prompt[i + len(sample):]),
                 "verdict_tokenization": pieces(t, verdict_words), "note": note,
                 "prompt_tail": prompt[-120:]})


E = env()

# Llama Guard 3 1B (template from ungated mirror alpindale/Llama-Guard-3-1B)
p = E.from_string(tmpl("alpindale__Llama-Guard-3-1B")).render(
    messages=[{"role": "user", "content": [{"type": "text", "text": SAMPLE}]}],
    excluded_category_keys=[])
report("Llama-Guard-3-1B", "alpindale__Llama-Guard-3-1B", p, SAMPLE,
       ["safe", "unsafe", "\n\nsafe", "\n\nunsafe", "\n\n"], "S1-S13 default categories")

# Llama Guard 3 8B (mirror VincentGOURBIN/Llama-Guard-3-8B)
p = E.from_string(tmpl("VincentGOURBIN__Llama-Guard-3-8B")).render(
    messages=[{"role": "user", "content": SAMPLE}])
report("Llama-Guard-3-8B", "VincentGOURBIN__Llama-Guard-3-8B", p, SAMPLE,
       ["safe", "unsafe", "\n\nsafe", "\n\nunsafe"], "S1-S14 categories")

# Llama Guard 4 12B (mirror unsloth/Llama-Guard-4-12B)
p = E.from_string(tmpl("unsloth__Llama-Guard-4-12B")).render(
    messages=[{"role": "user", "content": [{"type": "text", "text": SAMPLE}]}],
    excluded_category_keys=[], bos_token="")
report("Llama-Guard-4-12B", "unsloth__Llama-Guard-4-12B", p, SAMPLE,
       ["safe", "unsafe", "\n\nsafe", "\n\nunsafe"], "S1-S14 categories, text only")

# Qwen3Guard-Gen (same tokenizer/template for 0.6B/4B/8B)
p = E.from_string(tmpl("Qwen__Qwen3Guard-Gen-0.6B")).render(
    messages=[{"role": "user", "content": SAMPLE}])
report("Qwen3Guard-Gen (0.6B/4B/8B)", "Qwen__Qwen3Guard-Gen-0.6B", p, SAMPLE,
       ["Safety: Safe", "Safety: Unsafe", "Safety: Controversial", " Safe", " Unsafe", " Controversial"],
       "prompt moderation; template ends with empty <think></think>")

# Shieldstral 1.0 3B: card example (one narrow policy) and broad multi-category Instruct
SYS = ('Judge whether the Document meets the requirements based on the Query and the Instruction '
       'provided. Note that the answer can only be "yes" or "no".')
inst1 = "You are a strict safety moderator reviewing potentially harmful content. Apply a low tolerance threshold."
q1 = "Does this content promote physical violence?"
inst2 = ("You are a strict safety moderator for a public media app. Apply a low tolerance threshold "
         "across violence, hate speech, harassment, sexual content, child exploitation, self-harm, "
         "and criminal activity.")
q2 = "Is this content unsafe?"
for label, inst, q in (("card example, one policy", inst1, q1), ("broad 7-category Instruct", inst2, q2)):
    user = f"<Instruct>: {inst}\n\n<Query>: {q}\n\n<Document>: {SAMPLE}"
    p = E.from_string(tmpl("mistralai__Shieldstral-1.0-3B")).render(
        messages=[{"role": "system", "content": SYS}, {"role": "user", "content": user}],
        bos_token="<s>", eos_token="</s>", add_generation_prompt=True)
    report(f"Shieldstral-1.0-3B ({label})", "mistralai__Shieldstral-1.0-3B", p, SAMPLE,
           ["yes", "no", " yes", " no"])

# ShieldGemma 2B/9B/27B: model-card prompt, one policy ("No Harassment" example)
policy = ('* "No Harassment": The prompt shall not contain or seek generation of content that is malicious, '
          'intimidating, bullying, or abusive content targeting another individual (e.g., physical threats, '
          'denial of tragic events, disparaging victims of violence).')
p = ("<bos>You are a policy expert trying to help determine whether a user\nprompt is in violation of the defined "
     f"safety policies.\n\n<start_of_turn>\nHuman Question: {SAMPLE}\n<end_of_turn>\n\nOur safety principle is "
     f"defined in the below:\n\n{policy}\n\nDoes the human question violate the above principle? Your answer must "
     "start\nwith 'Yes' or 'No'. And then walk through step by step to be sure we answer\ncorrectly.\n")
report("ShieldGemma (2B/9B/27B), one policy", "unsloth__gemma-2-2b", p, SAMPLE, ["Yes", "No"],
       "one call per policy; 4 policies = 4 calls")

# Granite Guardian 3.1 2B: default 'harm' risk via chat template
p = E.from_string(tmpl("ibm-granite__granite-guardian-3.1-2b")).render(
    messages=[{"role": "user", "content": SAMPLE}], add_generation_prompt=True, guardian_config=None)
report("Granite-Guardian-3.1-2B (harm)", "ibm-granite__granite-guardian-3.1-2b", p, SAMPLE,
       ["Yes", "No"], "includes default Granite system message")

# Granite Guardian 4.1 8B: README build_guardian_block, pre-baked Harm criterion, no-think
NOTHINK = ("<no-think>As a judge agent, assess whether the provided text meets the given judging criteria using all "
           "available information, including conversations, documents, and tools. Provide your score immediately "
           "without explanation. Output empty <think>\\n</think> tags followed by your score in <score></score> tags.")
crit = "Texts deemed universally harmful are those that pose harm across all contexts and audiences."
schema = "If the last user's text meets the criteria, return 'yes'; otherwise, return 'no'."
block = f"{NOTHINK}\n\n### Criteria: {crit}\n\n### Scoring Schema: {schema}"
p = E.from_string(tmpl("ibm-granite__granite-guardian-4.1-8b")).render(
    messages=[{"role": "user", "content": SAMPLE}, {"role": "user", "content": block}],
    add_generation_prompt=True)
report("Granite-Guardian-4.1-8B (harm, no-think)", "ibm-granite__granite-guardian-4.1-8b", p, SAMPLE,
       ["<think>\n</think>\n<score> yes </score>", "yes", "no", " yes", " no"])

# Nemotron 3.5 Content Safety (Gemma 3 4B), default 24-category taxonomy
p = E.from_string(tmpl("nvidia__Nemotron-3.5-Content-Safety")).render(
    messages=[{"role": "user", "content": SAMPLE}], bos_token="<bos>")
report("Nemotron-3.5-Content-Safety (4B)", "nvidia__Nemotron-3.5-Content-Safety", p, SAMPLE,
       ["User Safety: safe", "User Safety: unsafe", " safe", " unsafe"])

print(json.dumps({"sample_user_content": SAMPLE, "rows": rows}, indent=1, ensure_ascii=False))
