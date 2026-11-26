# A22: the installed profile's policy prefix lengths

Applications researcher, 2026-11-26 UTC. Triage material, not a work order.

## Question

A14 found the 72 / 72 / 78 prefix lengths (and the chunk sizes 55 / 55 / 49) only in the R13 privacy statement (v3 line 204). For the profile the app installs, which policy texts, tokenizer and prefix and suffix does it use, and do the counted lengths equal those figures?

## What was read, and how

Read only; nothing was written under `apps/proven-media`, no service was started or contacted, nothing fetched, no weights.

- **Which profile is installed.** `deploy.json` profile `shieldstral-mac-fast-w16r2` (`prover_mode` `shieldstral-fast-w16r2`, 128 context tokens, `category_geometry` 55 / 55 / 49, overlap 8, max 8 chunks each, `max_content_tokens` 336). [COUNTED] In `w16r2_runtime.py:132-135` its `categories()` and `templates()` return the baseline's; `shieldstral_fast_runtime.py:123-128` returns `shieldstral_runtime.categories()` and `.templates()`. So the installed profile has no templates of its own: it takes the reviewed R13 runtime's.
- **Where the prefix comes from.** [COUNTED] `shieldstral_runtime.py:53-64`: `templates()` checks that `results/zk60_shieldstral_export_20261026/category_policy_candidates.json` has sha256 `POLICIES_SHA`, then for each category checks that the policy `.txt` file equals `prefix_text + ' {{private_content}}' + suffix_text + '\n'` and has the pinned sha256, and builds the `CategoryTemplate` from that JSON's `prefix_ids`, `suffix_ids` with context 128, overlap 8, max chunks 8. The app therefore does not tokenize the `.txt` files at run time; it uses the pinned ids, and the text check ties the displayed file to them.
- **Chunk formula.** [COUNTED] `shieldstral_text.py:85-86`: `chunk_size = context_tokens - len(prefix) - len(suffix)`; `:76` requires `prefix[0] == 1` (BOS id, so it is counted) and `suffix == (4,)`.
- **Tokenizer.** [COUNTED] `shieldstral_runtime.py:25-26`: `$HOME/models/shieldstral-1.0-3b/tekken.json`, overridable with `PM_SHIELDSTRAL_TOKENIZER`; pinned by sha256 in `shieldstral_text.py:16`. That default path does **not exist on this machine** (`/Users/victorrielly/models` holds two other directories). A local copy exists at `results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tekken.json`; [MEASURED] its sha256 is `ceb11e85e44d7c91d051604d636d97b05aee59a907a0dc96a3c6e557d9634e18`, equal to the code's pin and to the R13 statement's `ceb11e85e44d7c91`. I used it.
- **Counting script.** One script reproduces every count below. It imports the app's own `shieldstral_runtime` and `shieldstral_text` unchanged (so the app's own `templates()` checks run), re-tokenizes the displayed prefix text with the pinned tokenizer, and writes nothing. It needs `mistral_common`, which neither the system `python3` nor the frugal-lm interpreter has; I used the interpreter of the project's own `a28-tools` virtual environment, which has it, with `-I -B` (isolated, no bytecode written), installing nothing. Its output is saved at `/private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/a22-scripts/count_prefixes.out`.

```
env PM_SHIELDSTRAL_TOKENIZER=/Users/victorrielly/IntelligenceRegulation/results/zk60_astra_20261026/app_decision_refresh_20261104/tokenizers/tekken.json /Users/victorrielly/zk60-artifacts/a28-tools/venv/bin/python3 -I -B /private/tmp/claude-501/-Users-victorrielly-IntelligenceRegulation/39cab447-559b-4f13-981d-d0346f20681a/scratchpad/a22-scripts/count_prefixes.py
```

