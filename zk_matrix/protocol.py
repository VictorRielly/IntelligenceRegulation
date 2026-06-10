"""zkMatrix-style committed matrix multiplication proof prototype.

The core protocol implements the matrix multiplication reduction from
Algorithm 4 of the zkMatrix paper:

    C = A B

is reduced to four inner-product statements after a Fiat-Shamir challenge.
``prove_zk_matmul`` follows the paper's final optimization: instead of applying
the naïve Algorithm 5 wrapper to the whole matrix multiplication, it inserts
random masks into the four Algorithm 4 subprotocols so that the additional
zero-knowledge work is quadratic in the matrix dimensions.
"""

from __future__ import annotations

from dataclasses import dataclass
import random
import secrets
from typing import List, Optional, Sequence, Tuple

from .groups import CyclicGroup
from .inner_product import (
    InnerProductProof,
    inner_product,
    prove_inner_product,
    verify_inner_product,
    vector_commitment,
)
from .transcript import challenge_scalar, transcript_bytes

Matrix = List[List[int]]


@dataclass(frozen=True)
class MatmulBases:
    rows: int
    inner: int
    cols: int
    a_bases: Matrix
    b_bases: Matrix
    c_bases: Matrix
    ay_bases: List[int]
    by_bases: List[int]
    scalar_base: int
    blind_base: int


@dataclass(frozen=True)
class MatmulStatement:
    rows: int
    inner: int
    cols: int
    a_commitment: int
    b_commitment: int
    c_commitment: int


@dataclass(frozen=True)
class MatmulWitness:
    a: Matrix
    b: Matrix
    c: Matrix
    a_blind: int = 0
    b_blind: int = 0
    c_blind: int = 0


@dataclass(frozen=True)
class CoreMatmulProof:
    d_commitment: int
    ay_commitment: int
    by_commitment: int
    c_projection_proof: InnerProductProof
    a_projection_proof: InnerProductProof
    b_projection_proof: InnerProductProof
    product_projection_proof: InnerProductProof


@dataclass(frozen=True)
class ZkProjectionProof:
    mask_commitment: int
    projected_mask_commitment: int
    response_blind: int
    projected_response_blind: int
    proof: InnerProductProof


@dataclass(frozen=True)
class ZkProductProjectionProof:
    alpha_commitment: int
    beta_commitment: int
    cross_commitment: int
    alpha_beta_commitment: int
    left_response_blind: int
    right_response_blind: int
    output_response_blind: int
    proof: InnerProductProof


@dataclass(frozen=True)
class ZkMatmulProof:
    d_commitment: int
    ay_commitment: int
    by_commitment: int
    c_projection_proof: ZkProjectionProof
    a_projection_proof: ZkProjectionProof
    b_projection_proof: ZkProjectionProof
    product_projection_proof: ZkProductProjectionProof


@dataclass(frozen=True)
class NaiveZkMatmulProof:
    alpha_commitment: int
    beta_commitment: int
    cross_commitment: int
    alpha_beta_commitment: int
    a_response_blind: int
    b_response_blind: int
    c_response_blind: int
    core_proof: CoreMatmulProof


def _mod_matrix(matrix: Matrix, q: int) -> Matrix:
    return [[value % q for value in row] for row in matrix]


def _shape(matrix: Matrix) -> Tuple[int, int]:
    if not matrix or not matrix[0]:
        raise ValueError("matrix must be non-empty")
    width = len(matrix[0])
    if any(len(row) != width for row in matrix):
        raise ValueError("matrix rows must all have the same length")
    return len(matrix), width


def _validate_witness(statement: MatmulStatement, witness: MatmulWitness) -> None:
    a_rows, a_cols = _shape(witness.a)
    b_rows, b_cols = _shape(witness.b)
    c_rows, c_cols = _shape(witness.c)
    expected = (statement.rows, statement.inner, statement.cols)
    actual = (a_rows, a_cols, b_cols)
    if actual != expected or b_rows != statement.inner:
        raise ValueError("witness A and B shapes do not match the statement")
    if (c_rows, c_cols) != (statement.rows, statement.cols):
        raise ValueError("witness C shape does not match the statement")


def _flatten(matrix: Matrix) -> List[int]:
    return [value for row in matrix for value in row]


def _flatten_b_by_rows(matrix: Matrix) -> List[int]:
    return [matrix[i][j] for i in range(len(matrix)) for j in range(len(matrix[0]))]


def _powers(base: int, count: int, q: int) -> List[int]:
    values = []
    current = 1
    for _ in range(count):
        values.append(current)
        current = (current * base) % q
    return values


def _matrix_add(left: Matrix, right: Matrix, q: int) -> Matrix:
    if _shape(left) != _shape(right):
        raise ValueError("matrix addition shape mismatch")
    return [
        [(x + y) % q for x, y in zip(left_row, right_row)]
        for left_row, right_row in zip(left, right)
    ]


def _matrix_scale(matrix: Matrix, scalar: int, q: int) -> Matrix:
    return [[(scalar * value) % q for value in row] for row in matrix]


def _vector_add(left: Sequence[int], right: Sequence[int], q: int) -> List[int]:
    if len(left) != len(right):
        raise ValueError("vector addition shape mismatch")
    return [(x + y) % q for x, y in zip(left, right)]


def _vector_scale(values: Sequence[int], scalar: int, q: int) -> List[int]:
    return [(scalar * value) % q for value in values]


def _random_vector(
    length: int,
    q: int,
    *,
    rng: Optional[random.Random] = None,
) -> List[int]:
    if length <= 0:
        raise ValueError("vector length must be positive")
    source = rng if rng is not None else secrets.SystemRandom()
    return [source.randrange(q) for _ in range(length)]


