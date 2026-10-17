# Rulings open for Victor, 2026-10-17 (one page)

**ANSWERED 2026-10-17 19:28 UTC: "all recommendations yes" (Claude console;
also by Telegram at 19:24).** Recorded in `ZK60_DECISIONS.md` as D19b and D23
accepted, and new D25 (T1–T8).

Written 19:00 UTC by the coordinating Claude session; T2 amended 19:22 after
the adversarial check of the token design (`results/zk60_token_io_design_20261017/check/CHECK.md`:
core sound, three binding changes being folded in). Each item is
one plain question with a recommendation. A one-line answer is enough, e.g.
"all recommendations yes", or "D23 yes, T3 no: ...".

## Already pending (carried from September)

**D23 — never refer to an accepted receipt's endpoint fingerprints later.**
A private receipt ends with two public fingerprints of its hidden input and
output. The privacy argument holds only while no later artifact registers,
republishes or chains those two fingerprints; once something does, a harder
open question applies (D8/D11). It limits how receipts are used, not how they
are built. Nothing today does this. **Recommend: yes.** It is also a condition
for any privacy acceptance of the trained stacks and for the token hand-off
(T5 below). One-pager: `ZK60_RULINGS_FOR_VICTOR_PRIVACY.md`.

**D19b — the model behind the hash keys.** The keyed BLAKE3 separation (D19a)
rests on a slightly stronger assumption than the one you accepted in D19 (the
compression function is ideal even when the attacker picks its starting
value). Nothing measurable changes. Alternative: one prefix byte per domain
instead of keys (about 0.5% more hashing and a re-freeze). **Recommend: yes,
keep the keys.**

## New: proving the next token (D13's next milestone)

Design: `results/zk60_token_io_design_20261017/DESIGN.md`. It adds an
embedding stage before block 0 and a final-norm + head + greedy-choice stage
after the last block, inside the same private run. Cost at Llama-3-8B, T32:
about +3% proving time, +4.4 MB receipt [MODEL/COUNTED]; negligible at T512.

- **T1 Output.** First prove ONE hidden next token per run (mode i); prove a
  whole greedy continuation in one pass (mode ii) later. **Recommend: yes.**
- **T2 Prompt length.** Keep the prompt length hidden in mode (i). The
  adversarial check (19:20 UTC) found that hiding it safely means sealing the
  length inside the input's fingerprint, so the owner can check the prover
  answered the right prompt; otherwise a cheating prover could answer a
  shorter prefix. That costs a small endpoint geometry change (a security-owner
  ruling, R9), not proof time. Mode (ii) would start with public lengths.
  **Recommend: yes, hidden and sealed.**
- **T3 Ties.** When two tokens have the same top score, the lower token id
  wins (numpy's rule). **Recommend: yes.**
- **T4 Integer head.** The proof computes the head in integers. Accept it if
  it picks the same token as the float head on at least 99% of held-out
  positions; otherwise use one scale per vocabulary row. **Recommend: yes, at
  99%.** (Fidelity measurement running.)
- **T5 Owner hand-off.** The verifier never sees the token; the prover hands
  the owner the token plus the opening of its fingerprint over a private
  channel, and the owner checks it against the receipt. Needs D23.
  **Recommend: yes.**
- **T6 Several tokens.** Repeated one-token runs are not a proved token
  stream, and every claim must say so. **Recommend: yes.**
- **T7 Model identity.** The receipt names the embedding and head by the
  export's digest (as already accepted for the blocks); it does not prove the
  export came from the named checkpoint. **Recommend: yes.**
- **T8 First token.** The proof forces the beginning-of-sequence token at
  position 0. **Recommend: yes.**

## Added 20:10 UTC — G.0-2, the soundness target (open)

**What it is.** Today's recount (register D15, two dated notes) puts the
private trained stacks at about 97.4–98.2 bits whole-run (the chance a forger
gets one false proof accepted, summed over every check in the run), and an
8B run at the 512-token workload at about 94.7 bits; read as a forger's work
per attempt it is about 99.7. Above about 95 bits the limit is the lookup
checks, and every way to raise them in today's design adds a second set of
committed lookup helpers, costing about 30% of the GPU throughput the 50
positions/s goal needs (memo: `results/zk60_soundness_recount_20261017/MEMO_G02.md`).

**Proposed ruling.** State the target per run at a named workload (today
Llama-3-8B, T = 512) as a whole-run figure with the work-factor reading beside
it. **MVP: about 95 bits whole-run accepted as a recorded deviation**, next to
the zkVM line's 97 conjectured (D3); **next milestone 100 bits**, preferably
through LogUp-GKR with a 256-bit lookup challenge (no throughput cost if its
privacy design works out; otherwise about −33%); **product 128**.
**Recommend: yes.** If you want parity with 97 now, it costs about 31% of the
throughput (57 → 40 positions/s on the 5090 roofline at 40% bandwidth).

**ANSWERED 2026-10-17 20:21 UTC (Claude console): "Go for (b), as well as
G.0-2 yes."** Recorded as D27 (soundness target: about 95 bits whole-run for
the MVP at the named 8B T512 workload, 100 next, 128 product) and as an
amendment to D25 T4 (per-row integer head with 12-bit multipliers, accepted
when it matches the float head wherever the float top-2 margin is at least
0.3 logits; the 99%-overall threshold is withdrawn). Victor: "100%
reliability always is probably not necessary for most of the applications of
this technology."
