# Presenter script: a private AI answer, proved

**Run it** on a quiet laptop (one command; it narrates itself and saves a transcript):
`tools/demo_present.sh` — Llama-3-8B, 32-token prompt: 538 s (~9 min) of work in the round-11
dry run [MEASURED] ·
`tools/demo_present.sh tinyllama` — TinyLlama-1.1B, 32 tokens, the fast option: 130-132 s of
work in two dry runs [MEASURED] ·
`tools/demo_present.sh 8b-t128` — Llama-3-8B, 128 tokens (the best-fidelity "dg" export):
839 s (~14 min) of work in the round-11 dry run [MEASURED].
If the window closes the demo carries on; the transcript path is printed at the start.
**Quiet the box first:** every step waits for the resource guard, and on a busy box the dry runs
waited 9 to 51 minutes before proving. The summary separates working time from waiting.

## What is being shown (say this first)
An AI model's answer is checked by someone who never sees the question or the answer.
The **prover** runs a public AI model (Llama-3-8B) on a **private prompt** and produces a
mathematical proof that the next word of the model's exact integer version really came from that
prompt and that model. The **verifier** checks the proof using only the public model files; it is
never given the prompt or the answer. Only the **prompt owner**,
who holds a private opening file, can see the answer. Nobody has to trust the prover.

## What each step proves, and what it hides
| Step (on screen) | What it shows | What stays hidden |
|---|---|---|
| 1 Safety pre-check | No word of the prompt is known to break the integer model (a convenience; the proof refuses such prompts anyway) | the check runs on the owner's side |
| 2 Prove | Every layer of the approved model was run on one hidden prompt; each step is sealed; the prover checks its own work before writing anything | the prompt, every intermediate number, the answer |
| 3 Verify | The proof is valid for exactly this approved model; a forged or altered proof is rejected | the verifier sees the proof only: no prompt, no answer |
| 4 Open the answer | The owner re-checks the proof, then opens the answer it sealed (8B ho00: token 11, ",") | nobody without the opening file can open it |
| 5 Confirm the prompt | The proof was made from the owner's own prompt, not another one | — |

## Honest numbers (laptop, Intel Core Ultra 9 185H, CPU only, no GPU)
All [MEASURED], n = 1 unless marked; "shared box" = other jobs were running.

| | TinyLlama, 32 tokens | Llama-3-8B, 32 tokens | Llama-3-8B, 128 tokens |
|---|---|---|---|
| proving, whole next-word run (prove / with model loading, the sealing pass inside) | 68-71 / 81-86 s (two dry runs, round-9 binary) | 216.8 / 295.8 s (dry run, round-11 binary; no other guarded job running) | 437.3 / 568.5 s (dg export, dry run, round-11 binary; one 2 GiB fidelity job beside it) |
| ordinary inference, same CPU, tuned 8-bit engine | — | ~1.55 s | ~5.6 s |
| **the whole next-word proof the demo shows** ÷ ordinary inference [COUNTED] | — | **~140x** (prove) to **~191x** (with loading) | **~78x** to **~102x** |
| 32 layers alone (no prompt lookup, no word choice), quiet box, ÷ ordinary inference [COUNTED] | — | ~100x (156 s) | ~77x (433 s) |
| verifying (all three verifying steps exit 0) | 10-11 s | 50 s | 55 s |
| proof size | 255 MB | 471 MB | 928 MB |
| peak memory while proving | 1.3 GiB | 3.4 GiB | 8.0 GiB |
| prompt tokens proved per second (with loading) | 0.37 | 0.11 | 0.23 |

Quote the ratio of what the screen shows: **about 140-190x for the full next-word proof at 8B,
32 tokens, and about 80-100x at 128 tokens** (about 100x / 77x for the 32 layers alone on a
quiet box). Both 8B columns are the round-11 dry runs of `demo_present.sh` on the round-11
binary [MEASURED, n = 1]. Every step exited 0, and the owner opened token 11 (",") at both
lengths. The "with loading" figure includes the self-check "sealing pass", in which the prover
re-runs the integer model once before writing anything: 36.3 s at 32 tokens, 90.6 s at 128. The
independent reviewer's round-9 run at 32 tokens (288.7 s, REVIEW6) agrees within 3%.