def random_matrix(
    rows: int,
    cols: int,
    q: int,
    *,
    rng: Optional[random.Random] = None,
    max_entry: Optional[int] = None,
) -> Matrix:
    """Generate a random finite-field matrix."""

    if rows <= 0 or cols <= 0:
        raise ValueError("matrix dimensions must be positive")
    source = rng if rng is not None else secrets.SystemRandom()
    bound = q if max_entry is None else min(max_entry, q)
    return [[source.randrange(bound) % q for _ in range(cols)] for _ in range(rows)]


def matrix_multiply(left: Matrix, right: Matrix, q: int) -> Matrix:
    """Exact finite-field matrix multiplication."""

    left_rows, left_cols = _shape(left)
    right_rows, right_cols = _shape(right)
    if left_cols != right_rows:
        raise ValueError("matrix multiplication shape mismatch")
    product = [[0 for _ in range(right_cols)] for _ in range(left_rows)]
    for i in range(left_rows):
        for k in range(left_cols):
            value = left[i][k] % q
            if value == 0:
                continue
            for j in range(right_cols):
                product[i][j] = (product[i][j] + value * right[k][j]) % q
    return product


def make_bases(
    group: CyclicGroup,
    rows: int,
    inner: int,
    cols: int,
    label: bytes = b"zkmatrix",
) -> MatmulBases:
    """Derive deterministic matrix commitment bases for one shape."""

    if rows <= 0 or inner <= 0 or cols <= 0:
        raise ValueError("matrix dimensions must be positive")

    def basis(tag: str, *indices: int) -> int:
        suffix = b":".join(str(index).encode("ascii") for index in indices)
        return group.hash_to_group(label + b":" + tag.encode("ascii") + b":" + suffix)

    a_bases = [[basis("A", i, j) for j in range(inner)] for i in range(rows)]
    b_bases = [[basis("B", i, j) for j in range(cols)] for i in range(inner)]
    c_bases = [[basis("C", i, j) for j in range(cols)] for i in range(rows)]
    ay_bases = [basis("AY", j) for j in range(inner)]
    by_bases = [basis("BY", j) for j in range(inner)]
    scalar_base = basis("D", 0)
    blind_base = basis("BLIND", 0)
    return MatmulBases(
        rows=rows,
        inner=inner,
        cols=cols,
        a_bases=a_bases,
        b_bases=b_bases,
        c_bases=c_bases,
        ay_bases=ay_bases,
        by_bases=by_bases,
        scalar_base=scalar_base,
        blind_base=blind_base,
    )


def commit_matrix(
    group: CyclicGroup,
    matrix: Matrix,
    bases: Matrix,
    blind_base: Optional[int] = None,
    blind: int = 0,
) -> int:
    """Commit to a matrix with optional Pedersen blinding."""

    if _shape(matrix) != _shape(bases):
        raise ValueError("matrix and base shapes do not match")
    commitment = vector_commitment(group, _flatten(matrix), _flatten(bases))
    if blind_base is not None and blind:
        commitment = group.add(commitment, group.scale(blind_base, blind))
    return commitment


def commit_vector(
    group: CyclicGroup,
    values: Sequence[int],
    bases: Sequence[int],
    blind_base: Optional[int] = None,
    blind: int = 0,
) -> int:
    commitment = vector_commitment(group, [value % group.q for value in values], bases)
    if blind_base is not None and blind:
        commitment = group.add(commitment, group.scale(blind_base, blind))
    return commitment


def commit_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    a: Matrix,
    b: Matrix,
    c: Matrix,
    *,
    blinded: bool = False,
    rng: Optional[random.Random] = None,
) -> Tuple[MatmulStatement, MatmulWitness]:
    """Create a committed matrix multiplication statement and witness."""

    statement = MatmulStatement(
        rows=bases.rows,
        inner=bases.inner,
        cols=bases.cols,
        a_commitment=group.identity,
        b_commitment=group.identity,
        c_commitment=group.identity,
    )
    witness = MatmulWitness(
        a=_mod_matrix(a, group.q),
        b=_mod_matrix(b, group.q),
        c=_mod_matrix(c, group.q),
    )
    _validate_witness(statement, witness)
    source = rng if rng is not None else secrets.SystemRandom()
    a_blind = source.randrange(group.q) if blinded else 0
    b_blind = source.randrange(group.q) if blinded else 0
    c_blind = source.randrange(group.q) if blinded else 0
    statement = MatmulStatement(
        rows=bases.rows,
        inner=bases.inner,
        cols=bases.cols,
        a_commitment=commit_matrix(
            group, witness.a, bases.a_bases, bases.blind_base, a_blind
        ),
        b_commitment=commit_matrix(
            group, witness.b, bases.b_bases, bases.blind_base, b_blind
        ),
        c_commitment=commit_matrix(
            group, witness.c, bases.c_bases, bases.blind_base, c_blind
        ),
    )
    witness = MatmulWitness(
        a=witness.a,
        b=witness.b,
        c=witness.c,
        a_blind=a_blind,
        b_blind=b_blind,
        c_blind=c_blind,
    )
    return statement, witness


def _core_challenge(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    transcript_seed: bytes,
) -> int:
    return challenge_scalar(
        group.q,
        "zkmatrix-core-y",
        transcript_seed,
        group.name,
        bases.rows,
        bases.inner,
        bases.cols,
        statement,
    )


def _zk_challenge(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    alpha_commitment: int,
    beta_commitment: int,
    cross_commitment: int,
    alpha_beta_commitment: int,
    transcript_seed: bytes,
) -> int:
    return challenge_scalar(
        group.q,
        "zkmatrix-zk-x",
        transcript_seed,
        group.name,
        bases.rows,
        bases.inner,
        bases.cols,
        statement,
        alpha_commitment,
        beta_commitment,
        cross_commitment,
        alpha_beta_commitment,
    )


