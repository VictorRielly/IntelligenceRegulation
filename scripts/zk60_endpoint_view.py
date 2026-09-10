#!/usr/bin/env python3
"""Generate a standalone endpoint FIELD view at fixed public coefficients.

Unlike the round-24 fibre sampler, no group/proximity vector, terminal value or
column value is an input. This still does NOT jointly simulate A/H/W/CFS or the
adaptive transcript. Captured coefficients/indices are treated as fixed inputs.
All randomness arguments below are in the independent-uniform-Fp idealization.
"""
import argparse
from dataclasses import dataclass
from fractions import Fraction
import hashlib
import json
import math
from pathlib import Path
import secrets

import zk60_endpoint_fibre as F

C, T, P = F.C, F.T, F.P
require, ROOT = F.require, F.ROOT


@dataclass
class EndpointPlan:
    folds: list
    claim_weights: list
    claim_cw: list
    indices: list
    n: int = 256
    budget: int = 256
    domain: int = 2048

    def view(self, vectors, value, columns):
        return F.EndpointView(self.folds, vectors, self.claim_weights, self.claim_cw,
                              value, self.indices, columns, self.n, self.budget, self.domain)

    def validate(self):
        # Zero observations are a consistent test view of these coefficients.
        view = self.view([[C.ZERO]*(self.n+self.budget) for _ in range(2)], C.ZERO,
                         [[0]*7 for _ in self.indices])
        view.validate()
        F.LinearFibre([row[2:] for row in F.split_folds(self.folds)])


def plan_from_capture(role, obs):
    """Extract coefficients/positions ONLY; ignore all captured field outputs."""
    require(role["role"] in ("Input", "Output") and role["role"] == obs.role and obs.rows == 7,
            "endpoint plan role")
    require(len(role["claims"]) == len(role["groups"]) == 1 and role["groups"][0]["members"] == [0]
            and not role["public_linear_constraints"], "endpoint plan layout")
    folds, constraints = T.pcs_matrices(role)
    return EndpointPlan(folds, constraints[0], obs.groups[0]["cw"],
                        [column["index"] for column in role["columns"]],
                        obs.n, role["q_pad"], 8*obs.n)


def generate(plan, randbelow=secrets.randbelow):
    """Dummy-zero endpoint generator; no real witness or captured output input."""
    plan.validate()
    message = [[0]*plan.n for _ in range(2)] + [[randbelow(P) for _ in range(plan.n)] for _ in range(5)]
    pads = [[randbelow(P) for _ in range(plan.budget)] for _ in range(7)]
    require(all(F.canonical(v) for rows in (message, pads) for row in rows for v in row), "random field word")
    vectors = [[C.f2_dot(fold, [(x, 0) for x in column])
                for column in zip(*[m+p for m, p in zip(message, pads)])] for fold in plan.folds]
    value = C.ZERO
    for j, cw in enumerate(plan.claim_cw):
        claim = C.f2_dot(plan.claim_weights, [(row[j], 0) for row in message])
        value = C.f2_add(value, C.f2_mul(cw, claim))
    enc = [T.coset_evals(T.pcs_poly([(v, 0) for v in m], [(v, 0) for v in p]), plan.domain)
           for m, p in zip(message, pads)]
    columns = [[row[j][0] for row in enc] for j in plan.indices]
    view = plan.view(vectors, value, columns)
    view.validate()
    F.verify_sample(view, [[0]*plan.n for _ in range(2)], dict(message=message, pads=pads))
    return view


def reduction_distance(bits, modulus):
    """Exact TV distance between U([0,2^bits)) mod modulus and U(modulus)."""
    require(type(bits) is int and bits >= 0 and type(modulus) is int and modulus > 0, "reduction parameters")
    count = 1 << bits
    remainder = count % modulus
    return Fraction(remainder*(modulus-remainder), modulus*count)


def fraction_record(value):
    return dict(numerator=value.numerator, denominator=value.denominator,
                log2=math.log2(value) if value else None)


def arithmetic_ledger():
    delta = reduction_distance(128, P)
    require((1 << 128) % P == P-(1 << 32), "Goldilocks remainder")
    require(0 < delta < Fraction(1, 1 << 96), "Goldilocks exact reduction bound")
    return dict(modulus=P, input_bits=128, remainder=(1 << 128) % P,
                single_word_total_variation=fraction_record(delta),
                endpoint_words=5*256 + 7*256, endpoint_pair_words=6144,
                endpoint_pair_to_uniform_upper_bound=fraction_record(6144*delta),
                endpoint_pair_shift_comparison_upper_bound=fraction_record(2*6144*delta),
                visible_view_lower_bound_claimed=False, whole_protocol_bound_claimed=False,
                assumptions="uniform independent 128-bit integers before reduction; unconditional draws; PRG/adaptive/acceptance effects excluded")


