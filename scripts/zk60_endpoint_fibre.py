#!/usr/bin/env python3
"""Sample endpoint PCS preimages conditional on an ALREADY GIVEN field view.

Research only. This does not generate the public field view, simulate A/H/CFS,
or solve arbitrary external roots. It samples masks and pads for chosen dummy
data while keeping both full vectors, the terminal and every opened column.
All challenges are fixed. Uniformity is in the ideal independent-Fp model;
production PRG/Fiat-Shamir distributions are not established by this tool.
"""
import argparse
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path
import secrets

import zk60_endpoint_simulation as sim
import zk60_io_opening_translation as T
import zk60_io_repeated_view as repeated

C, P, ZERO = T.C, T.P, T.ZERO
require = T.require
ROOT = Path(__file__).resolve().parents[1]


def canonical(x):
    return type(x) is int and 0 <= x < P


class LinearFibre:
    """Full-row-rank base-field system with explicit free coordinates."""
    def __init__(self, matrix):
        require(bool(matrix) and bool(matrix[0]), "empty linear system")
        self.m, self.n = len(matrix), len(matrix[0])
        require(all(len(row) == self.n and all(canonical(x) for x in row)
                    for row in matrix), "linear matrix geometry/field")
        a = [list(row) + [int(i == j) for j in range(self.m)]
             for i, row in enumerate(matrix)]
        self.pivots = []
        for col in range(self.n):
            at = len(self.pivots)
            pivot = next((i for i in range(at, self.m) if a[i][col]), None)
            if pivot is None:
                continue
            a[at], a[pivot] = a[pivot], a[at]
            inv = pow(a[at][col], P - 2, P)
            a[at] = [v * inv % P for v in a[at]]
            for i in range(self.m):
                if i != at and a[i][col]:
                    factor = a[i][col]
                    a[i] = [(x - factor*y) % P for x, y in zip(a[i], a[at])]
            self.pivots.append(col)
            if len(self.pivots) == self.m:
                break
        require(len(self.pivots) == self.m, "deficient mask/fold rank")
        self.free = [i for i in range(self.n) if i not in self.pivots]
        self.reduced = [row[:self.n] for row in a]
        self.transform = [row[self.n:] for row in a]

    def solve(self, rhs, free):
        require(len(rhs) == self.m and len(free) == len(self.free)
                and all(canonical(x) for x in list(rhs) + list(free)), "linear RHS/free coordinates")
        out = [0] * self.n
        for i, value in zip(self.free, free):
            out[i] = value
        for row, change, pivot in zip(self.reduced, self.transform, self.pivots):
            out[pivot] = (sum(a*b for a, b in zip(change, rhs))
                          - sum(row[i]*out[i] for i in self.free)) % P
        return out


def split_folds(folds):
    return [[x[part] for x in fold] for fold in folds for part in (0, 1)]


def conditional_poly(xs, ys, budget, randbelow=secrets.randbelow):
    """Uniform degree < budget polynomial with prescribed distinct evaluations.

    L + product(X-x_i) h is a bijection from degree < budget-q polynomials h
    onto this affine fibre. Empty constraints and q=budget are included.
    """
    require(type(budget) is int and budget > 0 and len(xs) == len(ys)
            and len(set(xs)) == len(xs) and len(xs) <= budget,
            "conditional polynomial nodes/budget")
    require(all(canonical(x) for x in list(xs) + list(ys)), "polynomial field words")
    particular = T.interpolate(xs, [(y, 0) for y in ys]) if xs else []
    if len(xs) < budget:
        vanish = T.roots_poly(xs)
        h = [(randbelow(P), 0) for _ in range(budget - len(xs))]
        require(all(canonical(x[0]) for x in h), "random field word")
        noise = T.mul(vanish, h)
    else:
        noise = []
    return [((particular[i][0] if i < len(particular) else 0)
             + (noise[i][0] if i < len(noise) else 0)) % P for i in range(budget)]


@dataclass
class EndpointView:
    folds: list
    vectors: list
    claim_weights: list
    claim_cw: list
    claim_value: tuple
    indices: list
    columns: list
    n: int = 256
    budget: int = 256
    domain: int = 2048

    def validate(self):
        require(self.n > 0 and not self.n & (self.n-1) and 0 < self.budget <= self.n
                and self.domain == 8*self.n, "endpoint geometry")
        require(len(self.folds) == len(self.vectors) == 2
                and all(len(row) == 7 for row in self.folds)
                and all(len(v) == self.n+self.budget for v in self.vectors)
                and len(self.claim_weights) == 7 and len(self.claim_cw) == self.n,
                "endpoint fold/vector/claim geometry")
        pairs = [x for row in self.folds + self.vectors for x in row]
        pairs += self.claim_weights + self.claim_cw + [self.claim_value]
        require(all(len(x) == 2 and all(canonical(y) for y in x) for x in pairs),
                "endpoint extension field words")
        at = next((i for i, x in enumerate(self.claim_weights) if x != ZERO), None)
        require(at is not None, "zero endpoint claim")
        lam = C.f2_mul(self.folds[0][at], C.f2_inv(self.claim_weights[at]))
        require(lam != ZERO and self.folds[0] == [C.f2_mul(lam, x) for x in self.claim_weights],
                "endpoint claim is not the single folded claim")
        require(C.f2_dot(self.claim_cw, self.vectors[0][:self.n]) == C.f2_mul(lam, self.claim_value),
                "public individual terminal inconsistency")
        require(len(self.indices) == len(self.columns) == self.budget, "endpoint query budget")
        seen = {}
        for index, column in zip(self.indices, self.columns):
            require(type(index) is int and 0 <= index < self.domain, "endpoint query index")
            require(len(column) == 7 and all(canonical(x) for x in column), "endpoint column words")
            require(index not in seen or seen[index] == column, "conflicting duplicate column")
            seen[index] = column
        # Refuse inconsistent public observations before attempting a preimage.
        for weights, vector in zip(self.folds, self.vectors):
            enc = T.coset_evals(T.pcs_poly(vector[:self.n], vector[self.n:]), self.domain)
            require(all(C.f2_dot(weights, [(x, 0) for x in column]) == enc[index]
                        for index, column in seen.items()), "public fold/column inconsistency")


