"""Lattice-based zero-knowledge proofs of matrix multiplication.

Pure-Python reference implementation (Route Z) of the two protocols in the
companion report ``zk-matrix-multiplication-lattice.pdf``:

* Protocol Pi1: ``C = A B`` with ``A`` public and ``B``, ``C`` hidden behind
  Ajtai/BDLOP-style lattice commitments (binding under SIS, hiding under
  knapsack-LWE or statistically via the leftover hash lemma).
* Protocol Pi2: all three matrices hidden; double Freivalds compression plus
  a quadratic garbage-term product Sigma-protocol.

Both are non-interactive via the Fiat-Shamir transform with SHAKE-256 and
Schnorr-style transcript compression. All arithmetic is integer linear
algebra modulo a word-sized prime; there are no elliptic curves or pairings,
and no dependencies outside the standard library.

This is a prototype for protocol experiments, not a production cryptographic
backend: parameters must be validated with the lattice estimator before any
security claim (see ``LatticeParams.check_constraints``).
"""

from .params import (
    LatticeParams,
    reference_params,
    reference_params_pi1,
    reference_params_pi2,
    toy_params,
    toy_params_rect,
)
from .commitment import (
    CommitmentKey,
    commit,
    commit_columns,
    expand_crs,
    prove_opening,
    verify_opening,
)
from .protocol import (
    Pi1Proof,
    Pi2Proof,
    prove_pi1,
    prove_pi2,
    verify_pi1,
    verify_pi2,
)

__all__ = [
    "CommitmentKey",
    "LatticeParams",
    "Pi1Proof",
    "Pi2Proof",
    "commit",
    "commit_columns",
    "expand_crs",
    "prove_opening",
    "prove_pi1",
    "prove_pi2",
    "reference_params",
    "reference_params_pi1",
    "reference_params_pi2",
    "toy_params",
    "toy_params_rect",
    "verify_opening",
    "verify_pi1",
    "verify_pi2",
]
