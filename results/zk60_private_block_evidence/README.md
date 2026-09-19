# Private block on the custom line — the security owner's own verification run

Run by the interactive Claude Fable 5.1 session (the security owner) on
2026-09-19 at 05:10–05:14, on lane `zk60-private-block` at commit `95756c8`,
after a delegated Opus agent reported stages S3a–S4 complete. Nothing here was
taken from the agent's report: every line below is what I ran and saw.

**What this is.** The first complete private transformer block on the custom
(hashline) line at the tiny geometry (T32 tokens, width 16, two heads, one KV
head, feed-forward width 16): attention, the second RMS norm, the SiLU
feed-forward and the second residual in one proof, one transcript, no seam,
inputs, outputs and activations hidden, weights public (P1). Public synthetic
fixture, not a trained model.

**What this is not.** Not a privacy acceptance: no whole-proof privacy
property is established, the caller-fixed-root obligation (D8/D11) is open for
both external endpoints, and the rank and slot tools have not yet been run on
this Rust source (disposition condition 4, stage S5). Not a speed result: the
timings are diagnostic, taken on a shared laptop, at a geometry that says
nothing about 8B, and this form deliberately does not use the GPU
feed-forward prover.

## Checks

| Check | Command (every cargo call under `flock -w 540 /tmp/zk-build.lock`, offline, `-j 2`, release overrides as in the ledger) | Result |
|---|---|---|
| accepted files untouched | `git --no-pager diff --stat zk60-attention-compile zk60-private-block -- hashline/src/private_attention.rs hashline/src/private_attention hashline/examples/zk60_private_attention.rs hashline/tests/zk60_private_attention.rs hashline/src/zk.rs hashline/src/layer.rs hashline/src/zk_ffn_fresh_io.rs hashline/src/private_seam.rs scripts tests` | empty |
| existing files edited by the lane | same diff over `hashline/src/lib.rs hashline/Cargo.toml hashline/src/tables_attn.rs` | `lib.rs` +1 line (module export), `Cargo.toml` +7 (dev-dependency), `tables_attn.rs` +7 (the one constant `TAG_ACT = 134`) |
| unit, parity and tamper tests | `cargo test --release --lib private_ -- --test-threads=1` | **38 passed, 0 failed** (11 accepted attention tests, 27 block tests including the tripwire `block_output_cannot_be_chosen` and eight other tamper tests) |
| integration tests, fresh verifier from public data and bytes | `cargo test --release --test zk60_private_block -- --test-threads=1` | **4 passed, 0 failed** |
| prove, one process | `zk60_private_block prove owner_run1` | profile `hashline-zk-mr1/private-block-t32-poc/1`; A 455 rows, H 384, M 50, 34 functionals, opening groups 35 / 9; lookups U8 61,440, exp 2,048, act 512; **receipt 2,816,472 bytes, exactly the design's derived figure**; prove 0.095 s [MEASURED, NOISY-SHARED, diagnostic only] |
| verify, a fresh process, from bytes only | `zk60_private_block verify owner_run1` | `ACCEPT: 2816472 bytes verified in 0.043 s`; three corruptions refused (first root, an argument word, the last path byte) |

I also read the tripwire's source (`hashline/src/private_block/tamper.rs`,
`prove_tampered` and `block_output_cannot_be_chosen`): it tampers `z16` by
one, recomputes `xres2` and both limb pairs so every class proof still
passes, has the endpoint owner commit the **chosen** output so the output
endpoint cannot be what rejects, builds a real receipt (the prover pre-checks
no relation) and requires the **verifier** to reject at the down
requantization slot, with the honest proof asserted to verify through the
same path. That is the strong form the disposition's condition 1 asks for.

## Files

`owner_run1/block_receipt.bin` (2,816,472 bytes) and
`owner_run1/block_expected.bin` (112 bytes): the public receipt frame and the
public endpoint policy only. No input, output, activation, witness or salt is
stored. The prover seeds from the operating system, so a new run gives
different bytes; these are the bytes this record is about.