def _subproof_challenge(
    group: CyclicGroup,
    domain: str,
    transcript_seed: bytes,
    statement: MatmulStatement,
    commitments: Sequence[int],
) -> int:
    return challenge_scalar(
        group.q,
        domain,
        transcript_seed,
        group.name,
        statement,
        list(commitments),
    )


def _projection_values(
    group: CyclicGroup, witness: MatmulWitness, y: int
) -> Tuple[List[int], List[int], int, List[int], List[int]]:
    y_vector = _powers(y, len(witness.c) * len(witness.c[0]), group.q)
    y_left = [pow(y, i * len(witness.c[0]), group.q) for i in range(len(witness.a))]
    y_right = _powers(y, len(witness.c[0]), group.q)

    ay = []
    for j in range(len(witness.a[0])):
        total = 0
        for i in range(len(witness.a)):
            total = (total + y_left[i] * witness.a[i][j]) % group.q
        ay.append(total)

    by = []
    for i in range(len(witness.b)):
        total = 0
        for j in range(len(witness.b[0])):
            total = (total + witness.b[i][j] * y_right[j]) % group.q
        by.append(total)

    d = inner_product(_flatten(witness.c), y_vector, group.q)
    return y_vector, y_left, d, ay, by


def _a_projection_bases(
    group: CyclicGroup, bases: MatmulBases, y_left: Sequence[int]
) -> List[int]:
    projected = []
    for i in range(bases.rows):
        for j in range(bases.inner):
            projected.append(
                group.add(
                    bases.a_bases[i][j],
                    group.scale(bases.ay_bases[j], y_left[i]),
                )
            )
    return projected


def _b_projection_bases(
    group: CyclicGroup, bases: MatmulBases, y_right: Sequence[int]
) -> List[int]:
    projected = []
    for i in range(bases.inner):
        for j in range(bases.cols):
            projected.append(
                group.add(
                    bases.b_bases[i][j],
                    group.scale(bases.by_bases[i], y_right[j]),
                )
            )
    return projected


def _core_transcript_seed(
    label: bytes,
    group: CyclicGroup,
    statement: MatmulStatement,
    d_commitment: int,
    ay_commitment: int,
    by_commitment: int,
) -> bytes:
    return transcript_bytes(
        label,
        group.name,
        statement,
        d_commitment,
        ay_commitment,
        by_commitment,
    )


def _commit_scalar(
    group: CyclicGroup,
    value: int,
    base: int,
    blind_base: Optional[int] = None,
    blind: int = 0,
) -> int:
    commitment = group.scale(base, value)
    if blind_base is not None and blind:
        commitment = group.add(commitment, group.scale(blind_base, blind))
    return commitment


def _masked_public_inner_product_seed(
    transcript_seed: bytes,
    domain: bytes,
    statement: MatmulStatement,
    input_commitment: int,
    output_commitment: int,
    mask_commitment: int,
    projected_mask_commitment: int,
) -> bytes:
    return transcript_bytes(
        transcript_seed,
        domain,
        statement,
        input_commitment,
        output_commitment,
        mask_commitment,
        projected_mask_commitment,
    )


def _prove_zk_public_inner_product(
    group: CyclicGroup,
    domain: bytes,
    statement: MatmulStatement,
    input_commitment: int,
    output_commitment: int,
    input_values: Sequence[int],
    public_values: Sequence[int],
    input_bases: Sequence[int],
    output_base: int,
    blind_base: int,
    input_blind: int,
    output_blind: int,
    transcript_seed: bytes,
    rng: random.Random,
) -> ZkProjectionProof:
    """Mask a private vector/public-vector inner product relation."""

    if len(input_values) != len(public_values) or len(input_values) != len(input_bases):
        raise ValueError("inner-product masking input length mismatch")

    alpha = _random_vector(len(input_values), group.q, rng=rng)
    projected_alpha = inner_product(alpha, public_values, group.q)
    alpha_blind = rng.randrange(group.q)
    projected_alpha_blind = rng.randrange(group.q)
    mask_commitment = commit_vector(
        group, alpha, input_bases, blind_base, alpha_blind
    )
    projected_mask_commitment = _commit_scalar(
        group, projected_alpha, output_base, blind_base, projected_alpha_blind
    )
    challenge_seed = _masked_public_inner_product_seed(
        transcript_seed,
        domain,
        statement,
        input_commitment,
        output_commitment,
        mask_commitment,
        projected_mask_commitment,
    )
    x = _subproof_challenge(
        group,
        f"{domain.decode('ascii')}-mask",
        challenge_seed,
        statement,
        [input_commitment, output_commitment, mask_commitment, projected_mask_commitment],
    )
    masked_values = _vector_add(input_values, _vector_scale(alpha, x, group.q), group.q)
    response_blind = (input_blind + x * alpha_blind) % group.q
    projected_response_blind = (
        output_blind + x * projected_alpha_blind
    ) % group.q
    masked_input_commitment = group.add(
        group.add(input_commitment, group.scale(mask_commitment, x)),
        group.scale(blind_base, -response_blind),
    )
    masked_output_commitment = group.add(
        group.add(output_commitment, group.scale(projected_mask_commitment, x)),
        group.scale(blind_base, -projected_response_blind),
    )
    proof = prove_inner_product(
        group,
        group.add(masked_output_commitment, masked_input_commitment),
        output_base,
        input_bases,
        [group.identity] * len(input_bases),
        masked_values,
        public_values,
        challenge_seed + b":inner-product",
    )
    return ZkProjectionProof(
        mask_commitment=mask_commitment,
        projected_mask_commitment=projected_mask_commitment,
        response_blind=response_blind,
        projected_response_blind=projected_response_blind,
        proof=proof,
    )