def view_record(view):
    # Public generated observations are retained for independent checking.
    return dict(vectors=view.vectors, claim_value=view.claim_value, columns=view.columns)


def run(directory, manifest):
    prior = json.loads((ROOT/"results/zk60_round24_validation.json").read_text())
    require(prior["status"] == "passed", "round-24 validation incomplete")
    for group in ("source_sha256", "tools", "results"):
        for path, digest in prior[group].items():
            require(F.sha(ROOT/path) == digest, "changed round-24 dependency: " + path)
    # The archival parser/gate and all imported algebra are source-bound by O8.
    baseline = json.loads((ROOT/"results/zk60_round22_validation.json").read_text())
    for group in ("source_sha256", "tools", "analysis_results"):
        for path, digest in baseline[group].items():
            require(F.sha(ROOT/path) == digest, "changed round-22 dependency: " + path)
    O = F.repeated.O
    analysis = json.loads((ROOT/"results/zk60_round22_o8_analysis.json").read_text())
    F.repeated.gate.check_report(analysis, set(O.load_manifest(str(manifest))["entries"]))
    preflight = O.preflight(str(directory), str(manifest), log=lambda *args: None)
    require(preflight["pass"] and all(c["pass"] for c in preflight["checks"]), "capture preflight")
    captures = [O.IoCapture(str(path)) for path in sorted(directory.glob("*.json"))]
    for privacy in ("P1", "P3"):
        F.repeated.check_pair([c for c in captures if c.privacy == privacy])
    oracle = F.sim.RandomOracle()
    owners = {(cap.proof_sha256, role): F.sim.PreparedSimulation(oracle)
              for cap in captures for role in ("Input", "Output")}
    prepared_answers = dict(oracle.table)
    cases = []
    for cap in captures:
        raw = json.loads(Path(cap.path).read_text())
        for role in (r for r in raw["roles"] if r["role"] in ("Input", "Output")):
            plan = plan_from_capture(role, cap.by_role[role["role"]])
            view = generate(plan)
            # Round 24 constructs a compatible preimage for a different chosen
            # plane under these NEW observations, not under captured outputs.
            offset = 17 if role["role"] == "Input" else 41
            data = [[(r+1)*(j*j+offset) % P for j in range(plan.n)] for r in range(2)]
            completion = F.sample(view, data)
            owner = owners[(cap.proof_sha256, role["role"])]
            root = owner.root
            openings = owner.open_once(root, view.indices, view.columns)
            require(all(F.sim.verify(oracle, root, *op) for op in openings), "generated-view oracle paths")
            require(view.vectors[0] != [tuple(x) for x in role["groups"][0]["vector"]],
                    "generated group vector unexpectedly equals captured one")
            cases.append(dict(proof_sha256=cap.proof_sha256, privacy=cap.privacy, role=role["role"],
                              distinct_columns=len(set(plan.indices)), prepared_leaves=2048,
                              unopened_leaves=2048-len(set(plan.indices)), ideal_root=root.hex(),
                              paths_verified=len(openings), alternate_data_completion=True,
                              fibre_dimension=completion["message_free_dim"]+completion["pad_free_dim"],
                              generated=view_record(view)))
    require(all(oracle.table[k] == v for k, v in prepared_answers.items()), "preparation oracle answer changed")
    return dict(schema=1, status="passed", cases=cases, arithmetic=arithmetic_ledger(),
                manifest_sha256=F.sha(manifest), preflight_checks=len(preflight["checks"]),
                dependencies={**analysis["tool_sha256"], **{p: F.sha(ROOT/"scripts"/p) for p in (
                    "zk60_endpoint_view.py", "zk60_endpoint_fibre.py", "zk60_endpoint_simulation.py",
                    "zk60_io_opening_translation.py", "zk60_io_repeated_view.py", "zk60_io_review_gate.py")}},
                source_commit=O.SOURCE_COMMIT, source_sha256=prior["source_sha256"],
                oracle_counts=dict(owners=8, prepared_leaves=8*2048,
                                   distinct_programmed_leaves=len(oracle.programmed), paths=8*256,
                                   unopened_leaves=sum(c["unopened_leaves"] for c in cases)),
                public_endpoint_field_view_sampled=True, captured_field_outputs_used_by_generator=False,
                fixed_coefficients_and_indices=True, full_A_H_W_CFS_joint_sampler=False,
                adaptive_transcript_simulated=False, external_root_simulated=False,
                actual_blake3_programmed=False, full_privacy_review_complete=False,
                scope="standalone endpoint field-view image at fixed coefficients/indices; ideal uniform Fp randomness")


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
    print("PASS: eight generated endpoint field views, alternate-data completions and 2048 ideal-oracle paths")


if __name__ == "__main__":
    main()