(A second helper, `show_prefix.py` in the same directory, prints one category's full prefix text and control-token positions; it is not needed for the counts.)

## Findings

All values MEASURED by the script above. The prefix count includes the BOS id (1); the suffix is the one id 4 (`[/INST]`).

| Category | Policy file (bytes, sha256) | Prefix | Suffix | Chunk size at 128 | R13 statement (P0 / chunk) |
|---|---|---|---|---|---|
| sexual | `apps/proven-media/policy/shieldstral-moderate-sexual-v1.txt`, 383, `e702f604f893d95c773dda6b1cbd30c4c3a253555075c623bc5e800d164c0822` | 72 | [4] (1) | 128 - 72 - 1 = 55 | 72 / 55: equal |
| violence | `.../shieldstral-moderate-violence-v1.txt`, 393, `eb124ee93d46d2f716fb6beee54a8f26d21883a2b87daa721d9cbe92e5131128` | 72 | [4] (1) | 55 | 72 / 55: equal |
| hate | `.../shieldstral-moderate-hate-v1.txt`, 423, `c9a65df1b6a57e0e1aa5a497949aaae2b8c00843a7b3b465d69f9ee811b68f89` | 78 | [4] (1) | 128 - 78 - 1 = 49 | 78 / 49: equal |

- **All three equal the R13 figures.** The three file hashes equal the app's `POLICY_SHAS` (so the installed files are the pinned files); `category_policy_candidates.json` (17,049 bytes, `b1cfcda9ea4f48ce3b95d871b81f77c6cd27f94daa85fc618ec8e54222b44314`) equals `POLICIES_SHA`; the app's `templates()` ran without refusing. The JSON's own `content_tokens_by_T` field also reads 55 / 55 / 49 at T = 128 (and 183 / 183 / 177 at T = 256).
- **The deployed geometry agrees.** `deploy.json` lists 55 / 55 / 49 and `max_content_tokens` 336. [DERIVED] Per category, chunk + 7 x (chunk - 8): sexual and violence 55 + 7 x 47 = 384, hate 49 + 7 x 41 = 336; the profile's maximum is the smallest, 336, which equals the number in `deploy.json` and the R13 statement's "336 tokens (22 runs)".
- **The prefix is independently reproduced from the displayed text.** The prefix text is the control markers `<s>`, `[SYSTEM_PROMPT]`, `[/SYSTEM_PROMPT]`, `[INST]` (ids 1, 17, 18, 3) around two plain-text parts. Encoding the two parts with the pinned tokenizer (control markers not parsed, as the app's encoder does) gives, for sexual and violence, 31 + 37 plain tokens + 4 markers = 72, and for hate 31 + 43 + 4 = 78; each list equals the pinned `prefix_ids` exactly. So the pinned ids are what this tokenizer produces from the displayed text (a check the earlier handoff did not do).
- **Why the three are the same figures.** [COUNTED] The installed profile does not derive its own prefix: it reads the same JSON as the R13 profile. The R13 statement's lengths and the installed lengths are therefore the same numbers from the same source, and this tick confirms them by tokenizing. The difference between the profiles (profile sha `9464388...` against R13's `2ba468f9...` in `shieldstral_runtime.py:19`) lies in the model export and prover, not in the prompt.

No difference was found between the installed files or prefix and what the R13 statement describes, so there is nothing to explain.

## What a product would have to build

Nothing from this finding alone. A new or changed policy wording would need a new registered template (prefix ids, `category_policy_candidates.json` hash, policy-file hash), and the chunk size follows from the prefix length by the formula above: every extra prefix token takes one content token from each chunk (a 78-token prefix leaves 49). A deployment on another machine needs the tokenizer file at the path the code expects or `PM_SHIELDSTRAL_TOKENIZER` set; here the default path was absent.

## A test that would confirm or kill this

Confirm: the same script on a clean checkout with the tokenizer at the default path; the lengths die if any of the three file hashes, the candidates-file hash or the tokenizer hash differs from the pins above. A separate test that would also cover the other side: take a stored receipt of the installed profile and compare its statement's `template_prefix_ids` and `template_suffix_ids` with these templates (the app's `check_category_coverage` does this at run time, `shieldstral_text.py:154-155`; I did not run it).

## Not verified

- That the installed native binary and its W16R2 export use these same prefix ids: I read the app's side only. The app checks each receipt's template ids against its own at run time, but I opened no receipt and ran no check.
- That the policy files in the repository are those actually deployed: `apps/proven-media/policy/*.txt` showed no change in `git status --short` during this tick, and their hashes equal the pins; I did not look at any deployed copy elsewhere.
- Token counts for any other policy wording, other tokenizer revisions, or the `pm-cat-*-v0.txt` stub policies in the same directory (they belong to the stub profile, not this one).
- The tick used a `mistral_common` interpreter outside the two named ones; its version was not recorded. The result (rebuilt ids equal the pinned ids) does not depend on it beyond that equality, but a different library version could tokenize differently.