def _verify_zk_public_inner_product(
    group: CyclicGroup,
    domain: bytes,
    statement: MatmulStatement,
    input_commitment: int,
    output_commitment: int,
    public_values: Sequence[int],
    input_bases: Sequence[int],
    output_base: int,
    blind_base: int,
    proof: ZkProjectionProof,
    transcript_seed: bytes,
) -> bool:
    if len(public_values) != len(input_bases):
        return False
    challenge_seed = _masked_public_inner_product_seed(
        transcript_seed,
        domain,
        statement,
        input_commitment,
        output_commitment,
        proof.mask_commitment,
        proof.projected_mask_commitment,
    )
    x = _subproof_challenge(
        group,
        f"{domain.decode('ascii')}-mask",
        challenge_seed,
        statement,
        [
            input_commitment,
            output_commitment,
            proof.mask_commitment,
            proof.projected_mask_commitment,
        ],
    )
    masked_input_commitment = group.add(
        group.add(input_commitment, group.scale(proof.mask_commitment, x)),
        group.scale(blind_base, -proof.response_blind),
    )
    masked_output_commitment = group.add(
        group.add(output_commitment, group.scale(proof.projected_mask_commitment, x)),
        group.scale(blind_base, -proof.projected_response_blind),
    )
    return verify_inner_product(
        group,
        group.add(masked_output_commitment, masked_input_commitment),
        output_base,
        input_bases,
        [group.identity] * len(input_bases),
        proof.proof,
        challenge_seed + b":inner-product",
    )


def _prove_zk_commitment_projection(
    group: CyclicGroup,
    domain: bytes,
    statement: MatmulStatement,
    input_commitment: int,
    output_commitment: int,
    input_values: Matrix,
    projection_values: Sequence[int],
    input_bases: Matrix,
    output_bases: Sequence[int],
    projected_bases: Sequence[int],
    projection_axis: str,
    blind_base: int,
    input_blind: int,
    output_blind: int,
    transcript_seed: bytes,
    rng: random.Random,
) -> ZkProjectionProof:
    """Mask a high-dimensional linear projection relation."""

    if len(_flatten(input_values)) != len(projected_bases):
        raise ValueError("projection masking input length mismatch")

    rows, cols = _shape(input_values)
    alpha = random_matrix(rows, cols, group.q, rng=rng)
    if projection_axis == "rows":
        if len(projection_values) != rows:
            raise ValueError("row projection vector has the wrong length")
        projected_alpha = []
        for col in range(cols):
            total = 0
            for row in range(rows):
                total = (total + projection_values[row] * alpha[row][col]) % group.q
            projected_alpha.append(total)
    elif projection_axis == "cols":
        if len(projection_values) != cols:
            raise ValueError("column projection vector has the wrong length")
        projected_alpha = []
        for row in range(rows):
            total = 0
            for col in range(cols):
                total = (total + alpha[row][col] * projection_values[col]) % group.q
            projected_alpha.append(total)
    else:
        raise ValueError("projection_axis must be 'rows' or 'cols'")

    alpha_blind = rng.randrange(group.q)
    projected_alpha_blind = rng.randrange(group.q)
    mask_commitment = commit_matrix(
        group, alpha, input_bases, blind_base, alpha_blind
    )
    projected_mask_commitment = commit_vector(
        group, projected_alpha, output_bases, blind_base, projected_alpha_blind
    )
    challenge_seed = _masked_public_inner_product_seed(
        transcript_seed,
        domain,
        statement,
        input_commitment,
        output_commitment,
        mask_commitment,
        projected_mask_commitment,
    )
    x = _subproof_challenge(
        group,
        f"{domain.decode('ascii')}-mask",
        challenge_seed,
        statement,
        [input_commitment, output_commitment, mask_commitment, projected_mask_commitment],
    )
    masked_matrix = _matrix_add(input_values, _matrix_scale(alpha, x, group.q), group.q)
    response_blind = (input_blind + x * alpha_blind) % group.q
    projected_response_blind = (
        output_blind + x * projected_alpha_blind
    ) % group.q
    masked_input_commitment = group.add(
        group.add(input_commitment, group.scale(mask_commitment, x)),
        group.scale(blind_base, -response_blind),
    )
    masked_output_commitment = group.add(
        group.add(output_commitment, group.scale(projected_mask_commitment, x)),
        group.scale(blind_base, -projected_response_blind),
    )
    proof = prove_inner_product(
        group,
        group.add(masked_input_commitment, masked_output_commitment),
        group.identity,
        projected_bases,
        [group.identity] * len(projected_bases),
        _flatten(masked_matrix),
        [0] * len(projected_bases),
        challenge_seed + b":commitment-projection",
    )
    return ZkProjectionProof(
        mask_commitment=mask_commitment,
        projected_mask_commitment=projected_mask_commitment,
        response_blind=response_blind,
        projected_response_blind=projected_response_blind,
        proof=proof,
    )


def _verify_zk_commitment_projection(
    group: CyclicGroup,
    domain: bytes,
    statement: MatmulStatement,
    input_commitment: int,
    output_commitment: int,
    projected_bases: Sequence[int],
    blind_base: int,
    proof: ZkProjectionProof,
    transcript_seed: bytes,
) -> bool:
    challenge_seed = _masked_public_inner_product_seed(
        transcript_seed,
        domain,
        statement,
        input_commitment,
        output_commitment,
        proof.mask_commitment,
        proof.projected_mask_commitment,
    )
    x = _subproof_challenge(
        group,
        f"{domain.decode('ascii')}-mask",
        challenge_seed,
        statement,
        [
            input_commitment,
            output_commitment,
            proof.mask_commitment,
            proof.projected_mask_commitment,
        ],
    )
    masked_input_commitment = group.add(
        group.add(input_commitment, group.scale(proof.mask_commitment, x)),
        group.scale(blind_base, -proof.response_blind),
    )
    masked_output_commitment = group.add(
        group.add(output_commitment, group.scale(proof.projected_mask_commitment, x)),
        group.scale(blind_base, -proof.projected_response_blind),
    )
    return verify_inner_product(
        group,
        group.add(masked_input_commitment, masked_output_commitment),
        group.identity,
        projected_bases,
        [group.identity] * len(projected_bases),
        proof.proof,
        challenge_seed + b":commitment-projection",
    )