def from_capture(role, obs):
    require(role["role"] in ("Input", "Output") and obs.role == role["role"], "endpoint role")
    require(len(role["claims"]) == len(role["groups"]) == 1
            and role["groups"][0]["members"] == [0]
            and not role["public_linear_constraints"]
            and [x["kind"] for x in role["row_roles"]] == ["data"]*2 + ["mask"]*2 + ["prox"]*3,
            "unsupported endpoint layout")
    folds, constraints = T.pcs_matrices(role)
    return EndpointView(folds, [[tuple(x) for x in role["groups"][0]["vector"]],
                                [tuple(x) for x in role["proximity_vector"]]],
                        constraints[0], obs.groups[0]["cw"], tuple(role["claims"][0]["value"]),
                        [x["index"] for x in role["columns"]],
                        [x["values"] for x in role["columns"]],
                        n=obs.n, budget=role["q_pad"], domain=8*obs.n)


def sample(view, data, randbelow=secrets.randbelow):
    view.validate()
    require(len(data) == 2 and all(len(row) == view.n and all(canonical(x) for x in row)
                                 for row in data), "chosen dummy data geometry/field")
    matrix = split_folds(view.folds)
    mask = LinearFibre([row[2:] for row in matrix])
    pads = LinearFibre(matrix)
    message = [list(row) for row in data] + [[0]*view.n for _ in range(5)]
    for j in range(view.n):
        rhs = [view.vectors[i//2][j][i%2] for i in range(4)]
        rhs = [(v - sum(matrix[i][r]*data[r][j] for r in range(2))) % P
               for i, v in enumerate(rhs)]
        column = mask.solve(rhs, [randbelow(P) for _ in mask.free])
        for r, value in enumerate(column, 2):
            message[r][j] = value

    # The free pad ROWS are the kernel coordinates of the four fold equations.
    # Each polynomial's q evaluations are fixed by its sampled row columns.
    unique = dict(zip(view.indices, view.columns))
    indices = sorted(unique)
    roots = T.subgroup(view.domain)
    xs = [7*roots[j] % P for j in indices]
    zs = [(pow(x, view.n, P)-1) % P for x in xs]
    require(all(zs), "sample intersects message subgroup")
    zs_inv = [pow(z, P-2, P) for z in zs]
    free_pad = {}
    for r in pads.free:
        f = T.transform([(x, 0) for x in message[r]], True)
        ys = [(unique[j][r] - T.evaluate(f, x)[0])*inv % P
              for j, x, inv in zip(indices, xs, zs_inv)]
        free_pad[r] = conditional_poly(xs, ys, view.budget, randbelow)
    pad_rows = [[0]*view.budget for _ in range(7)]
    for j in range(view.budget):
        rhs = [view.vectors[i//2][view.n+j][i%2] for i in range(4)]
        column = pads.solve(rhs, [free_pad[r][j] for r in pads.free])
        for r, value in enumerate(column):
            pad_rows[r][j] = value
    result = dict(message=message, pads=pad_rows,
                  message_free_dim=view.n*len(mask.free),
                  pad_free_dim=len(pads.free)*(view.budget-len(indices)))
    verify_sample(view, data, result)
    return result


def verify_sample(view, data, result):
    """Check complete equations, independently of the solver's pivot choices."""
    message, pads = result["message"], result["pads"]
    require(len(message) == len(pads) == 7 and message[:2] == data, "changed shared dummy data")
    require(all(len(row) == width and all(canonical(x) for x in row)
                for rows, width in ((message, view.n), (pads, view.budget)) for row in rows),
            "sample geometry/field")
    for weights, expected in zip(view.folds, view.vectors):
        actual = [C.f2_dot(weights, [(x, 0) for x in column])
                  for column in zip(*[m+p for m, p in zip(message, pads)])]
        require(actual == expected, "sample full folded vector")
    claim = ZERO
    for j, cw in enumerate(view.claim_cw):
        value = C.f2_dot(view.claim_weights, [(row[j], 0) for row in message])
        claim = C.f2_add(claim, C.f2_mul(cw, value))
    require(claim == view.claim_value, "sample individual terminal")
    encoded = [T.coset_evals(T.pcs_poly([(v, 0) for v in m], [(v, 0) for v in p]), view.domain)
               for m, p in zip(message, pads)]
    columns = [[row[j][0] for row in encoded] for j in view.indices]
    require(all(x[1] == 0 for row in encoded for x in row), "sample left base field")
    require(columns == view.columns, "sample encoded columns")
    return columns


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(directory, manifest):
    # Preserve O8 and its archive. Fail closed on changed evidence/dependencies.
    prior = json.loads((ROOT / "results/zk60_round22_validation.json").read_text())
    for group in ("source_sha256", "tools", "analysis_results"):
        for path, digest in prior[group].items():
            require(sha(ROOT/path) == digest, "changed round-22 dependency: " + path)
    analysis = json.loads((ROOT/"results/zk60_round22_o8_analysis.json").read_text())
    repeated.gate.check_report(analysis, set(repeated.O.load_manifest(str(manifest))["entries"]))
    preflight = repeated.O.preflight(str(directory), str(manifest), log=lambda *args: None)
    require(preflight["pass"] and all(c["pass"] for c in preflight["checks"]), "failed capture preflight")
    captures = [repeated.O.IoCapture(str(p)) for p in sorted(directory.glob("*.json"))]
    for privacy in ("P1", "P3"):
        repeated.check_pair([c for c in captures if c.privacy == privacy])
    # Simulation roots exist BEFORE any capture's field observations are loaded
    # into the sampler. They are fresh hypothetical roots, never imported roots.
    oracle = sim.RandomOracle()
    owners = {(c.proof_sha256, role): sim.PreparedSimulation(oracle)
              for c in captures for role in ("Input", "Output")}
    prior_answers = dict(oracle.table)
    cases = []
    for capture in captures:
        raw = json.loads(Path(capture.path).read_text())
        for role in (r for r in raw["roles"] if r["role"] in ("Input", "Output")):
            view = from_capture(role, capture.by_role[role["role"]])
            draws = []
            for variant in ("zero", "nonzero"):
                # Identical per-role choice in both proofs; not real witness data.
                offset = 11 if role["role"] == "Input" else 31
                data = [[0 if variant == "zero" else ((r+1)*(j*j+offset)) % P
                         for j in range(view.n)] for r in range(2)]
                sampled = sample(view, data)
                draws.append(dict(variant=variant, message_free_dim=sampled["message_free_dim"],
                                  pad_free_dim=sampled["pad_free_dim"],
                                  sample_sha256=hashlib.sha256(json.dumps(sampled, sort_keys=True).encode()).hexdigest(),
                                  all_field_equations_checked=True))
            owner = owners[(capture.proof_sha256, role["role"])]
            columns = verify_sample(view, data, sampled)
            openings = owner.open_once(owner.root, view.indices, columns)
            require(all(sim.verify(oracle, owner.root, *op) for op in openings), "ideal-oracle path")
            cases.append(dict(proof_sha256=capture.proof_sha256, privacy=capture.privacy, role=role["role"],
                              distinct_columns=len(set(view.indices)), samples=draws,
                              simulator_root=owner.root.hex(), openings=len(openings), all_paths_accept=True))
    require(all(oracle.table[k] == v for k, v in prior_answers.items()), "changed prior oracle answer")
    return dict(schema=1, status="passed", source_commit=repeated.O.SOURCE_COMMIT, cases=cases,
                manifest_sha256=sha(manifest), capture_preflight_checks=len(preflight["checks"]),
                tools={**analysis["tool_sha256"], **{p: sha(ROOT/"scripts"/p) for p in (
                    "zk60_endpoint_fibre.py", "zk60_endpoint_simulation.py", "zk60_io_opening_translation.py",
                    "zk60_io_repeated_view.py", "zk60_io_review_gate.py")}},
                prior_analysis_sha256=sha(ROOT/"results/zk60_round22_o8_analysis.json"),
                programmed_salted_leaf_inputs=len(oracle.programmed), preexisting_points_reprogrammed=0,
                conditional_preimages_sampled=True, public_field_view_sampled=False,
                full_A_endpoint_alias_sampler=False, root_only_simulation=False,
                actual_blake3_programmed=False, full_privacy_review_complete=False,
                scope="eight endpoint owners; fixed public field observations; two chosen dummy-data variants; ideal Fp fibre samples",
                excluded=["public field-view generation", "A/W/H joint sampling", "CFS sampling",
                          "adaptive Fiat-Shamir", "production PRG distribution", "external fixed roots",
                          "arbitrary repeated-proof composition"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    require(not args.out.exists(), "output already exists")
    result = run(args.captures, args.manifest)
    with args.out.open("x") as stream:
        json.dump(result, stream, indent=2)
        stream.write("\n")
    print("PASS: 16 endpoint conditional samples; 2048 ideal-oracle openings; public field view remains an input")


if __name__ == "__main__":
    main()
