# A14: policy-prompt lengths of the named guards

Applications researcher, 2026-11-26 UTC. Triage material, not a work order.

## Question

How many tokens do the default prompt templates of Llama Guard 3, Qwen3Guard and Granite Guardian use for one 40-token
input; how does each compare with the T = 128 profile and with the registered Shieldstral policy texts (72 and 78
tokens); which guards need a chunk plan or a larger rung; and, per guard, are the verdict words single tokens at the
position where the installed relation reads them (it compares two token ids)?

## What was read, and how

- Local: `shieldstral_text.py` (the app's template and chunk code, read only), the Shieldstral privacy statement v3, the A10 and A18 handoffs, the first 75 lines of `MVP_STATUS.md`.
- Downloaded from the publishers' own repositories into new directories, read as data and tokenized with `tokenizers` through an existing interpreter (run with `-I`); nothing installed, no weights, no login:
  - Qwen3Guard-Gen-8B `tokenizer.json`, `tokenizer_config.json` (Hugging Face `Qwen/Qwen3Guard-Gen-8B`, resolve/main).
  - Granite Guardian 3.3 8B `tokenizer.json`, `chat_template.jinja` (`ibm-granite/granite-guardian-3.3-8b`).
  - Llama Guard: `tokenizer.json` and `tokenizer_config.json` of `meta-llama/Llama-Guard-3-8B` and `-3-1B` answered HTTP 401 (gated). Not logged in, no mirror used. **Llama Guard 3 token counts: NOT VERIFIED.** The 8B model card (public) and Meta's `llama-cookbook` file `prompt_format_utils.py` (official repository, read, not executed; its category list was parsed as data) supplied the template text.
- Sha256 of the files used:
  - Qwen `tokenizer.json` `aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4`; Qwen `tokenizer_config.json` `934e187433b06c5d28519e0347dd293084cf28621f00a86ae7e24e42f8b53e81`.
  - Granite `tokenizer.json` `91168e938f05796aa6dcca7e485e4b30ab52785320c7a6391ecef86e6c84681e`; Granite `chat_template.jinja` `ddb691d71955c735aeca367b7405cf3e3622cf33788d6a1a7186965f0a4a69fc`.
  - Cookbook `prompt_format_utils.py` `189b604a1de59774404d22b19e5fe43c7118c2abd9647d5707373516dd5b40d2`.
- What was tokenized: the guard's own default chat template rendered with one user message (a single-turn "check the user prompt" case, no system message, no thinking, no custom criteria) whose text is 40 tokens under that guard's own tokenizer (an English sentence prefix; the string differs per tokenizer). Granite: `add_generation_prompt=True`, default criteria `harm`, `no_think`. Special-token markers in the template (`<|im_start|>`, `<|start_of_role|>`, ...) are in the text and were counted as the single tokens they are; no extra special tokens were added by the tokenizer (`add_special_tokens` False and True gave identical counts). The rendered prompt ends where generation starts.
- The renderer (a sandboxed Jinja environment) was checked against the library: `transformers` `apply_chat_template` on the same local files gave 297 and 116 tokens for empty content, equal to mine, and 301 and 120 for a four-word message.

## Findings

All counts MEASURED by tokenizing the files above (the arithmetic after them is DERIVED).

| Guard (template) | Template only (empty content) | With the 40-token input | Against T = 128 |
|---|---|---|---|
| Shieldstral registered "moderate" texts | 72 / 72 / 78 including the BOS id, plus the 1-token suffix | 113 / 113 / 119 | fits; chunk capacity 55 / 55 / 49 |
| Qwen3Guard-Gen (8B repo) | 297 | 337 | does not fit; the template alone exceeds 128 and also 256 |
| Granite Guardian 3.3 8B | 116 | 156 | the template leaves 12 content tokens |
| Llama Guard 3 (8B and 1B) | NOT VERIFIED | NOT VERIFIED | see the estimate below |

- **Source of the 72 and 78.** [COUNTED] Statement v3, `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_CLASSIFIER_SHIELDSTRAL_T128_DRAFT_v3.md:204`: "P0 72, chunk 55" for sexual and violence, "P0 78, chunk 49" for hate, for the registered *moderate* wording, with a suffix of one token (`[/INST]` = [4]). The code defines the chunk as `context_tokens - len(prefix) - len(suffix)` (`shieldstral_text.py:86`) and requires `prefix[0] == 1`, the BOS id (`:76`), so P0 includes the BOS id. These are R13-statement figures; I did not tokenize the installed profile's pinned policy files (`apps/proven-media/policy/shieldstral-moderate-*-v1.txt`, 383 to 423 bytes) and did not check that they equal those texts.
- **Qwen3Guard** needs a larger rung than any in the code. [DERIVED] 128 - 297 < 0 and 256 - 297 < 0; `CategoryTemplate` accepts only 128 or 256 (`shieldstral_text.py:79`). The next power of two, 512, would leave 215 content tokens; no 512 profile is in the records read. Its fixed text carries the policy, a nine-item category list and the instructions; I did not check whether the 0.6B and 4B repositories use the same template.
- **Granite Guardian** fits T = 256 but not T = 128 usefully. [DERIVED] At 128, 12 content tokens per chunk; with the Shieldstral overlap of 8 (statement v3 line 205) the plan formula (`shieldstral_text.py:91-97`) gives stride 4 and 8 chunks for a 40-token input. At 256, 140 content tokens: one chunk. 256 is an allowed value in the code; I did not check that any 256 classifier profile has been proved or timed.
- **Llama Guard 3, ESTIMATE only.** The cookbook's default template (names-only category list S1 to S14) was rendered and tokenized with the *Qwen* and *Granite* tokenizers as stand-ins: 251 and 307 template-only tokens (291 and 358 with the input). The stand-ins split the six Llama special-token markers into several pieces each, so they over-count by roughly 20 to 30 tokens, and the real Llama tokenizer will differ in other ways. Reading: names-only is likely near or above 256 with the input, not certain. With category descriptions added (the cookbook's `with_policy` option) the same proxies give 886 and 1,099 template-only. Whether the guard's own gated chat template carries names only or descriptions was not verifiable. The 1B model uses its own category subset and is also gated. No claim that Llama Guard fits any rung.

