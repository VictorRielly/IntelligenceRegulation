# The two statements every ZKP must have proved in Lean before production (proposal, 2026-11-04)

**Status: APPROVED by Victor, 2026-11-04** ("I approve the lean statements and section 6 choices"; "go ahead and reuse FlashProve's library when appropriate"), together with every choice in §6. The requirement itself is Victor's ruling (D63,
2026-11-04): "Before we put any ZKPs into production we need to formalize and prove in lean the following two
statements of the ZKPs." This file proposes the precise statements. Nothing here is proved yet. The formalization
is the last step before production; it does not hold up the latency work.

**The statements are also written in Lean 4** (`formal/ZK60Formal/Statements.lean`; Lean 4.34.1, Mathlib v4.34.1;
build with `lake -d formal build`). It states `CircuitIff`, `Complete`, `KnowledgeSound`, `Binding`,
`ZeroKnowledge`, `SemanticHiding` and the bundle `ProductionReady` for an abstract profile. A real profile becomes
an instance of its structures, and proving `ProductionReady` for that instance is the remaining work. The Lean text
is the authoritative wording. The code blocks below are its readable sketch; where they differ, the Lean file wins.

## 1. In plain words

**Statement 1, "the proof is right exactly when the answer is right."**
- If the model's answer is correct, the honest proof is accepted (except with a tiny, stated failure chance).
- If the claimed answer is not the discretized model's answer on the committed input, no prover can get it
  accepted, except with probability at most about q × 2^-λ after q hash computations.
