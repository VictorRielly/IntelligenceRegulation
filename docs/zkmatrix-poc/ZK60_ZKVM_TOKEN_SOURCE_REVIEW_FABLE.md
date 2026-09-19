# Security owner's review of `zkvm-model/` — the token-generation receipt profile and its source pins — 2026-09-19

**Status: COMPLETE** (2026-09-19). Source read at `HEAD` `2abff86`; retained
evidence re-verified after the 01:04 reboot.

## 0. What this is and how to read it

| | |
|---|---|
| Author | Claude Opus 5 (1M context), delegated reviewer for the security owner |
| Reviewed | `zkvm-model/` (guest, statement, model, host, wrap, Cargo files, README), `private-model-kernel/`, the shared pin crate `zkvm-native-tools/`, and the retained public evidence of the first token-generation proof under `results/zk60_loop_20260918/token-integration/` |
| Against | the block review `ZK60_ZKVM_BLOCK_SOURCE_REVIEW_FABLE.md`, the disposition `ZK60_ZKVM_REVIEW_DISPOSITION.md`, Codex's own `ZK60_TOKEN_MODEL_SOURCE_REVIEW.md` (checked, not repeated), `ZK60_DECISIONS.md` D1–D11 and `ZK60_PRIVACY_REQUIREMENTS.md` |
| Verdict | **Consistent with D5 and the disposition. No defect in the code.** One defect in the *evidence record* (§10.1), eleven hardening items and three wording items. The retained 785-byte Groth16 receipt re-verifies today in a fresh process (§9). This is a source review, not a privacy acceptance: **D7 — whether the salted-SHA-256 endpoint profile is accepted as the P1 statement — is still Victor's ruling and is neither accepted nor rejected here.** |

Plain words for anyone joining: a *receipt* is the small public file that proves
a computation happened; a *journal* is the short public message that receipt is
about; a *policy* is the journal the verifier expects, obtained separately from
the receipt; an *image ID* is the fingerprint of the exact program that ran
inside the zkVM; an *endpoint* is a hash that stands in for a hidden value
(here, the tokens) so the proof can talk about it without revealing it. A
*salt* is a secret random string mixed into that hash so nobody can guess the
hidden value by trying candidates.

Everything below is line-by-line source reading plus read-only inspection of
retained files and two verifications that take milliseconds. Nothing was built,
proven, downloaded or committed. No salt, token, activation, inner receipt or
private log is quoted anywhere in this document; only public digests and public
files appear.

## 1. Source pins: what the retained receipt is bound to, and what is not pinned

### 1.1 Uncommitted changes

`git --no-pager status --short zkvm-model private-model-kernel` prints
**nothing**: both trees are exactly at `HEAD` (`2abff86`, 2026-09-19 01:12).
The same command over the neighbours shows `zkvm-native-tools` and
`private-block-kernel` clean, while `zkvm-block/README.md`,
`zkvm-block/host/src/main.rs` and `zkvm-block/wrap/src/main.rs` carry Codex's
live uncommitted edits. Nothing in this review touched any of them.