def _masked_product_seed(
    transcript_seed: bytes,
    statement: MatmulStatement,
    output_commitment: int,
    left_commitment: int,
    right_commitment: int,
    alpha_commitment: int,
    beta_commitment: int,
    cross_commitment: int,
    alpha_beta_commitment: int,
) -> bytes:
    return transcript_bytes(
        transcript_seed,
        b"zk-product",
        statement,
        output_commitment,
        left_commitment,
        right_commitment,
        alpha_commitment,
        beta_commitment,
        cross_commitment,
        alpha_beta_commitment,
    )


def _prove_zk_product_projection(
    group: CyclicGroup,
    statement: MatmulStatement,
    output_commitment: int,
    left_commitment: int,
    right_commitment: int,
    left_values: Sequence[int],
    right_values: Sequence[int],
    output_base: int,
    left_bases: Sequence[int],
    right_bases: Sequence[int],
    blind_base: int,
    output_blind: int,
    left_blind: int,
    right_blind: int,
    transcript_seed: bytes,
    rng: random.Random,
) -> ZkProductProjectionProof:
    if not (
        len(left_values)
        == len(right_values)
        == len(left_bases)
        == len(right_bases)
    ):
        raise ValueError("product projection length mismatch")

    alpha = _random_vector(len(left_values), group.q, rng=rng)
    beta = _random_vector(len(right_values), group.q, rng=rng)
    alpha_beta = inner_product(alpha, beta, group.q)
    cross = (
        inner_product(alpha, right_values, group.q)
        + inner_product(left_values, beta, group.q)
    ) % group.q

    alpha_blind = rng.randrange(group.q)
    beta_blind = rng.randrange(group.q)
    cross_blind = rng.randrange(group.q)
    alpha_beta_blind = rng.randrange(group.q)

    alpha_commitment = commit_vector(
        group, alpha, left_bases, blind_base, alpha_blind
    )
    beta_commitment = commit_vector(group, beta, right_bases, blind_base, beta_blind)
    cross_commitment = _commit_scalar(
        group, cross, output_base, blind_base, cross_blind
    )
    alpha_beta_commitment = _commit_scalar(
        group, alpha_beta, output_base, blind_base, alpha_beta_blind
    )
    challenge_seed = _masked_product_seed(
        transcript_seed,
        statement,
        output_commitment,
        left_commitment,
        right_commitment,
        alpha_commitment,
        beta_commitment,
        cross_commitment,
        alpha_beta_commitment,
    )
    x = _subproof_challenge(
        group,
        "zk-product-mask",
        challenge_seed,
        statement,
        [
            output_commitment,
            left_commitment,
            right_commitment,
            alpha_commitment,
            beta_commitment,
            cross_commitment,
            alpha_beta_commitment,
        ],
    )
    x2 = (x * x) % group.q
    left_response_blind = (left_blind + x * alpha_blind) % group.q
    right_response_blind = (right_blind + x * beta_blind) % group.q
    output_response_blind = (
        output_blind + x * cross_blind + x2 * alpha_beta_blind
    ) % group.q
    masked_left = _vector_add(left_values, _vector_scale(alpha, x, group.q), group.q)
    masked_right = _vector_add(right_values, _vector_scale(beta, x, group.q), group.q)

    masked_left_commitment = group.add(
        group.add(left_commitment, group.scale(alpha_commitment, x)),
        group.scale(blind_base, -left_response_blind),
    )
    masked_right_commitment = group.add(
        group.add(right_commitment, group.scale(beta_commitment, x)),
        group.scale(blind_base, -right_response_blind),
    )
    masked_output_commitment = group.add(
        group.add(
            group.add(output_commitment, group.scale(cross_commitment, x)),
            group.scale(alpha_beta_commitment, x2),
        ),
        group.scale(blind_base, -output_response_blind),
    )
    proof = prove_inner_product(
        group,
        group.add(
            group.add(masked_output_commitment, masked_left_commitment),
            masked_right_commitment,
        ),
        output_base,
        left_bases,
        right_bases,
        masked_left,
        masked_right,
        challenge_seed + b":product-projection",
    )
    return ZkProductProjectionProof(
        alpha_commitment=alpha_commitment,
        beta_commitment=beta_commitment,
        cross_commitment=cross_commitment,
        alpha_beta_commitment=alpha_beta_commitment,
        left_response_blind=left_response_blind,
        right_response_blind=right_response_blind,
        output_response_blind=output_response_blind,
        proof=proof,
    )


