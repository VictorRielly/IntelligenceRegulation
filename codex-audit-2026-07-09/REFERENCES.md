# Primary external references

These sources were used only to calibrate the repository's claims; the findings
principally come from the repository itself.

1. **zkMatrix: Batched Short Proof for Committed Matrix Multiplication** — the
   protocol the original pairing-style work reconstructs:
   <https://eprint.iacr.org/2024/161.pdf>
2. **zkLLM: Zero Knowledge Proofs for Large Language Models** — primary
   comparison for an LLM-specific GPU proof architecture; its public abstract
   reports a 13B model proof below 15 minutes, not seconds:
   <https://arxiv.org/abs/2404.16109>
3. **Lyubashevsky and Seiler, Short, Invertible Elements in Partially Splitting
   Cyclotomic Rings and Applications to Lattice-Based Zero-Knowledge Proofs** —
   basis for the short-invertible-difference condition used by Route R:
   <https://crypto.ethz.ch/publications/files/LyuSei17.pdf>
4. **Micciancio and Mol, Pseudorandom Knapsacks and the Sample Complexity of
   LWE Search-to-Decision Reductions** — primary grounding for the
   knapsack/LWE relationship discussed by the lattice work:
   <https://eprint.iacr.org/2011/521.pdf>
5. **LaZer: Automated and Efficient Zero-Knowledge Proofs for Lattice-Based
   Cryptosystems** — relevant reference implementation/research baseline for
   lattice ZK engineering and sampling:
   <https://eprint.iacr.org/2024/1846.pdf>

These papers do not validate the bespoke Route R protocol or its concrete
parameters. Any analogy to NIST-standard schemes should be described as an
analogy, not a reduction showing equivalent security.

