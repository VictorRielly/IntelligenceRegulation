# 2026-09-26 — KV reuse: first hypothesis, counterexample and next experiment

**KV caching can avoid re-executing an already computed causal prefix, but
it cannot make each new position's FFN free or establish that a private cache
is correct.** For a single ordinary prefill that already computes each
position once, there is no repeated-prefix work to eliminate. The useful
research question is whether incremental witness construction and larger
proof windows reduce *measured complete-proof cost* enough to offset state
authentication, retention and composition costs.

This supports the current >=50 proved-position/s workload target; no fixed
512-position acceptance limit or GPU performance prediction is assumed.
No production source, protocol, shared explorer state, or GPU was changed.

## First falsifiable hypothesis

**H1:** within one fixed, supported proof window, an append-only witness
builder can reuse old per-layer values and produce exactly the original
integer relation and refusal behavior, while avoiding any repeated-prefix
execution in a later streaming driver. Keep state private inside that one
unfinished proof. Do not publish intermediate roots or claim cross-receipt
cache continuity at this stage.

Expected benefit has a precise boundary. A driver that recomputes every
prefix of lengths 1 through N processes N(N+1)/2 positions through its FFNs;
a correctly cached driver computes those N positions once. Against the
existing **single** N-position prefill, this is no FFN saving. Every new
position still executes and proves all model layers, including its FFN,
norms, projections, attention against retained keys, and cache update.
Batching B new positions per proof might amortize a measured fixed proof
cost F toward F/B per position, but neither F nor a gain is established
here. Count only newly completed positions and include state/proof overhead.

Separate three reusable objects:

| Object | Reuse means | What still must be checked |
|---|---|---|
| Public static weights and valid public setup | Same model/profile identity; existing permitted weight cache | Model binding and every request's arithmetic/opening work |
| Private per-layer K/V values | Same logical prefix, absolute positions, layer, head map and integer calibration | Correct origin, unchanged old entries, exact appended entries, reads bound to that state |
| Proof state across windows | A verified transition from one hidden state to the next | A privacy-preserving composition argument, fresh blinding, and authenticated continuity |

Reusing K/V values does **not** authorize reusing masks, pads, salts or a
private commitment's opening budget. Private weights under P3 have their
own cache/security obligations; public-weight caching is not a precedent
for private KV root reuse.

## Reproduced negative result: K/V-only checks change the frozen relation

`private-block-kernel/src/lib.rs:545` computes all `(head,t,j)` scores,
including masked future pairs, and `:560` range-checks them **before** causal
softmax. At shift 6 the exact score is `floor((dot + 32)/64)`, required to
lie in [-127,127]. Consequently equal successful causal outputs do not
establish equal proof statements or refusal behavior.

The new [synthetic experiment](../experiments/kv-future-score-20260926/experiment.py)
uses the frozen T32/H2/Hkv1/head-width-8 score geometry. Set an old rotated
query to `(127,32,0,...)`, a future rotated key to `(64,1,0,...)`, and all
other rows to zero. Every coordinate is individually in range, but their
masked future dot product is 8160, which requantizes to **128**. All 1,056
lower-triangle score sites pass; the complete 2,048-site relation refuses.
Checking the new key against **retained old Q** catches the omitted failure.

Run from the repository root:

```sh
python3 research/zkp-efficiency/experiments/kv-future-score-20260926/experiment.py
```

[Result and source hashes](../experiments/kv-future-score-20260926/result.json):
six cases pass, including positive/negative future violations, valid ±127
boundaries, a visible violation and zeros; 18 signed-requant boundary
checks pass. All six retained-Q incremental score maps equal their dense
maps exactly. This run used about 0.036 seconds and 15,268 KiB RSS.
**These are synthetic post-RoPE score operands, not an established
upstream-reachable full-block witness. No native kernel, proof or model ran.**

The main agent independently reran the same source into a separate temporary
result directory: all six cases and 18 signed-requant boundary checks passed
again. This validates reproducibility of the small arithmetic experiment,
not native/full-block equivalence or a throughput improvement.

Preserving the frozen relation therefore needs old rotated Q or its
recomputation, as well as K/V: when a key arrives, validate its pairs with
older queries. Across the whole window this still covers the full square
score domain. Earlier outputs cannot receive final acceptance under that
full-window statement before all future-pair checks complete. Tokenwise
execution can also encounter refusals in a different order from the original
stagewise kernel; exact equivalence must compare `Result` and error sites,
not only accepted outputs. The script restores canonical order at the score
site only; it does not establish full-block error-order equivalence.

