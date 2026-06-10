"""Pure-Python zkMatrix proof-of-concept primitives.

This package implements the algebraic core of the zkMatrix paper for local
experiments. It is not a production cryptographic backend.
"""

from .groups import (
    MultiplicativeSubgroup,
    ToyAdditiveGroup,
    make_group,
)
from .protocol import (
    MatmulBases,
    MatmulStatement,
    MatmulWitness,
    commit_matmul,
    make_bases,
    matrix_multiply,
    prove_naive_zk_matmul,
    prove_core_matmul,
    prove_zk_matmul,
    random_matrix,
    verify_naive_zk_matmul,
    verify_core_matmul,
    verify_zk_matmul,
)

__all__ = [
    "MatmulBases",
    "MatmulStatement",
    "MatmulWitness",
    "MultiplicativeSubgroup",
    "ToyAdditiveGroup",
    "commit_matmul",
    "make_bases",
    "make_group",
    "matrix_multiply",
    "prove_naive_zk_matmul",
    "prove_core_matmul",
    "prove_zk_matmul",
    "random_matrix",
    "verify_naive_zk_matmul",
    "verify_core_matmul",
    "verify_zk_matmul",
]