def _verify_zk_product_projection(
    group: CyclicGroup,
    statement: MatmulStatement,
    output_commitment: int,
    left_commitment: int,
    right_commitment: int,
    output_base: int,
    left_bases: Sequence[int],
    right_bases: Sequence[int],
    blind_base: int,
    proof: ZkProductProjectionProof,
    transcript_seed: bytes,
) -> bool:
    challenge_seed = _masked_product_seed(
        transcript_seed,
        statement,
        output_commitment,
        left_commitment,
        right_commitment,
        proof.alpha_commitment,
        proof.beta_commitment,
        proof.cross_commitment,
        proof.alpha_beta_commitment,
    )
    x = _subproof_challenge(
        group,
        "zk-product-mask",
        challenge_seed,
        statement,
        [
            output_commitment,
            left_commitment,
            right_commitment,
            proof.alpha_commitment,
            proof.beta_commitment,
            proof.cross_commitment,
            proof.alpha_beta_commitment,
        ],
    )
    x2 = (x * x) % group.q
    masked_left_commitment = group.add(
        group.add(left_commitment, group.scale(proof.alpha_commitment, x)),
        group.scale(blind_base, -proof.left_response_blind),
    )
    masked_right_commitment = group.add(
        group.add(right_commitment, group.scale(proof.beta_commitment, x)),
        group.scale(blind_base, -proof.right_response_blind),
    )
    masked_output_commitment = group.add(
        group.add(
            group.add(output_commitment, group.scale(proof.cross_commitment, x)),
            group.scale(proof.alpha_beta_commitment, x2),
        ),
        group.scale(blind_base, -proof.output_response_blind),
    )
    return verify_inner_product(
        group,
        group.add(
            group.add(masked_output_commitment, masked_left_commitment),
            masked_right_commitment,
        ),
        output_base,
        left_bases,
        right_bases,
        proof.proof,
        challenge_seed + b":product-projection",
    )


def prove_core_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    witness: MatmulWitness,
    *,
    transcript_seed: bytes = b"",
) -> CoreMatmulProof:
    """Prove a committed matrix multiplication statement.

    This is Algorithm 4's algebraic core. The supplied statement must be
    unblinded; use ``prove_zk_matmul`` for a masked privacy-preserving wrapper.
    """

    _validate_witness(statement, witness)
    y = _core_challenge(group, bases, statement, transcript_seed)
    y_vector, y_left, _d_unused, ay, by = _projection_values(group, witness, y)
    d = inner_product(_flatten(witness.c), y_vector, group.q)

    d_commitment = group.scale(bases.scalar_base, d)
    ay_commitment = commit_vector(group, ay, bases.ay_bases)
    by_commitment = commit_vector(group, by, bases.by_bases)
    proof_seed = _core_transcript_seed(
        transcript_seed, group, statement, d_commitment, ay_commitment, by_commitment
    )

    c_projection_commitment = group.add(d_commitment, statement.c_commitment)
    c_projection_proof = prove_inner_product(
        group,
        c_projection_commitment,
        bases.scalar_base,
        _flatten(bases.c_bases),
        [group.identity] * (bases.rows * bases.cols),
        _flatten(witness.c),
        y_vector,
        proof_seed + b":c-projection",
    )

    a_projection_commitment = group.add(statement.a_commitment, ay_commitment)
    a_projection_proof = prove_inner_product(
        group,
        a_projection_commitment,
        group.identity,
        _a_projection_bases(group, bases, y_left),
        [group.identity] * (bases.rows * bases.inner),
        _flatten(witness.a),
        [0] * (bases.rows * bases.inner),
        proof_seed + b":a-projection",
    )

    y_right = _powers(y, bases.cols, group.q)
    b_projection_commitment = group.add(statement.b_commitment, by_commitment)
    b_projection_proof = prove_inner_product(
        group,
        b_projection_commitment,
        group.identity,
        _b_projection_bases(group, bases, y_right),
        [group.identity] * (bases.inner * bases.cols),
        _flatten_b_by_rows(witness.b),
        [0] * (bases.inner * bases.cols),
        proof_seed + b":b-projection",
    )

    product_projection_commitment = group.add(
        group.add(d_commitment, ay_commitment), by_commitment
    )
    product_projection_proof = prove_inner_product(
        group,
        product_projection_commitment,
        bases.scalar_base,
        bases.ay_bases,
        bases.by_bases,
        ay,
        by,
        proof_seed + b":product-projection",
    )

    return CoreMatmulProof(
        d_commitment=d_commitment,
        ay_commitment=ay_commitment,
        by_commitment=by_commitment,
        c_projection_proof=c_projection_proof,
        a_projection_proof=a_projection_proof,
        b_projection_proof=b_projection_proof,
        product_projection_proof=product_projection_proof,
    )


def verify_core_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    proof: CoreMatmulProof,
    *,
    transcript_seed: bytes = b"",
) -> bool:
    """Verify a core committed matrix multiplication proof."""

    if (statement.rows, statement.inner, statement.cols) != (
        bases.rows,
        bases.inner,
        bases.cols,
    ):
        return False

    y = _core_challenge(group, bases, statement, transcript_seed)
    y_vector = _powers(y, bases.rows * bases.cols, group.q)
    y_left = [pow(y, i * bases.cols, group.q) for i in range(bases.rows)]
    y_right = _powers(y, bases.cols, group.q)
    proof_seed = _core_transcript_seed(
        transcript_seed,
        group,
        statement,
        proof.d_commitment,
        proof.ay_commitment,
        proof.by_commitment,
    )

    c_ok = verify_inner_product(
        group,
        group.add(proof.d_commitment, statement.c_commitment),
        bases.scalar_base,
        _flatten(bases.c_bases),
        [group.identity] * (bases.rows * bases.cols),
        proof.c_projection_proof,
        proof_seed + b":c-projection",
    )
    if not c_ok:
        return False

    a_ok = verify_inner_product(
        group,
        group.add(statement.a_commitment, proof.ay_commitment),
        group.identity,
        _a_projection_bases(group, bases, y_left),
        [group.identity] * (bases.rows * bases.inner),
        proof.a_projection_proof,
        proof_seed + b":a-projection",
    )
    if not a_ok:
        return False

    b_ok = verify_inner_product(
        group,
        group.add(statement.b_commitment, proof.by_commitment),
        group.identity,
        _b_projection_bases(group, bases, y_right),
        [group.identity] * (bases.inner * bases.cols),
        proof.b_projection_proof,
        proof_seed + b":b-projection",
    )
    if not b_ok:
        return False

    return verify_inner_product(
        group,
        group.add(group.add(proof.d_commitment, proof.ay_commitment), proof.by_commitment),
        bases.scalar_base,
        bases.ay_bases,
        bases.by_bases,
        proof.product_projection_proof,
        proof_seed + b":product-projection",
    )


