# ZK60 private block — implementation progress (lane `zk60-private-block`)

Worktree `/home/victor/wt-zk60-private-block`, branch `zk60-private-block`,
opened from the design lane tip `58f6150`. SOLE WRITER: one implementation
agent at a time. This file is the hand-off record: any later agent reads the
stage table, then the log from the bottom, and continues at "precise next
step".

**What is being built.** A COPY of the accepted native private attention
component (`hashline/src/private_attention*`), grown into a complete private
transformer block (attention, `norm_m`, SiLU feed-forward, residual 2) in one
proof with no seam, per
`docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_CONSTRUCTION_DISPOSITION.md` (rulings
R-A, R-B and the six conditions of section 3), `..._CONSTRUCTION.md` (T1) and
`..._CONSTRUCTION_TIER2.md` (T2), with the 22 errata already applied to both
memos. The accepted attention files are NEVER edited: byte identity against
`zk60-attention-compile` is an acceptance gate of every stage.

**This is not a privacy acceptance and carries no speed claim.** Nothing here
establishes a privacy property; D8/D11 stay open (disposition section 5).

## Stages

| Stage | What | Status |
|---|---|---|
| S0 | SCAFFOLD: `private_block` module as a faithful copy under new names, WIP profile `hashline-zk-mr1/private-block-t32-wip/0`, all digest/magic/parameter strings forked | not started |
| S1 | TESTS FIRST: `private-block-kernel` as a dev-dependency; deterministic generator of public synthetic inputs/weights; witness-vs-kernel parity for the attention half (up to `xres1`) over >= 1,000 inputs including refusals | not started |
| S2 | WITNESS AND LAYOUT GROWTH: whole-block layout (A 455 / H 384 rows) and witness (`norm_m`, `g8`, `a16`, `u16`, `h16`, `z16`, remainders, residual 2) with kernel semantics; parity extended to `xres2` and every intermediate | not started |
| S3 | ARGUMENT: the new define arms, slots, sites; the tamper tests of T2-check section 8 | not started (next agent) |
| S4 | The block profile `hashline-zk-mr1/private-block-t32-poc/1`, `BlockPublic` with the E-2 activation-table range check, the output endpoint moved to `xres2`, the tripwire `block_output_cannot_be_chosen` (T1-check section 11.3) | not started (next agent) |
| S5 | The checking tools re-run on the real Rust source (disposition condition 4) | not started (next agent) |

Condition 1 of the disposition (errata E-1) BINDS every stage before S4:
nothing in this module may carry the block profile string, a type named
`BlockPublic`, or an output endpoint on `xres2`, until the feed-forward
relations of T2 are proved in the same commit.

## QUESTIONS FOR THE SECURITY OWNER

(none yet)

## Log

(empty)