The guest-affecting sources were last changed by `db021ba` ("Checkpoint
verified Groth16 block and token-model proving pipeline", 2026-09-18 20:05).

### 1.2 Current source bytes against the build record

One `python3 -c` block hashed all 36 files listed in
`results/zk60_loop_20260918/token-integration/token-build-source.json` with
`hashlib.sha256` and compared. **32 of 36 match. Four differ**, all on the
wrap side and none of them able to change the guest:

| File | Recorded in `token-build-source.json` | Current (= `HEAD`) |
|---|---|---|
| `zkvm-model/wrap/src/main.rs` | `7f9780475db8…0ef2ea` | `80139fe9865a…4cd96c7` |
| `zkvm-model/wrap/Cargo.toml` | `6f44733f3087…ec8f6670` | `d91e3c8f2dfb…61b502b` |
| `zkvm-model/Cargo.lock` | `e3eeee908bf6…d43065f82` | `3f22369e1b31…ca0b5459b` |
| `zkvm-model/README.md` | `1f9a35fd24b9…be701b472` | `14740f63b2e7…ecb27671` |

This is not drift after the fact; it is the record being **stale at the moment
it was written**. `token-build-source.json` was written at 19:31. The wrap
source and its manifest were edited at 19:35:01 (to add the pinned native-tool
check through the new `zkvm-native-tools` crate — compare Codex's review, which
still says "the wrapper checks native filenames, not their provenance or
SHA-256"), and the wrap binary was built at 19:37. The binary's own dependency
file, `zkvm-block/target/release/zk60-token-wrap.d`, lists
`/home/victor/IntelligenceRegulation/zkvm-native-tools/src/lib.rs` as an input —
a file the recorded `7f9780…` version does not reference at all. So the wrap
binary that produced and verified the public receipt was built from the
**current** source, and the record's wrap rows describe a version that was
never used. The README was edited later still (19:39) and is documentation
only. The host row is consistent: the recorded
`host_sha256 a4bf119bd0d0…c3f92d40` equals the SHA-256 of the surviving
`zk60-token-host` binary today, and `zkvm-model/host/src/main.rs` still hashes
to the recorded `6529f611dfda…21073c7`.

Every guest-affecting file matches: `methods/guest/src/main.rs`
(`28d1c506…`), `methods/guest/Cargo.toml`, `methods/guest/Cargo.lock`,
`methods/build.rs`, `methods/src/lib.rs`, `statement/src/lib.rs`
(`75e84556…`), `model/src/lib.rs` (`d7beacb6…`),
`private-model-kernel/src/lib.rs` (`a7053d2e…`),
`private-block-kernel/src/lib.rs` (`9e7c9bff…`) and both kernels' manifests.
Independently, both surviving binaries print the recorded image ID (§9), which
is the strongest single check that the guest is unchanged.

### 1.3 The published artifact set against its own SHA256SUMS

All five listed files verify:

```
OK  model.bin               f6b93370104166a7dd56d96beb1dcef88eeede373f70c067177da50ab4f3217c
OK  policy.bin              f8177d93f57f00a813a142c1d3993b6de377e4f6ae87313e5a903c68ed82240b
OK  receipt.bin             94f3ce1438b41b34a086cabd2eafcabf75c492dc2eed9da6555493f1cb9b2cb0
OK  token-proof-v2.json     d9d3ce09bf09047e97e21aa2405bdff316ee9e42d9a72c2293c46397a8e1d9f5
OK  token-v2-image-id.log   7ea9e33a5823967273d3e407f0ea0a3221e18ccd9b50f57e21bff07f27b446b1
```

`README.txt` is present in the directory but **not listed** in `SHA256SUMS`, so
the description of the artifact is itself unpinned; and the file uses absolute
paths, so `sha256sum -c` only works from this box (§10.3). Two further checks
I ran that nothing in the repository runs:

- The published `model.bin` is byte-identical to the exporter's output
  `token-integration/token-synthetic-model.bin`.
- Recomputing the profile's model digest by hand —
  `SHA256("zk60-r0-token-model-v1\0" ‖ "zk60-r0-token-v1" ‖ u64le(13928) ‖
  model.bin)` — gives `df600a214e06c4e8921ebe4e1f914414981641c3197280e9d2fd520cedfa4b60`,
  which is exactly bytes 48..80 of `policy.bin`. So the published weights
  really are the weights the proof is about. **No tool does this check**
  (§10.2, item H4).

### 1.4 What the retained receipt is bound to

Stated exactly, the 785-byte `token_public/receipt.bin` binds:

1. **The program.** Guest image ID
   `3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b`, the
   fingerprint of the compiled ELF
   `zkvm-block/target/riscv-guest/zk60-token-methods/zk60-token-guest/riscv32im-risc0-zkvm-elf/release/private_token.bin`
   (330,196 bytes, SHA-256
   `c137489b5065c7dd32b78e1f0498b0234f9f836290091640140c5f828356b64f`). That
   ELF is compiled from `methods/guest/src/main.rs` plus, as libraries,
   `zkvm-model/statement/src/lib.rs`, `zkvm-model/model/src/lib.rs`,
   `private-model-kernel/src/lib.rs`, `private-block-kernel/src/lib.rs` and the
   locked `risc0-zkvm =3.0.6` guest crates (`methods/guest/Cargo.lock`). All of
   those files are byte-identical to the current checkout (§1.2). The image ID
   does **not** cover the host, the wrap, the runner or the README.
2. **The public statement**, the 144 bytes of `policy.bin` (§2.1), which in
   turn bind the complete model payload by digest, the context nonce and the
   two salted endpoints.
3. **Nothing else.** The receipt does not carry the model file, the tokens, the
   next token, any activation, the salts, a cycle count or a segment count.

The producing/verifying binaries are **not** recorded anywhere in the retained
evidence except the host. For the record, as of today:

| Binary (built 2026-09-18 19:36–19:37) | SHA-256 |
|---|---|
| `zkvm-block/target/release/zk60-token-host` | `a4bf119bd0d0f586de4aff098b6a52bd67770556d45b648f161e394dc3f92d40` |
| `zkvm-block/target/release/zk60-token-wrap` | `338eb2a7b16a8698c646c3d05bb885dcc6f40566f7dd3378acefc7c65d4fa7a7` |
| `zkvm-block/target/release/zk60-block-host` | `c8151dcdd858053115996ecb6a141b76db413c17d00369a4c89d8d0a36016944` |
| `zkvm-block/target/release/zk60-block-wrap` | `3e7b1cd90c4399effc3a812d8e47702a04853a435f9f183aac3b1cffadd5cb59` |

### 1.5 What is NOT pinned: toolchain and build path

Not pinned by anything in the retained evidence: the RISC Zero guest Rust
toolchain version, the `r0vm` binary's own hash (only its absolute path is
required — `host/src/main.rs:151`, `wrap/src/main.rs:132`), the host Rust
toolchain, and the build directory. The five native Groth16 tools *are* pinned,
by length and SHA-256, inside the wrap binary (`zkvm-native-tools/src/lib.rs:37–68`,
called at `wrap/src/main.rs:153`) — this is the one place where the token wrap
is *ahead* of what Codex's review describes.

**The build-path finding applies to the token guest too, and more strongly than
to the block guest.** Reading the sources: the guest crate at
`zkvm-model/methods/guest` declares its own `[workspace]`
(`methods/guest/Cargo.toml:7`) and reaches its libraries by paths that leave
that directory (`../../model`, `../../statement`, and transitively
`../../../private-model-kernel`, `../../../private-block-kernel`). Cargo hands
rustc absolute paths for packages outside the package being built, so every
panic location recorded from those crates (`file!()` in the panic metadata)
becomes an absolute host path inside the ELF. `risc0-build` 3.0.6 applies no
remap: `grep -rn "remap" risc0-build-3.0.6/` finds nothing, and its
`encode_rust_flags` (`risc0-build-3.0.6/src/lib.rs:105–…`) adds only
`-C passes=lower-atomic` and the link-address flags. The Docker path gets
reproducibility a different way — it copies the tree to a fixed `/src` inside
the container (`risc0-build-3.0.6/src/docker.rs:151–154`: `DockerFile::new() … .workdir("/src")
.copy(".", ".")`) — so it never applies outside Docker, and Docker is absent on
this box (D6).

Reading the ELF that actually exists (read-only; nothing was built) confirms
it: the token guest embeds
`/home/victor/IntelligenceRegulation/private-block-kernel/src/lib.rs`,
`/home/victor/IntelligenceRegulation/private-model-kernel/src/lib.rs` — **two**
absolute repository paths, where the block guest had one — and fourteen
`/home/victor/.cargo/registry/src/index.crates.io-*/…` paths, so the image ID
also depends on `$HOME` and on the registry hash directory. (It also contains
`/home/remi/…` and `/root/…` strings, which come from upstream prebuilt
artifacts, not from this box.)

Consequence for the approval record, identical to the block's: image
`3c0631ee…430b` is reproducible **only** from
`/home/victor/IntelligenceRegulation` with this `$HOME`, and must be labelled
"locally built, unreproduced" until either the build path is pinned in the
registry entry or the Docker build is used.

## 2. Profile separation: a block receipt is not a token receipt

### 2.1 The 144-byte policy, field by field

`JOURNAL_BYTES = 16 + 4 * 32 = 144` (`statement/src/lib.rs:11`); the layout is
written by `Statement::encode` (`statement/src/lib.rs:44–52`) and read back by
`Statement::decode` (`:54–60`). Decoded from the retained
`token_public/policy.bin`:

| Offset | Bytes | Field | Value in the retained artifact | What it is |
|---|---|---|---|---|
| 0 | 16 | `PROFILE` | `zk60-r0-token-v1` (ASCII, `statement/src/lib.rs:10`) | the profile tag; a fixed literal, not a hash |
| 16 | 32 | context | `7c956218…d9b0c5b7` | a public random nonce drawn per preparation; ties the two endpoints to one session |
| 48 | 32 | model digest | `df600a21…edfa4b60` | SHA-256 over the complete public model payload (§1.3) |
| 80 | 32 | input endpoint | `a0215eff…e53d51e0` | salted commitment to the 32 private prompt tokens |
| 112 | 32 | output endpoint | `65161f66…c2dbb68e` | salted commitment to the one private next token |

The two endpoint hashes are built by `endpoint()`
(`statement/src/lib.rs:91–104`) as

```
SHA256( "zk60-r0-token-endpoint-v1\0" ‖ "zk60-r0-token-v1" ‖ role
        ‖ context ‖ model_digest ‖ salt(32) ‖ u32le(count) ‖ count × u32le(token) )
```

with `role = 0` for input and `1` for output (`:29–31`), and `count` fixed at
32 for input and 1 for output (`:13`, `:15`, enforced at `:93`). The model
digest uses a *different* domain string, `"zk60-r0-token-model-v1\0"`
(`:18`, `:74–81`), and includes an explicit `u64le` length before the payload,
so no payload can be reinterpreted as a longer or shorter one.

### 2.2 The three independent separations

A block receipt cannot be accepted as a token receipt, or the reverse, for
three reasons that each suffice on their own:

1. **The journal tag.** Both profiles use a 144-byte journal with the same
   field offsets, but byte 0..16 is a distinct literal: `zk60-r0-block-v1`
   versus `zk60-r0-token-v1`. `Statement::decode` rejects any other tag
   outright (`statement/src/lib.rs:55`), and the unit test at `:151–153`
   explicitly feeds it the block tag and requires an error. Since
   `check_journal` (`:62–66`) is a plain byte comparison of the candidate
   journal against the caller's own policy — nothing is parsed out of the
   candidate to decide acceptance — a block journal can never equal a token
   policy.
2. **The image ID.** The token verifier calls
   `verify_with_context(…, PRIVATE_TOKEN_ID)` (`wrap/src/main.rs:71–74`), the
   block verifier its own constant. Upstream compares the receipt's claim
   digest against the expected claim built from that image ID
   (`risc0-zkvm-3.0.6/src/receipt.rs:171–201`), so a receipt for the other
   program fails even if the journals somehow agreed.
3. **The hash domains.** Endpoint and model digests carry `zk60-r0-token-…`
   domain prefixes that cannot begin with `zk60-r0-block`, asserted at
   `statement/src/lib.rs:219–220`. Separation here is computational under
   SHA-256 — Codex's phrasing on that point is correct and worth keeping.

Both directions were exercised in a fresh process today, against the two
retained artifacts (§9): the block verifier refuses the token pair and the
token verifier refuses the block pair, both with
`unsupported statement profile or length` and exit 1 — i.e. refusal happens on
the *policy tag*, before any cryptography runs.

Two related separations, for completeness. The wire formats refuse each other
as well: the token model file is `Z60TOK01`/13,928 bytes and each embedded
block payload is a complete legacy `Z60MDL01`/6,184-byte encoding
(`model/src/lib.rs:12–16`), and the test at `model/src/lib.rs:222–223` requires
that each decoder rejects the other's file. And the *request* carries the
profile tag too (`model/src/lib.rs:126`), so a block request cannot be fed to
the token guest.

## 3. What is public, and what the salts do

### 3.1 The journal and the policy

The guest commits **exactly** the 144 statement bytes and nothing else:
`env::commit_slice(&actual.encode())` is the last line of the program
(`methods/guest/src/main.rs:22`), and it is the only write of any kind in the
guest. There is no `env::log`, no `env::write`, no `env::verify`, no pause.

So the public view of an accepted token proof is: the image ID (known in
advance, out of band), the four fields of §2.1, and the Groth16 seal. The
runner additionally publishes `model.bin` (the weights, public by D1), and an
`outcome.json` built only from public file hashes and boolean flags
(`scripts/zk60_zkvm_demo.py:798–834`; its comment at `:829–831` explains why
even scan counts are kept out, because they depend on secret-value equality).

### 3.2 Is the next token public?

**No — it is hidden**, and this is the point of the profile. The generated
token appears in the public artifacts only inside the output endpoint, as
`SHA256(… ‖ output_salt ‖ u32le(1) ‖ u32le(token))`. Nothing publishes the
token itself:

- the guest never commits it — `Request::compute` returns `(Statement, u32)`
  and the guest discards the token by pattern (`methods/guest/src/main.rs:20`,
  `model/src/lib.rs:142–148`);
- the host writes it only to `private/output.u32`, mode 0600 inside a 0700
  directory created with an explicit mode (`host/src/main.rs:131–134`);
- `prove` also discards it (`host/src/main.rs:162`);
- the runner asserts the private directory holds exactly `request.bin` and
  `output.u32` after prepare and re-`chmod`s both to 0600
  (`scripts/zk60_zkvm_demo.py:647–655`), then searches every published and
  logged file for the token's three digest encodings
  (`:753–796`; the raw 4-byte token is deliberately *not* searched because a
  4-byte needle would match padding by chance — `:111–117`, test at
  `tests/test_zk60_zkvm_demo.py:630–653`).

The honest caveat, which the code states itself
(`statement/src/lib.rs:85–88`, `zkvm-model/README.md:46–47`): the output
endpoint hides **one of only 32 values**. Its hiding is entirely the secrecy of
the 32-byte output salt; anyone who learns that salt recovers the token with at
most 32 hash evaluations. The input endpoint's message space is 32^32 ≈ 2^160,
so it does not have this property.

### 3.3 Anything else that depends on hidden inputs

Lengths and counts: **nothing varies.** Every frame is a compile-time constant
— model 13,928 bytes, request 240, policy 144, input 128, output 4
(`model/src/lib.rs:15–24`, a `const _: () = assert!(…)` that fails the build if
a kernel or statement change moves any of them). The guest reads three
fixed-length slices (`methods/guest/src/main.rs:11–16`). There is no padding,
no truncation, no optional field.

Error paths and early exits: every refusal in the guest is a static string
(`"public model refused"`, `"private request refused"`, `"policy refused"`,
`"computation refused"`, `"policy mismatch"`, lines 17–21) and every refusal in
the kernel carries only a site name and a layer index, never data — the type is
documented as such (`private-model-kernel/src/lib.rs:53–65`), and
`ModelError::Token` deliberately does not say *which* token was out of range
(`model/src/lib.rs:106–107`, kernel `:57–58`). More importantly, a guest abort
produces **no receipt at all**: there is no public artifact in which a refusal
could be observed. The host's refusals are visible only to the operator, who is
the data owner.

Panics: the only reachable panic sites are the five `expect`s above plus
library-internal ones; none formats a value.

Cycles and segments: these **do** depend on the data — the kernel says so
(`private-model-kernel/src/lib.rs:29`: "Control flow depends on secret data
(argmax, refusals); nothing here claims constant time"), and the README repeats
it (`zkvm-model/README.md:145–146`). But the public Groth16 receipt exposes no
cycle or segment count: the claim is the halted-with-zero shape whose post
state is `{pc: 0, merkle_root: ZERO}` (`risc0-zkvm-3.0.6/src/claim/receipt.rs:77–92`),
so cycle variation is **host-side wall-clock leakage only**, already declared.
The one measurement that exists — nine hostile inputs with identical padded
total cycles and segment counts, user cycles varying by 0.27% — was run for the
**block** guest, not this one (§8, gap G3).

Model identity: the weights are public by D1, so the model digest reveals
nothing that was meant to be hidden. The context is a fresh random nonce
(§3.4), so it reveals nothing either.

Repeated proofs of the same request produce the **same** journal, so an
observer who sees two token receipts with equal policies learns they concern
the same input and the same output. That is the declared leakage the
disposition already records (`ZK60_ZKVM_REVIEW_DISPOSITION.md` §3, row
"Adaptive and repeated proofs").

### 3.4 The salts

- **Length and count.** Two independent 32-byte salts per request, one for each
  role (`model/src/lib.rs:117–122`; layout `:131–139`: profile 0..16, context
  16..48, input salt 48..80, output salt 80..112, tokens 112..240).
- **Source of randomness.** One read of 128 bytes from `/dev/urandom`
  (`host/src/main.rs:111–112`), split into disjoint slices: context `[0..32]`,
  input salt `[32..64]`, output salt `[64..96]`, and — when no owner input is
  given — 32 bytes at `[96..128]` reduced `b % 32` into token IDs
  (`:117–121`; the comment at `:116` is right that 256 is a multiple of 32, so
  the reduction is uniform). No PRNG, no seeding, no time source. A host test
  asserts the three values differ and that fresh runs never repeat any of them
  (`host/src/main.rs:304–305`, `:328–348`).
- **Reuse across proofs.** *Within* one fixed statement, reuse is intended:
  `prove` recomputes the statement from the stored request and refuses unless
  it equals the supplied policy (`host/src/main.rs:162–163`), so proving the
  same policy again necessarily reuses the same salts, and only the receipt
  path must be new (`:148–150`). Reuse with a *different* value is forbidden
  and would destroy hiding for the 32-value output — the crate documents this
  (`statement/src/lib.rs:85–89`) but **nothing enforces it**: `Request::decode`
  accepts an all-zero salt, and accepts `input_salt == output_salt`, in which
  case knowing the prompt and that shared salt would let an attacker brute-force
  the output token (roles keep the two digests distinct — tested at
  `model/src/lib.rs:326–328` — but they do not restore hiding). `prepare` never
  builds such a request; a hand-written one could. See H5.
- **Where stored.** Only in `private/request.bin`, mode 0600 in a 0700
  directory, never in the public directory, never on stdout, never in a log
  (`host/src/main.rs:130–136`; the test at `:311–317` searches both published
  files for both salts and the raw input). For the retained proof the private
  directory lived under `/tmp/zk60-loop-20260917` and was destroyed by the
  01:04 reboot, so the salts of `token_public/receipt.bin` no longer exist
  anywhere — its endpoints can never be opened, by anyone, including us.

## 4. The hidden seam between the two blocks

The "seam" is the activation array that leaves block 0 and enters block 1 —
under D1 it is an intermediate activation and must be hidden. **Confirmed: it
is never written to the journal, to stdout, to a log or to a file.**

The whole two-block computation happens inside one function, on one stack
buffer:

```rust
let mut x = [0i16; X_LEN];                       // private-model-kernel/src/lib.rs:288
… gather embeddings …                            // :289–292
for (layer, blk) in model.blocks.iter().enumerate() {
    x = run_block(&x, &blk.weights, &blk.tables, None)  // :296–297
        .map_err(|e| ModelError::Layer(layer as u8, e))?;
    …
}
```

`x` after the first iteration *is* the seam. It is a local `[i16; X_LEN]`; it
is overwritten by the second iteration and dropped at return. The supporting
facts:

- The crate is `#![no_std]`, `#![forbid(unsafe_code)]`, has no allocation, no
  floats and **no I/O at all**; its own header states "nothing in this crate
  prints anything" (`private-model-kernel/src/lib.rs:1–35`).
- `ModelTrace`, the only type that would materialise the seam
  (`.layer0`, `.layer1`), exists "for native tests only", has **no `Debug`**
  (`:31–32`, `:172–187`), and the guest never constructs one: the guest calls
  `Request::compute` (`methods/guest/src/main.rs:20`), which calls
  `next_token` (`model/src/lib.rs:143`), which passes `None` for the trace
  (`private-model-kernel/src/lib.rs:278–280`). `next_token_traced` is used only
  inside `#[cfg(test)]` modules (`model/src/lib.rs:216–219`).
- `Request` itself is marked "Intentionally no Debug/Serialize"
  (`model/src/lib.rs:116`), so neither the tokens nor the salts can be printed
  by accident, and `PublicModel`'s fields are private
  (`private-model-kernel/src/lib.rs:152–157`).
- The guest's only output is the 144-byte commit (§3.1). `RUST_LOG=off` and
  `RUST_BACKTRACE=0` are set on the host before any thread starts
  (`host/src/main.rs:213–214`, `wrap/src/main.rs:239–240`), and the runner
  removes `RUST_LOG*` from the child environment entirely
  (`scripts/zk60_zkvm_demo.py:93`, `:415–421`).
- The host's native recomputation (`host/src/main.rs:162`) runs the same
  kernel and likewise keeps the seam on the stack; it writes only the request
  and the 4-byte token, both 0600.

One residual, shared with the block profile and not specific to this delivery:
the seam and the tokens live in ordinary process memory. Nothing calls
`mlock`, zeroizes buffers on drop, or disables core dumps, so a core file or a
swapped page could contain them. See H8.

## 5. Receipt kind and environment

**Groth16-only enforcement (D5).** The public verifier is
`zk60-token-wrap verify`. Its `verify()` refuses on kind **first**, before any
journal comparison and before any cryptography:

```rust
if !matches!(receipt.inner, InnerReceipt::Groth16(_)) {        // wrap/src/main.rs:67
    return Err("Groth16 receipt required".into());
}
policy.check_journal(&receipt.journal.bytes)?;                  // :70
receipt.verify_with_context(&VerifierContext::default().with_dev_mode(false),
                            PRIVATE_TOKEN_ID)?;                 // :71–74
```

That `matches!` is load-bearing, because upstream `Receipt::verify` accepts all
four kinds and accepts `Fake` whenever the context is in dev mode (verified in
the disposition §1). Composite and succinct receipts therefore cannot enter the
public path at all. Symmetrically, the **host's** `real_verify` accepts *only*
`InnerReceipt::Succinct` (`host/src/main.rs:66–68`), so the host CLI cannot be
misused to bless a public artifact, and the wrap CLI cannot be misused to bless
an inner one. Both directions are exercised: the runner feeds the inner
succinct receipt to the public verifier and requires refusal
(`scripts/zk60_zkvm_demo.py:729`), and the retained run recorded the same
(`token-refuses-inner`, exit 1).

**Dev-mode refusal.** Three layers. (a) Both binaries are built
`default-features = false, features = ["client", "disable-dev-mode"]`
(`host/Cargo.toml:11`, `wrap/Cargo.toml:10`) — the feature makes
`is_dev_mode()` return false unconditionally and makes setting the variable an
error, and dropping the default features removes the Bonsai upload path from
the build entirely. (b) `ProverOpts::succinct().with_dev_mode(false)`
(`host/src/main.rs:180`, and again for the identity conversion at
`wrap/src/main.rs:172`). (c) `VerifierContext::default().with_dev_mode(false)`
at every verification (`host/src/main.rs:71`, `wrap/src/main.rs:72`, `:150`).
A `Fake` receipt with a genuine claim is rejected in unit tests on both sides
(`host/src/main.rs:455–478`, `wrap/src/main.rs:294–318`).

**Refusal of `RISC0_*` and `BONSAI_*`.** Both binaries check the whole
environment in `main()`, before `run()` and before any prover thread exists:

```rust
fn refused_variable(name: &str) -> bool {                      // host :51–53, wrap :52–54
    name.starts_with("RISC0_") || name.starts_with("BONSAI_")
}
…
if std::env::vars_os().any(|(k, _)| k.to_str().is_some_and(refused_variable)) {
    eprintln!("… RISC0_* and BONSAI_* runtime switches must be unset");
    std::process::exit(1);                                     // host :215–218, wrap :241–244
}
```

This is a **prefix** rule, so it covers `RISC0_DEV_MODE`, `RISC0_PROVER`,
`RISC0_WORK_DIR` (which would otherwise persist the Groth16 witness — see the
disposition §2.4) and `RISC0_PPROF_OUT`, the profiling output path Codex's
review identified as an additional, `RUST_LOG`-independent write channel whose
report is a per-call-site cycle profile of a secret-dependent program. The
predicate tests name `RISC0_PPROF_OUT`, `RISC0_UNKNOWN` and `RISC0_DEV_MODE2`
explicitly (`host/src/main.rs:489–494`, `wrap/src/main.rs:362–367`). **Codex's
finding is closed in these source copies**, and the closure is refusal rather
than silent scrubbing, which is the right shape for a hand run. Belt and
braces: the runner also deletes every `HL_`, `BONSAI_`, `RISC0_` and `RUST_LOG`
variable from the child environment (`scripts/zk60_zkvm_demo.py:93`,
`:415–421`), with a test that sets four of them and still passes
(`tests/test_zk60_zkvm_demo.py:655–668`).

Two notes, neither of them defects. The `to_str()` guard means a variable whose
*name* is not valid UTF-8 would slip past the check — but `risc0-zkvm` looks its
switches up by UTF-8 literals, so such a name can never be read by it either.
And, unlike the hardened block host, the token host does not additionally
`remove_var` the refused names or scrub `RUST_LOG_STYLE`
(compare `zkvm-block/host/src/main.rs:218–239`); refusing is at least as
strong for the names it covers, but see H6.

**`r0vm` selection.** Never `default_prover()`. `prove` constructs an explicit
`ExternalProver::new("explicit-local-r0vm", r0vm)` (`host/src/main.rs:171`)
after requiring the path to be absolute (`:151–153`), and the wrap opens the
identity-conversion sub-process the same way (`wrap/src/main.rs:132–134`,
`:170`). An absolute path is not an integrity check on that binary; the
`r0vm` hash is unpinned (§1.5, H2).

**Saved-byte readback before reporting success.** Both binaries re-read the
file they just wrote, decode it under the bounded codec and verify it again
before printing anything:

- host: `write_new(receipt_path, &bytes, true)` then
  `if verify_saved(&policy, receipt_path)? != bytes { return Err("saved receipt
  differs from verified receipt") }` (`host/src/main.rs:186–189`);
- wrap: the same, with the message "do not publish it"
  (`wrap/src/main.rs:213–216`).

`verify_saved` is a strict path: bounded read (16 MiB cap, type and size
checked, `host/src/main.rs:27–38`), bincode with `with_fixint_encoding`,
`with_limit` and `reject_trailing_bytes` (`:21–26`), then the full kind /
journal / seal check. Files are created with `create_new` and an explicit mode,
so no existing file is ever overwritten and no symlink is followed
(`host/src/main.rs:39–48`, tested at `:404–413`).

## 6. Statement binding, tie-break determinism and integer behaviour

**What binds what.** The guest is twenty-three lines and every one of them
matters (`methods/guest/src/main.rs`):

| Line | Effect |
|---|---|
| 11–16 | three fixed-length reads: model 13,928, request 240, policy 144 |
| 17 | `Model::decode` — framing, shapes and lookup-table structure, and the model digest over **exactly the bytes decoded** (`model/src/lib.rs:96–103`) |
| 18 | `Request::decode` — profile tag, length, and every token in `0..32` (`model/src/lib.rs:125–130`) |
| 19 | `Statement::decode` of the caller's policy — tag and length |
| 20 | `request.compute(&model)` — runs the model and rebuilds both endpoints |
| 21 | `assert!(actual == expected)` — the recomputed statement must equal the policy |
| 22 | commits the recomputed statement |

So: the **model digest** is bound because it is hashed over the identical byte
string the guest decoded and ran (`model/src/lib.rs:102`), including both
blocks' weights *and* their lookup tables *and* their order — the digest test
flips bytes across every region and swaps the two block payloads
(`model/src/lib.rs:248–261`). The **embedding table and head** are inside that
payload (offsets 8..1032 and 13,416..13,928, asserted at `:171–183`), so the
public embedding is covered by the same digest; there is no separate
embedding commitment to get out of step. The **context** is copied verbatim
from the request into the statement (`model/src/lib.rs:147`) and is also mixed
into both endpoints (`statement/src/lib.rs:98`). The **input** is bound by the
input endpoint over all 32 tokens with role 0; the **output** by the output
endpoint over the single recomputed token with role 1
(`model/src/lib.rs:145–146`). Crucially the output endpoint is built from the
token the kernel *returned*, never from anything supplied: `compute` calls
`next_token(&self.tokens, &model.public)` and uses its result
(`model/src/lib.rs:143`, `:146`). The test at `model/src/lib.rs:340–354` makes
this concrete — over 64 requests it checks that the committed output opens to
the kernel's token and to none of the other 31.

Nothing claimed by a caller is consumed: no activation, no logit, no token
appears in any input frame. `Model` has public fields, but the guest reaches it
only through `Model::decode`, so no hand-built object can bypass the decoder —
Codex's observation, confirmed.

**Greedy argmax tie-break.** Deterministic and documented:

```rust
pub fn greedy(logits: &[i64; VOCAB]) -> u32 {      // private-model-kernel/src/lib.rs:261–269
    let mut best = 0usize;
    for v in 1..VOCAB { if logits[v] > logits[best] { best = v; } }
    best as u32
}
```

A strict `>` scanned in increasing index means the **lowest** index wins any
tie. The loop count is fixed at 32 regardless of the data. This rule is not in
the model file and cannot be changed by one: it is fixed by the image, as the
statement crate's doc comment says (`statement/src/lib.rs:69–73`) and the model
crate repeats (`model/src/lib.rs:3–5`).

**Integer overflow and wraparound, guest versus reference.** There is no
wraparound anywhere on the proof path, and no clamping:

- The kernel does its own checked arithmetic: `kadd`/`kmul` wrap
  `checked_add`/`checked_mul` and convert `None` into a refusal
  (`private-model-kernel/src/lib.rs:202–207`), used for the sum of squares, the
  norm denominator, the quotient numerator and every head accumulation
  (`:215–257`). Narrowing is checked too (`u64::try_from`, `i64::try_from` at
  `:222–223`), and out-of-range results are **refused**, not clamped: the final
  norm requires `q ∈ [-127, 127]` and both remainder witnesses below `2^wrho`
  (`:237–240`). The crate header states the rule (`:26`).
- Belt and braces, both build profiles set `overflow-checks = true` in release:
  the guest's own workspace (`methods/guest/Cargo.toml:14–16`) and the host
  workspace (`zkvm-model/Cargo.toml:6–8`). Profile settings apply to path
  dependencies, so the two kernels are compiled with checks on in **both**
  builds. The practical consequence is that the host's native recomputation in
  `prove` and the guest's recomputation cannot diverge by an overflow that is
  caught on one side and wrapped on the other — and because the kernel uses
  explicit checked calls, they would agree even without the flag.
- The remaining raw arithmetic is on indices with statically bounded operands
  (`*tok as usize * D` with `tok < 32`, `v * D + i`), which the const assertions
  at `model/src/lib.rs:23–24` keep honest.
- The reference implementation `reference/reference_vectors.py` is an
  independent Python recomputation of the **framing** only. It shares no code
  with the Rust crates (it re-derives the sizes from first principles at
  `:25–29` and re-implements both hashes at `:32–45`), and its own header is
  explicit: "`check` trusts the claimed output token; it does not run the
  model" (`:15`). So it cross-checks the journal layout, not the model
  relation. The retained run recorded that the Rust and Python vector outputs
  agree on all three digests (`token-rust-vectors.log`,
  `token-python-vectors.log`).

## 7. Segment limit and D3

D3 requires segments at or below `2^20`, because larger segments lower the
conjectured figure. The token host sets

```rust
.segment_limit_po2(18)                       // host/src/main.rs:168
.session_limit(Some(64 * 1024 * 1024))       // host/src/main.rs:169
```

**18 ≤ 20, so D3's condition holds.** At `2^18` the D3 measurement addendum's
figures for the rv32im circuit are 98.6424 bits conjectured and 45.3014 bits
proven (list-decoding), i.e. slightly *better* than the 97.1420 / 41.5670 the
headline number assumes at `2^20`. The correct wording for this artifact stays
"about 97 bits conjectured (RISC Zero default), accepted per D3", with the
2^18 figure recorded alongside; the Groth16 layer adds its own roughly 100 bits
on BN254 plus the D4 trusted-setup assumption.

Two evidence points rather than source points. First, the segment limit is a
hard-coded literal here, unlike the block host's named `SEGMENT_LIMIT_PO2`
constant (`zkvm-block/host/src/main.rs:153`); a future edit could move it
without anything failing. Second — and this is the gap — **the retained token
run records neither the segment limit nor the per-run security figures.** The
hardened block host prints `total_cycles`, `user_cycles`, `segments` and
`segment_limit_po2` from its `execute` stage
(`zkvm-block/host/src/main.rs:165–180`); the token host prints only
`{"execution_matches_policy":true,"proof_created":false,"mvp_complete":false}`
(`host/src/main.rs:175–177`), which is exactly what
`token-integration/token-execute.log` contains. So D3 compliance for this
receipt is established **from source**, not from the run record. See H1.

## 8. Rejection controls and coverage gaps

Two different sets of controls exist, and they are not the same set. This
matters, so both are listed.

**(a) The maintained runner exercises thirteen controls for the token
profile**, all in `Runner.controls()` (`scripts/zk60_zkvm_demo.py:711–746`).
Each runs the *public* verifier in a fresh, environment-scrubbed, process-group
-bounded child and requires a clean refusal — exit code exactly 1, a non-empty
message, and no `"verified": true` line (`:574–578`):

| # | Control | Where |
|---|---|---|
| 1 | policy byte 0 flipped (profile tag) | `:724–727` via `POLICY_FIELDS` `:49–50` |
| 2 | policy byte 16 flipped (context) | same |
| 3 | policy byte 48 flipped (model digest) | same |
| 4 | policy byte 80 flipped (input endpoint) | same |
| 5 | policy byte 112 flipped (output endpoint) | same |
| 6 | the private inner **succinct** receipt offered to the public verifier | `:729` |
| 7 | wrong image ID handed to the verifier (token profile only; the block verifier takes no image argument) | `:731–735` |
| 8 | receipt truncated by one byte | `:736–737` |
| 9 | receipt with one trailing byte | `:736–737` |
| 10 | empty receipt | `:736–737` |
| 11 | first receipt byte flipped | `:738–741` |
| 12 | middle receipt byte flipped | `:738–741` |
| 13 | last receipt byte flipped | `:738–741` |

Control 7 deserves a plain-words note: `check_image` compares the *compiled*
image ID against the operator's argument and refuses on mismatch
(`wrap/src/main.rs:58–63`, called first at `:228`). It does **not** change what
the seal is verified against — that is always the compiled `PRIVATE_TOKEN_ID`
(`:73`). So control 7 tests the operator pin, not the seal binding; the seal
binding to the image is control 1–5's business and upstream's claim-digest
comparison. A verifier that merely ignored the argument would pass verification
but fail this control, which is exactly what
`tests/test_zk60_zkvm_demo.py:645–652` simulates with a "lax-image" mock.

**(b) The retained run recorded eleven controls, and they are a different
eleven.** `token_public/token-proof-v2.json` lists eleven stages with exit code
1: `token-refuses-inner`, `token-wrong-image`, `token-wrong-profile`,
`block-refuses-token`, `token-wrong-context`, `token-wrong-model`,
`token-wrong-input`, `token-wrong-output`, `token-truncated`,
`token-trailing`, `token-tampered`. Those came from Codex's
`token_prove.py` under `/tmp/zk60-loop-20260917`, which the 01:04 reboot
destroyed; the script is not in `scripts/`. Comparing the two sets:

- the retained run has **one control the maintained runner does not**:
  `block-refuses-token`, the cross-profile negative (the *block* verifier
  offered the token pair). The runner's `controls()` never invokes the other
  profile's binary. It is covered at unit level for the standalone `verify`
  subcommand (`tests/test_zk60_zkvm_demo.py:957–961`, and the mirror at
  `:927–932`), and I re-ran it for real today (§9) — but it is not part of the
  pipeline's acceptance set;
- the maintained runner has **three the retained run did not**: the empty
  receipt and two of the three byte-flip positions (the retained run's
  `token-tampered` is a single flip).

**Coverage gaps, named.**

- **G1 — no composite or fake receipt is offered to the public verifier at CLI
  level.** Both are covered by unit tests inside the crates (`Fake` with a
  genuine claim and a zero-seal Groth16 at `wrap/src/main.rs:294–318`), and the
  explicit `matches!` makes the outcome structural, but the pipeline's
  acceptance set only contains the succinct case.
- **G2 — no claim-shape regression.** The block hardening lane added tests for
  a `Paused` claim, a non-empty assumptions list and wrong verifier parameters;
  the token wrap's test module has three tests where the block wrap's has
  eight. This was item 8 of the block review and is still open here.
- **G3 — no constant-cycle (P3) evidence for the token guest.** The gate script
  `scripts/zk60_zkvm_cycle_gate.py` is block-only: it builds 512-element `i16`
  inputs (`:39–40`) and requires the host to report `total_cycles`,
  `user_cycles`, `segments` and `segment_limit_po2 == 18` (`:247–253`), which
  the token host does not print (§7). Timing therefore remains declared
  leakage for this profile with no measurement behind it.
- **G4 — nothing checks the published `model.bin` against the policy's model
  digest.** `audit_public` checks file *names* (`:253–262`); `prepare` checks
  that the published copy equals the input file (`:656–657`); `cmd_verify`
  never opens the model at all (`:1032–1082`). I did the check by hand in §1.3
  and it passes, but a consumer following the README has no command for it.
- **G5 — the token wrap has no `check-tools` subcommand** (the block wrap
  gained one), so an operator cannot validate the pinned native tools for this
  profile without running a full wrap.
- **G6 — the wrong-`r0vm` case is untested.** Both binaries require an absolute
  path and nothing more; no control substitutes a different binary at that
  path.

On the positive side, the token profile's test coverage in
`tests/test_zk60_zkvm_demo.py` is genuinely good and exceeds the block's in two
places: the four-byte-token secret scan (`:630–653`, asserting 19 markers over
5 private values with 1 value too short to search raw), and two fail-closed
tests that run *block* binaries under the token profile and require the run to
stop at the image pin or at `prepare`, creating nothing (`:690–706`).

## 9. Post-reboot re-verification of the retained receipts

The box rebooted at 01:04 on 2026-09-19 and `/tmp` is gone, but the binaries
built on 2026-09-18 at 19:36–19:37 survived under
`zkvm-block/target/release/`. The two verify commands come from the CLI usage
strings in the sources — note they differ, because the token verifier demands
the approved image ID as a third argument and the block verifier does not
(`zkvm-model/wrap/src/main.rs:234`; `zkvm-block/wrap/src/main.rs:276`). Each
ran in its own fresh process, wrote nothing, and touched no repository file.

**Token receipt (the new one).**

```
$ .../zkvm-block/target/release/zk60-token-wrap image-id
3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b
$ .../zkvm-block/target/release/zk60-token-host image-id
3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b
$ .../zk60-token-wrap verify \
    results/zk60_loop_20260918/token-integration/token_public/policy.bin \
    results/zk60_loop_20260918/token-integration/token_public/receipt.bin \
    3c0631ee629a40a78421e03cd5c6ac9ffdafa026a1289aa9207fcce6c016430b
{"verified":true,"kind":"groth16","coverage":"synthetic-T32-V32-two-block-greedy-token","mvp_complete":false}
```

Exit 0. Both binaries' compiled image IDs equal the value recorded in
`token-v2-image-id.log`, so the guest is unchanged since the proof.

**Block receipt (the earlier one), same session.**

```
$ .../zk60-block-wrap verify \
    results/zk60_loop_20260918/block-integration/groth16_public/policy.bin \
    results/zk60_loop_20260918/block-integration/groth16_public/groth16.bin
{"verified":true,"kind":"groth16","coverage":"one-fixed-T32-block","mvp_complete":false}
```

Exit 0.

**Two cross-profile negatives, also fresh processes** (not asked for, cheap,
and they are the one control the maintained runner lacks — §8 G-list):

```
$ zk60-block-wrap verify <token policy> <token receipt>
zk60 wrap: unsupported statement profile or length            exit 1
$ zk60-token-wrap verify <block policy> <block receipt> 3c0631ee…430b
zk60 token wrap: unsupported statement profile or length      exit 1
```

Both refuse on the policy tag, before any cryptography — which is the fail-fast
ordering one wants.

One caveat on the block line: `zkvm-block/wrap/src/main.rs` currently carries
Codex's uncommitted edits, so the `zk60-block-wrap` binary I used (19:36) does
not necessarily correspond to today's block source. For the token line there is
no such caveat — `zkvm-model/` is clean at `HEAD` and the binaries were built
from it (§1.2).

## 10. Findings

Separated as asked: a **DEFECT** is wrong behaviour; a **HARDENING** item is
defence in depth that is currently fine but should not be; **WORDING** is text
that could mislead a later reader. Nothing here blocks the retained artifact,
and nothing here touches D7.

### 10.1 Defects

**D-1 (DEFECT, evidence record, not code).** `token-build-source.json` does not
describe the wrap binary that produced and verified the public receipt. It
records `zkvm-model/wrap/src/main.rs = 7f9780…0ef2ea` and
`zkvm-model/wrap/Cargo.toml = 6f44733f…`, but the wrap source was edited at
19:35:01 to add the pinned native-tool check and the binary was built at 19:37
from that newer source — proven by `zk60-token-wrap.d`, which lists
`zkvm-native-tools/src/lib.rs` as a build input, a file the recorded version
never references. `zkvm-model/Cargo.lock` and `README.md` are stale in the same
record for the same reason. Consequence: the artifact's own source manifest
understates the verifier, and anyone reproducing from it would build a
*weaker* wrap (one that checks native tool filenames but not their hashes).
The guest rows and the host rows are correct and the image ID is unaffected, so
the receipt's meaning does not change — but the record should be corrected or
superseded before it is used as an approval input.
Files: `results/zk60_loop_20260918/token-integration/token-build-source.json:15–16`,
`:5`, `:4`; `zkvm-model/wrap/src/main.rs:153`; `zkvm-model/wrap/Cargo.toml:14`.

No defect was found in `zkvm-model/` or `private-model-kernel/` source.

### 10.2 Hardening items

**H1 — the token host reports no executor telemetry.** `execute` prints only
`execution_matches_policy`, where the hardened block host prints
`total_cycles`, `user_cycles`, `segments` and `segment_limit_po2`. This is why
D3 compliance for this receipt rests on source reading rather than on the run
record, and why the constant-cycle gate cannot run (G3). Cheapest fix: copy
`zkvm-block/host/src/main.rs:165–180` into `zkvm-model/host/src/main.rs:173–178`
and teach `scripts/zk60_zkvm_cycle_gate.py` the token input shape.
Cite: `zkvm-model/host/src/main.rs:168–178`.

**H2 — `r0vm` is pinned by path, not by hash.** Both binaries require an
absolute path and nothing else (`host/src/main.rs:151–153`,
`wrap/src/main.rs:132–134`). The five Groth16 native tools *are* hash-pinned
(`zkvm-native-tools/src/lib.rs:37–68`); `r0vm` is the remaining unpinned
executable on the proving path. Same fix shape: a pin entry, or at minimum
record its SHA-256 with every run.

**H3 — the token wrap keeps the private work directory forever.** After a
verified wrap, `input.json`, `witness.wtns`, `proof.json` and the two child
logs stay in the 0700 work directory (`wrap/src/main.rs:165–216`; no removal
path exists). That material is the inner STARK seal, which D5 says must never
become public. The block wrap now removes it by default and offers
`--keep-work`; the token wrap implements neither, and the runner documents the
asymmetry in a comment (`scripts/zk60_zkvm_demo.py:690–697`). Port the block
behaviour: removal is the safe default for a hand run.

**H4 — nothing checks `model.bin` against the policy's model digest** (G4).
Add a `check-model MODEL POLICY` subcommand, or a runner stage, that recomputes
`SHA256("zk60-r0-token-model-v1\0" ‖ PROFILE ‖ u64le(len) ‖ bytes)` and
compares it with bytes 48..80. I did it by hand for the retained artifact in
§1.3 and it matches; a consumer should not have to.

**H5 — `Request::decode` accepts degenerate salts.** It does not reject an
all-zero salt, nor `input_salt == output_salt`
(`model/src/lib.rs:125–130`). Role separation keeps the two digests distinct
even then (`model/src/lib.rs:326–328`), but with a shared salt an adversary who
learns the prompt and the salt recovers the output token in 32 tries — the
32-value message space makes this profile unusually sensitive to salt misuse.
`prepare` never builds such a request; a hand-built one could. Two cheap
rejections in the decoder would make the safe case the only case.

**H6 — the token host does not scrub, only refuse.** It refuses any
`RISC0_*`/`BONSAI_*` name and exits, which is fine and arguably clearer, but
the hardened block host additionally `remove_var`s them and scrubs
`RUST_LOG_STYLE` (`zkvm-block/host/src/main.rs:218–239`). Aligning the two
removes a difference a future reader has to re-derive.

**H7 — no `check-tools` subcommand on the token wrap** (G5): an operator cannot
validate the pinned native tools for this profile without running a full wrap.

**H8 — no memory hygiene for the tokens, the seam and the salts.** Nothing
zeroizes `Request`, the kernel's activation buffer or the decoded salts on
drop; nothing disables core dumps or locks pages. The filesystem story is
careful (0700/0600, `create_new`, symlink refusal); the memory story is not
addressed at all. Low priority for a laptop experiment, but it belongs on the
list before anything is called a private artifact.

**H9 — filesystem checks are not race-proof.** `private_inner` lstats the
inner receipt and then re-opens it by path (`wrap/src/main.rs:86–95`), and
`validate_tool_directory` hashes the tools and then the wrap joins names on the
canonical directory (`wrap/src/main.rs:153`, `zkvm-native-tools/src/lib.rs:9–12`
says so itself). Both assume a trusted local directory owner. Documented, not
fixed; recording it as an explicit premise of the artifact would be enough.

**H10 — claim-shape and composite/fake CLI regressions are missing** (G1, G2).
The block hardening lane's three regressions (`Paused`, non-empty assumptions,
wrong verifier parameters) plus a CLI-level composite case would close the last
of the block review's eight items on the token side.

**H11 — the cross-profile negative is not in the pipeline's acceptance set**
(§8). It was in the destroyed `/tmp` script and it is in the unit tests; it
should be one more `refuse(...)` call in `Runner.controls()`, invoking the
other profile's verifier on this profile's artifacts.

### 10.3 Wording

**W-1 — `token_public/SHA256SUMS` omits `README.txt`** and uses absolute
paths, so the file that *describes* the artifact is unpinned and
`sha256sum -c` only works from this box. Hash the README too, and write
relative paths.

**W-2 — the image-ID argument is a pin, not a binding.** `check_image` compares
the operator's hex string against the *compiled* image ID and refuses on
mismatch (`wrap/src/main.rs:58–63`); verification itself always uses the
compiled ID (`:73`). Codex's review already says "successful `image-id` output
from the same candidate build is identification, not by itself approval"; the
README's verifier paragraph (`zkvm-model/README.md:120–125`) would be clearer
if it said the same in one sentence, because the phrase "requires the caller's
independently obtained image ID to equal the compiled one" reads, to a hurried
operator, as though the argument selected what is verified.

**W-3 — "both wrappers use `../zkvm-native-tools`"** (`zkvm-model/README.md:117–119`)
is true of the current source and false of the version named in the retained
build record; whichever way D-1 is resolved, the record and the README should
end up telling the same story.

## 11. What this review did not check

Said plainly, so nobody reads more into the verdict than is there.

- **Nothing was built, proven, executed in the zkVM, or tested.** No `cargo`,
  no `r0vm`, no unit-test run, no download, no git write. The crates' own tests
  are read as *claims about* the code, not as passing evidence; the only
  execution in this session was `image-id` and `verify` on already-built
  binaries, five invocations in total.
- **The block profile was not re-reviewed.** `zkvm-block/` carries Codex's
  uncommitted edits and is out of scope; I only ran its verifier once (§9).
- **`private-block-kernel/` was not re-reviewed.** Both blocks' arithmetic
  comes from it, and the block review already covers its checked arithmetic and
  refusal-not-clamping behaviour. I confirmed only that its bytes are unchanged
  since the build record and that `private-model-kernel` calls `run_block` with
  no trace.
- **Upstream `risc0-*` claims are mostly relayed, not re-verified.** The
  citations to `risc0-zkvm-3.0.6/src/receipt.rs`, `src/claim/receipt.rs` and
  the dev-mode feature come from `ZK60_ZKVM_REVIEW_DISPOSITION.md`, which
  checked them in the local crate source. The one upstream claim I checked
  myself, because §1.5 turns on it, is `risc0-build` 3.0.6's lack of a path
  remap.
- **No cryptography was assessed.** Whether SHA-256 commitments hide, whether
  the Groth16 layer is zero-knowledge, whether the ceremony was honest (D4),
  and the 97-bit conjectured level (D3) are all accepted external assumptions,
  not things this review re-established.
- **No timing or cycle measurement was taken**, on either guest.
- **The ceremony, the extracted native tools and the prover's randomness were
  not re-checked.** I read the pin table; I did not re-hash the 2.2 GB proving
  key or re-derive the image manifest.
- **No claim about model quality.** The fixture is synthetic and untrained,
  vocabulary 32, width 16, context 32; this is a functional intermediate, not
  an MVP, and every artifact says so in its own `coverage` string.
- **D7 is untouched.** Whether the salted-SHA-256 endpoint profile is the
  accepted P1 statement remains Victor's ruling. Until it is made, the right
  label for this artifact is "two-block token-generation experiment", not
  "private token generation".