- "The discretized model" is a Lean definition of the exact integer model we run: integer weights, integer
  matrix products, the rounding rules, the lookup tables for exp, SiLU and rsqrt, the norm and softmax steps, and the
  final decision (the greedy next token, or the classifier's verdict). It is written once in Lean and tested
  against our Rust forward pass.

**Statement 2, "the receipt teaches nothing about the hidden data."**
- A simulator that never sees the hidden data produces fake receipts that no one can tell from real ones, except
  with probability at most ε_zk after q hash computations.
- Consequence, the form you asked for: for any property of the hidden data at all (one bit, one token, anything),
  seeing the receipt raises anyone's chance of guessing it by at most ε_zk.
  - With ε_zk ≈ q × 2^-128 + 2^-120, learning even one bit with a 1% advantage takes about 2^121 hash computations.
    That is the "exorbitant compute" form.
  - The part of ε_zk that does not grow with q is the "nearly 100% probability" form.
- **This is stronger than "nearly 100% of the data is hidden": nothing leaks beyond a short, declared list** (the
  model, the token count, any output we choose to publish such as the classifier verdict, and whether the prover
  served the request).

**What stays outside any theorem, said up front.**
- Lean checks proofs, not whether the definitions mean what we want. The statement file has to be read by a person,
  and we will publish it as a short, readable file for exactly that.
- Timing and other side channels are not covered.
- The theorems are about the Lean model of the prover and verifier. Section 5 says how each one is tied to the code
  we run.

## 2. The objects (Lean)

```lean
-- A registered proof profile: shapes, field (Goldilocks, p = 2^64 - 2^32 + 1, with its degree-2 extension Fp2),
-- code (Reed–Solomon, rate, opened columns Q, pad count), hash, D55 fork plan, token count T.
structure Profile where ...

-- The discretized (integer) model of a profile. Executable and total.
structure IntModel (P : Profile) where
  Weights : Type            -- integer weights (public under P1, committed under P3)
  Input   : Type            -- a token sequence of length P.T (or the classifier's input)
  Output  : Type            -- next token (argmax with a fixed tie rule) or classifier verdict
  admissible : Input → Prop -- vocabulary range, length; decidable
  forward : Weights → Input → Output  -- exact integer semantics, as in section 1

-- What an output makes public (P1: nothing beyond a declared part, such as a verdict).
  publicPart : Output → PublicOutput
  hiddenPart : Output → HiddenOutput

-- Public statement of one proof: profile, weights digest (P1) or weights commitment (P3),
-- the input commitment root, the public output part, the hidden-output commitment root.
structure Stmt (P) (M : IntModel P) where
  wroot : Digest; cin : Digest; ypub : M.PublicOutput; cout : Digest

-- The protocol: a hash function H (modelled as a random oracle), the honest prover, the verifier.
def prove  (H : Oracle) (W) (x : M.Input) (coins) : Stmt × Receipt
def verify (H : Oracle) (s : Stmt) (π : Receipt) : Bool      -- deterministic; THE production verifier (section 5)
def opens  (H : Oracle) (root : Digest) (v) (salt) : Prop     -- a salted commitment opening
```

## 3. Statement 1: completeness and knowledge soundness, the precise form of "if and only if"

An exact "if and only if" is impossible for any short proof: a cheater can always guess, with a tiny chance. The
precise form has two theorems with stated error terms. Together they say: accepted ⇔ the answer is the model's
answer, except with the stated probabilities.

**T1a, completeness ("if").** For every profile P, weights W and admissible input x, the honest receipt is accepted,
and its statement carries the model's answer:

```lean
theorem complete (P) (M : IntModel P) (W) (x) (hx : M.admissible x) :
  Pr[ H ← RO, coins ← U ; let (s, π) := prove H W x coins :
      verify H s π = true
      ∧ s.ypub = M.publicPart (M.forward W x)
      ∧ (∃ r, opens H s.cin x r) ∧ (∃ r', opens H s.cout (M.hiddenPart (M.forward W x)) r') ]
  ≥ 1 - ε_c P
```

- ε_c covers the prover's own refusals on rare challenge values (today "a refusal is terminal").
- Target: ε_c ≤ 2^-40, as FlashProve has.

**T1b, knowledge soundness with binding ("only if").** There is an extractor E that reads the cheating prover's hash
queries. For every cheating prover A that makes at most q hash queries:

```lean
theorem knowledgeSound (P) (M : IntModel P) :
  ∃ E, ∀ (A : Adversary) (q : ℕ), A.queries ≤ q →
  Pr[ H ← RO ; (s, π) ← A^H ; (x, r, r') ← E(A's query log) :
      verify H s π = true
      ∧ ¬ ( M.admissible x
            ∧ opens H s.cin x r
            ∧ s.ypub = M.publicPart (M.forward W x)
            ∧ opens H s.cout (M.hiddenPart (M.forward W x)) r' ) ]
  ≤ ε_s P q
```

Here W is the model the statement names: public under P1, and extracted from `s.wroot` under P3. Binding of the
roots is part of the same statement: no one can open `s.cin` to two different inputs except within ε_s.

**Error target.**
- ε_s(q) = q·2^-λ₁ + 2^-λ₀, with λ₁ ≥ 100 bits per hash query and λ₀ ≥ 100.
  - For comparison, FlashProve proves about q/2^124 + 2^-101.
  - Our current interactive count is 2^-97.78 for the whole 8B T128 run at W16R2 Q = 280 (union bound, D59).
- The Lean count will produce the true q-dependent figure. Before production it must meet the target, or you
  rule on a lower one. A larger field or proof-of-work grinding would raise λ₁ if needed.

**The lemma that carries the model (the bulk of the work).** It is deterministic, with no cryptography: the
profile's constraint system (the slots, lookups, range checks and sumcheck relations) is satisfiable with endpoints
(x, y) exactly when y = forward W x.

```lean
theorem circuit_iff (P) (M) (W) (x) (y) :
  (∃ w, Satisfies (constraints P W) x y w) ↔ (M.admissible x ∧ y = M.forward W x)
```

This lemma is where field arithmetic must equal integer arithmetic: the range checks rule out wrap-around mod p.

## 4. Statement 2: zero knowledge, the precise form of "sufficiently hard to learn anything"

**T2, zero knowledge in the random-oracle model.** There is a simulator S that sees only the public values
(profile, weights digest, public output parts, and the declared leakage L below). It may program the random oracle.
For every distinguisher D that makes at most q hash queries and sees up to R receipts on inputs of its own choosing:

```lean
theorem zeroKnowledge (P) (M : IntModel P) :
  ∃ S, ∀ (D : Distinguisher) (q R : ℕ), D.queries ≤ q → D.receipts ≤ R →
  | Pr[ D^{H, Prove(W, ·)} = 1 ] - Pr[ D^{S.oracle, S(W, publicPart ∘ forward W, L)} = 1 ] |
  ≤ ε_zk P q R
```

**Corollary T2′, the form you asked for (any information at all).** For every function g of the hidden data
(inputs, activations, hidden outputs) and every adversary A that makes at most q queries:

```lean
Pr[ A(receipts, public) = g(hidden) ] ≤ max_B Pr[ B(public) = g(hidden) ] + ε_zk P q R
```

That is, the receipts raise anyone's success at learning any property of the hidden data by at most ε_zk. The
variable q makes the "exorbitant compute" form explicit; the q-free part of ε_zk is the "probability" form.

**Declared leakage L** (all of it must be listed in the Lean statement; anything else must be simulated):
- the profile: the model, the shapes, the token count T, the D55 fork plan;
- the public output part: nothing for a hidden output; for the media classifier, the verdict bits per D58/D61;
- whether the request was served or refused (one bit, as in FlashProve), unless T1a's refusal is shown independent
  of the hidden data, in which case even that bit is simulated;
- the receipt length, which is fixed per profile.

**Error target.**
- ε_zk(q, R) ≤ q·2^-128 + R·2^-120, valid for q ≤ 2^64 and R ≤ 2^64 (**amended 2026-11-10, D76 (2)**; this draft
  first said R ≤ 2^30, and the Lean first asked for every q and R). FlashProve proves ≤ 2^-154 for q ≤ 2^64 and
  688,127 replies.
- **Amendment D76 (1), 2026-11-10:** the declared leakage L above is an explicit part of the Lean statements
  themselves, not a field each protocol instance chooses, and the production theorem names it. The first
  `Statements.lean` left it to the instance, so a protocol that publishes its input could satisfy the statement (gap
  audit finding GB-1). **In the Lean (lane L42):** the approved statements are now `ZeroKnowledgeL`,
  `SemanticHidingL` and the gate `ProductionReadyL`, each taking the allowed leakage `Λ` as an argument;
  `ZeroKnowledge`, `SemanticHiding` and `ProductionReady` stay as the instance-leak forms the proofs use, with bridges
  (`StatementsD76Bridge.lean`). For the media classifier `Λ` is `classifyLeak` (T, d, the layer count, whether the
  request is served; `StatementsD76Leak.lean`). A protocol that publishes its input provably fails the new gate
  (`leaky_not_productionReadyL`).
- The expected sources:
  - salted Merkle leaves, about q·2^-(salt bits);
  - an opened-column count at or below the pad count, which is exact (the D59 privacy check: full rank on any Q
    distinct points);
  - the masked sumcheck, which is exact in the uniform-blinding idealization per the joint-law composition check;
  - challenge values that make a mask degenerate.
- **P3 (weights hidden)** extends the hidden data to the weights, with `s.wroot` as their commitment, and adds
  authenticated model identity (ZK60_PRIVACY_REQUIREMENTS).

## 5. Tying the theorems to the programs we run

FlashProve leaves these gaps open: its C++ verifier, its CUDA prover, and their equivalence to Lean rest on tests.
Two of them are within our reach.

| Link | Proposed rule | Status |
|---|---|---|
| Verifier | **Production acceptance is the Lean `verify`'s verdict** (compiled, executable Lean). Our Rust verifier stays the fast path, and the two must agree on every golden, every malicious control and every production receipt we spot-check | proposed; needs your ruling |
| Integer model | The Lean `forward` is run against our Rust witness builder on the trained 8B, Shieldstral and TinyLlama goldens; every intermediate value must be equal | testing, not proof; unavoidable |
| Prover (for ZK) | T2 is about the Lean honest prover. The Rust/Metal prover is tied to it by (a) the 18-part privacy gate on real captures, which already hunts for leaks in the shipped prover's output (FlashProve has no such check), and (b) as a stretch goal, a translation (Aeneas or hax) of the mask sampling and message assembly into Lean, proved equal to the Lean prover | (a) exists; (b) open |
| Randomness | Masks come from a CSPRNG seeded from OS entropy; Lean models them as uniform. Stated as an assumption | assumption |
| Hash | BLAKE3 modelled as a random oracle, as FlashProve models BLAKE2b | assumption |
| Kernel | Only Lean's three standard axioms (`propext`, `Classical.choice`, `Quot.sound`), no `sorry`; checked again with an independent checker (nanoda or lean4checker) | rule |

## 6. Decisions for Victor

1. Approve these two statements (T1a + T1b with `circuit_iff`, T2 with T2′) as the production requirement, or
   amend them.
2. The error targets: λ₁, λ₀ ≥ 100 for soundness, and ε_zk ≤ q·2^-128 + R·2^-120 for zero knowledge. Or name others.
3. Production acceptance by the Lean verifier (section 5, row 1). Recommended: it makes soundness a theorem about
   what actually decides acceptance, at the cost of a slower verify (seconds, not milliseconds).
4. Reuse FlashProve's Apache-2.0 Lean library, which proves the Reed–Solomon proximity results and has the
   random-oracle framework, and ArkLib (sumcheck, IOP compilation). Recommended: our code is Ligero-style over
   Reed–Solomon too, so much of the coding theory carries over.

## 7. How it gets done (does not block the latency work)

- **L0 (first):** pin the toolchain (Lean 4 + Mathlib + ArkLib), read FlashProve's `lean/` and `THEOREM.md`, and
  write the statements of section 3–4 in Lean with `sorry`. Publish them as a short, readable file for review. Your
  approval of section 6 comes first.
- **L1:** the integer model in executable Lean, tested value-for-value against the Rust witness builder.
- **L2:** `circuit_iff` per profile family. The R13 and W16 arithmetizations of the same integer model share one
  `forward`.
- **L3:** soundness of the IOP: sumcheck, LogUp, the Ligero-style PCS at δ/3 (rate 1/4) and δ/2 (rate 1/2, D59),
  the D55 fork-join composition, then Fiat–Shamir in the random-oracle model, giving the q-dependent bound.
- **L4:** zero knowledge: the masked sumcheck, the hiding PCS (pad block full rank), salted Merkle hiding, the
  refusal bit, and composition over R receipts.
- **L5:** the executable Lean verifier, and the agreement corpus against the Rust verifier.
- **Sizing (estimate, not measured):** several months of agent work plus human review. FlashProve's development
  compiles about 16,000 Lean files including its libraries. The formalization should target a frozen production
  profile: every change to the protocol (W16R2, Q = 280, D55) changes what must be proved.

Sources: FlashProve, `github.com/anthropics/FlashProve` (`lean/THEOREM.md`, `guide/what-is-proved.md`, Apache-2.0),
read 2026-11-04; ZK60_PRIVACY_REQUIREMENTS.md; D58, D59, D60, D61 in ZK60_DECISIONS.md.