The goal is **50 proved tokens per second** for private 8B on one high-end GPU. Today we are
about 200x short of that on this laptop's CPU. The GPU path for this proof is not built yet.
Reaching 50 needs the whole prover running on the GPU close to the hardware's limits, plus some
design changes (the speed plan, `docs/zkmatrix-poc/ZK60_SPEED_PLAN_20261017.md` §5).

## What NOT to claim
* **Not "privacy is certified" for this demo.** The only privacy acceptance (decision D33,
  Victor, 2026-10-19) covers one artifact: the 22-layer TinyLlama block stack at calibration
  pg_rot1, 32 tokens, built from tree R7. Outside it: Llama-3-8B, the b4 and b7voc0
  calibrations shown here, the newer build tree, and the next-word stages (prompt lookup, final
  norm, head, word choice). The next-word privacy statement is still in review, and so is the
  re-check of D33 on the newer tree. Say instead: "designed to hide; the formal privacy sign-off
  so far covers the smaller model's core; the rest is in review."
* **Not "same quality as the original model".** The bar (D32) is perplexity within 1.01x of the
  float model, LAMBADA accuracy at least 99% of it, and zero refusals. Today the proved integer
  models score about 1.2-1.3x perplexity (TinyLlama), 1.6-1.8x (the 8B b7 family shown here)
  and 1.28x with LAMBADA 0.69 vs 0.78 (the best 8B export, dg).
* **Not "fast" or "production ready".** It runs on CPU, about 140-190x slower than ordinary
  inference for the full next-word proof shown at 32 tokens and 80-100x at 128 (about 100x for
  the 32 layers alone on a quiet box), and has no GPU yet.
* **Not "hides the model".** In this phase the model weights are public. Hiding the weights is
  a later phase (P3).
* **Not "hides the prompt length".** 32 or 128 tokens is public. The hidden-length variant is
  not built.
* **Not "audited".** This is a research prototype. It has independent internal review rounds,
  not an external audit.

## Five likely questions
1. **What exactly does the proof guarantee?** That a specific, publicly fingerprinted model
   produced this next word from the prompt the owner holds, with every layer computed exactly.
   A cheat is rejected except with odds below about 1 in 2^95 per run. That is the MVP's
   accepted soundness target (D27); the next milestone is 100 bits and the product target 128.
2. **Why not just trust the AI provider, or use secure hardware (TEE)?** A TEE asks you to trust
   the chip maker and that the hardware has no flaws. Here the check is pure mathematics: anyone
   with the public model files can verify, and the verifier never sees the data.
3. **How fast is it, and when is it practical?** Today: minutes per answer on a laptop CPU,
   about 140-190x ordinary inference for the full next-word proof at 32 tokens and 80-100x at
   128 (about 100x for the 32 layers alone). The target is 50 proved tokens/s on a high-end GPU. That needs
   the whole prover running on the GPU close to the hardware's limits, plus some design changes.
   We do not have a date we can stand behind.
4. **Is the privacy actually proven? Who checked it?** For one artifact, yes: the 22-layer
   TinyLlama block stack at calibration pg_rot1, 32 tokens, built from tree R7. That is a
   written argument that survived three independent review rounds, accepted by the project
   lead (D33). Its extension to the newer build trees has been re-checked and reviewed and is
   pending his word. The rest of what this demo shows is outside D33:
   * the TinyLlama option (calibration b4, on the round-9 code);
   * both 8B options;
   * the next-word stages, whose privacy statement is drafted and in review.
5. **Does making the model provable make it worse?** Somewhat, today. The provable integer
   version scores below the original (1.2-1.8x perplexity). The bar is "no measurable
   degradation". About half the gap at 8B has been closed, and the calibration work continues
   at no cost to proving speed.

Sources: `PROGRESS.md` here; 8B columns: the round-11 dry runs
(`~/zk60-owner-private/token-io/demo-present/8b-t32-dryrun-r11b/` and `.../8b-t128-dryrun-r11/`,
`transcript.txt` and `logs/`); CPU baseline
`results/zk60_cpu_inference_baseline_20261019/README.md`; decisions D32 / D33 in
`docs/zkmatrix-poc/ZK60_DECISIONS.md`; fidelity in `docs/zkmatrix-poc/MVP_STATUS.md`.
TinyLlama row: the round-10 dry runs. Transcript of the final script:
`~/zk60-owner-private/token-io/demo-present/tinyllama-dryrun-r10b/transcript.txt`; the first run
is `.../tinyllama-dryrun-r10/`.