### Verdict words at the generated position (the installed relation compares two token ids)

Installed template code refuses any suffix other than `(4,)` (`shieldstral_text.py:76`), and the verdict row is the last prompt row.

- **Qwen3Guard.** The template ends `<think>`, blank line, `</think>`, blank line, so generation starts at "Safety: ...". [MEASURED] `Safety` (id 73037) then `:` (25) then the verdict. The first generated token is therefore `Safety` for all three labels and does not discriminate. The verdict is the third token: ` Safe` 22291 and ` Unsafe` 73067 are single tokens; ` Controversial` is three tokens (2093, 12563, 530). A two-id relation would need `Safety:` appended to the public prompt (2 more tokens, a different suffix) and would read Safe against Unsafe; the third label has no single id (its first piece, 2093, is distinct from the other two).
- **Granite Guardian.** Non-thinking generation is `<score> yes </score>` or `<score> no </score>` (the model card's parser reads the `<score>` tags). [MEASURED] The prompt ends `<|end_of_role|>`; the first generated token is `<` (46), then `score` (5020), `>` (48), then the verdict: ` yes` 9155 and ` no` 1289 are single tokens (`yes` 7134 and `no` 1347 without the space). Reading the verdict needs `<score>` (3 tokens) appended to the prompt. Which spelling (with or without the space) the model emits was not measured; no model was run.
- **Llama Guard 3.** The 8B card says classifier scores use the probability of the first token as the unsafe-class probability (card line 209) and Meta's page says the first output line is `safe` or `unsafe`. Whether `safe` and `unsafe` are single tokens in the Llama 3 vocabulary, and whether the first generated token is a newline token rather than the word (the cookbook template ends at `<|end_header_id|>` with no blank line), is **NOT VERIFIED** (tokenizer gated, and the docs page does not state token ids).

## What a product would have to build

A per-guard public template and verdict-row definition, registered as a new policy id with its own calibration; a larger rung (Qwen3Guard) or a 256 rung or chunk plan (Granite); for both, a forced public suffix (`Safety:` or `<score>`) that the code's `suffix == (4,)` check does not allow today; and for Llama Guard, the licence-accepted tokenizer to count at all.

## Test that would confirm or kill

Confirm: with the owner's own licensed copy of the Llama Guard 3 tokenizer, render the cookbook template with a 40-token input and count template-only tokens; kill the "does not fit T = 128" reading only if the count is below 128 - 40 - 1. For the two measured guards, the figures die if `apply_chat_template` on the same local files gives a different length from 297 and 116 (it matched on the files used; other revisions of the repositories were not checked).

## Not verified

Llama Guard 3 token counts and verdict ids; the guards' counts on later repository revisions; whether the installed profile's policy texts equal the 72/72/78-token texts; any 256 or 512 profile; the multi-turn, response-check and custom-criteria templates (shorter or longer); Qwen3Guard's streaming variant.