def prove_naive_zk_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    witness: MatmulWitness,
    *,
    transcript_seed: bytes = b"",
    rng: Optional[random.Random] = None,
) -> NaiveZkMatmulProof:
    """Apply Algorithm 5 directly to the whole matrix multiplication.

    The paper presents this wrapper as the conceptual ZK transform, then notes
    that its line 3 costs O(n^3) for square matrices. The optimized
    ``prove_zk_matmul`` below moves the same masking idea into the subprotocols.
    """

    _validate_witness(statement, witness)
    source = rng if rng is not None else secrets.SystemRandom()

    alpha = random_matrix(bases.rows, bases.inner, group.q, rng=source)
    beta = random_matrix(bases.inner, bases.cols, group.q, rng=source)
    alpha_beta = matrix_multiply(alpha, beta, group.q)
    alpha_b = matrix_multiply(alpha, witness.b, group.q)
    a_beta = matrix_multiply(witness.a, beta, group.q)
    cross = _matrix_add(alpha_b, a_beta, group.q)

    alpha_blind = source.randrange(group.q)
    beta_blind = source.randrange(group.q)
    cross_blind = source.randrange(group.q)
    alpha_beta_blind = source.randrange(group.q)

    alpha_commitment = commit_matrix(
        group, alpha, bases.a_bases, bases.blind_base, alpha_blind
    )
    beta_commitment = commit_matrix(
        group, beta, bases.b_bases, bases.blind_base, beta_blind
    )
    cross_commitment = commit_matrix(
        group, cross, bases.c_bases, bases.blind_base, cross_blind
    )
    alpha_beta_commitment = commit_matrix(
        group, alpha_beta, bases.c_bases, bases.blind_base, alpha_beta_blind
    )

    x = _zk_challenge(
        group,
        bases,
        statement,
        alpha_commitment,
        beta_commitment,
        cross_commitment,
        alpha_beta_commitment,
        transcript_seed,
    )
    x2 = (x * x) % group.q

    masked_a = _matrix_add(witness.a, _matrix_scale(alpha, x, group.q), group.q)
    masked_b = _matrix_add(witness.b, _matrix_scale(beta, x, group.q), group.q)
    masked_c = _matrix_add(
        _matrix_add(witness.c, _matrix_scale(cross, x, group.q), group.q),
        _matrix_scale(alpha_beta, x2, group.q),
        group.q,
    )

    a_response_blind = (witness.a_blind + x * alpha_blind) % group.q
    b_response_blind = (witness.b_blind + x * beta_blind) % group.q
    c_response_blind = (
        witness.c_blind + x * cross_blind + x2 * alpha_beta_blind
    ) % group.q

    masked_statement = MatmulStatement(
        rows=bases.rows,
        inner=bases.inner,
        cols=bases.cols,
        a_commitment=group.add(
            group.add(statement.a_commitment, group.scale(alpha_commitment, x)),
            group.scale(bases.blind_base, -a_response_blind),
        ),
        b_commitment=group.add(
            group.add(statement.b_commitment, group.scale(beta_commitment, x)),
            group.scale(bases.blind_base, -b_response_blind),
        ),
        c_commitment=group.add(
            group.add(
                group.add(statement.c_commitment, group.scale(cross_commitment, x)),
                group.scale(alpha_beta_commitment, x2),
            ),
            group.scale(bases.blind_base, -c_response_blind),
        ),
    )
    masked_witness = MatmulWitness(a=masked_a, b=masked_b, c=masked_c)
    core_seed = transcript_bytes(
        b"zk-wrapper-core",
        transcript_seed,
        x,
        alpha_commitment,
        beta_commitment,
        cross_commitment,
        alpha_beta_commitment,
    )
    core_proof = prove_core_matmul(
        group,
        bases,
        masked_statement,
        masked_witness,
        transcript_seed=core_seed,
    )

    return NaiveZkMatmulProof(
        alpha_commitment=alpha_commitment,
        beta_commitment=beta_commitment,
        cross_commitment=cross_commitment,
        alpha_beta_commitment=alpha_beta_commitment,
        a_response_blind=a_response_blind,
        b_response_blind=b_response_blind,
        c_response_blind=c_response_blind,
        core_proof=core_proof,
    )


def verify_naive_zk_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    proof: NaiveZkMatmulProof,
    *,
    transcript_seed: bytes = b"",
) -> bool:
    """Verify the direct Algorithm 5 wrapper."""

    x = _zk_challenge(
        group,
        bases,
        statement,
        proof.alpha_commitment,
        proof.beta_commitment,
        proof.cross_commitment,
        proof.alpha_beta_commitment,
        transcript_seed,
    )
    x2 = (x * x) % group.q
    masked_statement = MatmulStatement(
        rows=bases.rows,
        inner=bases.inner,
        cols=bases.cols,
        a_commitment=group.add(
            group.add(statement.a_commitment, group.scale(proof.alpha_commitment, x)),
            group.scale(bases.blind_base, -proof.a_response_blind),
        ),
        b_commitment=group.add(
            group.add(statement.b_commitment, group.scale(proof.beta_commitment, x)),
            group.scale(bases.blind_base, -proof.b_response_blind),
        ),
        c_commitment=group.add(
            group.add(
                group.add(statement.c_commitment, group.scale(proof.cross_commitment, x)),
                group.scale(proof.alpha_beta_commitment, x2),
            ),
            group.scale(bases.blind_base, -proof.c_response_blind),
        ),
    )
    core_seed = transcript_bytes(
        b"zk-wrapper-core",
        transcript_seed,
        x,
        proof.alpha_commitment,
        proof.beta_commitment,
        proof.cross_commitment,
        proof.alpha_beta_commitment,
    )
    return verify_core_matmul(
        group,
        bases,
        masked_statement,
        proof.core_proof,
        transcript_seed=core_seed,
    )