## Next bounded experiment and falsification

On the existing synthetic T32 fixture, add a **research-only** witness
schedule oracle for chunk lengths 1, 2, 4, 8, 16 and 32. Compare one complete
run against append processing with retained Q/K/V and deferred future-pair
checks. Use the unchanged public RoPE table at each absolute position;
restarting position zero per chunk is a negative control. Preserve exact
integer accumulation, rounding, support, lookup and range rules.

Acceptance for this experiment: all per-stage values needed by the current
relation agree, final outputs agree, and both successful and refusing
fixtures have the same result/error site under canonical execution order.
Controls: mutate an old K or V; swap query/KV head mapping; reset the RoPE
offset; reuse state from another layer/model/prefix; drop an old-Q/new-K
check; and introduce simultaneous score/FFN failures to expose refusal-order
changes. First find an upstream-reachable masked-score counterexample or
establish why the bounded fixture family excludes one; neither outcome may
be inferred from the present score-only experiment.

Record operation counts and retained bytes before timing. H1 fails upon any
unexplained value/refusal mismatch. A speed hypothesis fails if eliminated
recomputation is absent in the real driver, or is outweighed by cache
authentication, old-Q retention, openings and proof-window overhead. Only
after the relation passes should the native owner compare accepted receipt
behavior, blinding consumption, verifier rejection controls and whole-workload
clocks. This experiment does not itself authorize a new profile/privacy claim.

## Cross-window proof state is a separate construction

D8/D11 keep the caller-fixed-root and prior-history obligations open; D11
records actual leakage from two openings at the endpoint geometry. D18
accepts prover-sealed endpoints for the MVP, **not** chaining separately
finished receipts through their roots. D23 is recorded as a proposed
operational restriction and a hypothesis of the toy statement, not an
accepted new user ruling. It does not authorize KV reuse. A same-window
experiment avoids this new public interface but does not close these issues.

A later transition statement would bind model/profile, layer state, absolute
position/count, exact old-prefix retention and appended K/V, then relate
the hidden input state to hidden output state. Fresh commitments alone do
not prove they contain the same old prefix. Candidate directions are the
recorded salted-handle construction with an in-proof binding gadget, or a
reviewed incremental proof system. Their actual costs and zero-knowledge
composition must be assessed; recursive aggregation does not remove the
underlying new-token computation or repair a mismatched integer relation.

## Primary sources inspected and next questions

Meta's reference `Attention.forward` writes rotated new keys and values at
`start_pos`, reads the retained prefix, and computes attention for the new
query rows; `TransformerBlock.forward` still runs their FFN. This confirms
the ordinary inference reuse pattern, not this repository's exact integer
or proof equivalence. [Meta Llama 3 reference implementation](https://github.com/meta-llama/llama3/blob/main/llama/model.py)

Nova provides a primary construction for incrementally verified computation.
HyperNova studies incremental CCS relations and explicitly treats proof
randomization for zero knowledge. These are candidates for researching the
state-transition obligation, not compatible drop-in replacements or measured
8B speed results. [Nova](https://eprint.iacr.org/2021/370),
[HyperNova](https://eprint.iacr.org/2023/573).

TensorBlock's Proof-of-Cache README describes KV sampling/matching. That
description does not establish a complete zero-knowledge forward-pass proof;
no equivalence to the project's acceptance contract was found or assumed.
[Maintainer README](https://github.com/TensorBlock/Proof-of-Cache)

Sources accessed 2026-09-26. Nova's ePrint history: received 2021-03-22,
last revision 2024-07-20. HyperNova: received 2023-04-23, revised 2026-02-20.
Repository file dates/full commits were not pinned; source code was read,
not downloaded or executed, and no external implementation is adopted.

The next researcher questions are: **Is prefix re-execution a measured cost
in our intended driver? How much cost remains per new token after reuse?
Can the frozen full-square score checks be scheduled cheaply without keeping
all Q? What proof-window size minimizes recurring overhead while preserving
latency and memory? What is the concrete private-state binding relation and
its cumulative opening/masking budget?** Each answer should produce an exact
counter, a differential test or a bounded negative result before a speed claim.