def prove_zk_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    witness: MatmulWitness,
    *,
    transcript_seed: bytes = b"",
    rng: Optional[random.Random] = None,
) -> ZkMatmulProof:
    """Prove committed matrix multiplication with subprotocol-level masking.

    This is the implementation path described after Algorithm 5: the prover
    computes the Algorithm 4 projections, commits to them with Pedersen
    blindings, and adds random masks inside the three semi-inner-product
    projections and the final Bulletproof inner product.
    """

    _validate_witness(statement, witness)
    source = rng if rng is not None else secrets.SystemRandom()
    y = _core_challenge(group, bases, statement, transcript_seed)
    y_vector, y_left, d, ay, by = _projection_values(group, witness, y)
    y_right = _powers(y, bases.cols, group.q)

    d_blind = source.randrange(group.q)
    ay_blind = source.randrange(group.q)
    by_blind = source.randrange(group.q)
    d_commitment = _commit_scalar(
        group, d, bases.scalar_base, bases.blind_base, d_blind
    )
    ay_commitment = commit_vector(
        group, ay, bases.ay_bases, bases.blind_base, ay_blind
    )
    by_commitment = commit_vector(
        group, by, bases.by_bases, bases.blind_base, by_blind
    )
    proof_seed = _core_transcript_seed(
        transcript_seed, group, statement, d_commitment, ay_commitment, by_commitment
    )

    c_projection_proof = _prove_zk_public_inner_product(
        group,
        b"c-projection",
        statement,
        statement.c_commitment,
        d_commitment,
        _flatten(witness.c),
        y_vector,
        _flatten(bases.c_bases),
        bases.scalar_base,
        bases.blind_base,
        witness.c_blind,
        d_blind,
        proof_seed,
        source,
    )
    a_projection_proof = _prove_zk_commitment_projection(
        group,
        b"a-projection",
        statement,
        statement.a_commitment,
        ay_commitment,
        witness.a,
        y_left,
        bases.a_bases,
        bases.ay_bases,
        _a_projection_bases(group, bases, y_left),
        "rows",
        bases.blind_base,
        witness.a_blind,
        ay_blind,
        proof_seed,
        source,
    )
    b_projection_proof = _prove_zk_commitment_projection(
        group,
        b"b-projection",
        statement,
        statement.b_commitment,
        by_commitment,
        witness.b,
        y_right,
        bases.b_bases,
        bases.by_bases,
        _b_projection_bases(group, bases, y_right),
        "cols",
        bases.blind_base,
        witness.b_blind,
        by_blind,
        proof_seed,
        source,
    )
    product_projection_proof = _prove_zk_product_projection(
        group,
        statement,
        d_commitment,
        ay_commitment,
        by_commitment,
        ay,
        by,
        bases.scalar_base,
        bases.ay_bases,
        bases.by_bases,
        bases.blind_base,
        d_blind,
        ay_blind,
        by_blind,
        proof_seed,
        source,
    )
    return ZkMatmulProof(
        d_commitment=d_commitment,
        ay_commitment=ay_commitment,
        by_commitment=by_commitment,
        c_projection_proof=c_projection_proof,
        a_projection_proof=a_projection_proof,
        b_projection_proof=b_projection_proof,
        product_projection_proof=product_projection_proof,
    )


def verify_zk_matmul(
    group: CyclicGroup,
    bases: MatmulBases,
    statement: MatmulStatement,
    proof: ZkMatmulProof,
    *,
    transcript_seed: bytes = b"",
) -> bool:
    """Verify the optimized zero-knowledge matrix multiplication proof."""

    if (statement.rows, statement.inner, statement.cols) != (
        bases.rows,
        bases.inner,
        bases.cols,
    ):
        return False

    y = _core_challenge(group, bases, statement, transcript_seed)
    y_vector = _powers(y, bases.rows * bases.cols, group.q)
    y_left = [pow(y, i * bases.cols, group.q) for i in range(bases.rows)]
    y_right = _powers(y, bases.cols, group.q)
    proof_seed = _core_transcript_seed(
        transcript_seed,
        group,
        statement,
        proof.d_commitment,
        proof.ay_commitment,
        proof.by_commitment,
    )

    c_ok = _verify_zk_public_inner_product(
        group,
        b"c-projection",
        statement,
        statement.c_commitment,
        proof.d_commitment,
        y_vector,
        _flatten(bases.c_bases),
        bases.scalar_base,
        bases.blind_base,
        proof.c_projection_proof,
        proof_seed,
    )
    if not c_ok:
        return False

    a_ok = _verify_zk_commitment_projection(
        group,
        b"a-projection",
        statement,
        statement.a_commitment,
        proof.ay_commitment,
        _a_projection_bases(group, bases, y_left),
        bases.blind_base,
        proof.a_projection_proof,
        proof_seed,
    )
    if not a_ok:
        return False

    b_ok = _verify_zk_commitment_projection(
        group,
        b"b-projection",
        statement,
        statement.b_commitment,
        proof.by_commitment,
        _b_projection_bases(group, bases, y_right),
        bases.blind_base,
        proof.b_projection_proof,
        proof_seed,
    )
    if not b_ok:
        return False

    return _verify_zk_product_projection(
        group,
        statement,
        proof.d_commitment,
        proof.ay_commitment,
        proof.by_commitment,
        bases.scalar_base,
        bases.ay_bases,
        bases.by_bases,
        bases.blind_base,
        proof.product_projection_proof,
        proof_seed,
    )
