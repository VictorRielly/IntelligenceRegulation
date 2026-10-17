#!/usr/bin/env python3
"""Convert the allocation-free Rust Shape/Layout probe into byte lower bounds.

The input is `layout_probe.log`, emitted by the isolated test-only harness.
Counts use Fp=8 bytes, 256 PCS pads/row, 32-byte hashes/salts, and the
candidate's declared rate. These are live payload bytes, not measured RSS.
"""
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def parse(log: str) -> dict:
    cases = {}
    domains = {}
    seams = {}
    for line in log.splitlines():
        if line.startswith("PROBE ") and " REFUSED " not in line and " LAYOUT_REFUSED " not in line:
            words = line.split()
            name = words[1]
            pairs = dict(w.split("=", 1) for w in words[2:])
            cases[name] = {k: int(v) for k, v in pairs.items()}
        elif line.startswith("DOMAIN "):
            words = line.split()
            name, domain = words[1:3]
            pairs = dict(w.split("=", 1) for w in words[3:])
            domains.setdefault(name, {})[domain] = {k: int(v) for k, v in pairs.items()}
        elif line.startswith("SEAMS "):
            words = line.split()
            seams[words[1]] = " ".join(words[2:])
    if set(cases) != {"toy", "m125", "mistral_t512_probe", "mistral_t1024_probe"}:
        raise ValueError(f"unexpected or refused cases: {sorted(cases)}")
    if (cases["toy"]["A"], cases["toy"]["Hrows"], cases["toy"]["receipt"]) != (455, 384, 2816472):
        raise ValueError("frozen toy control differs")
    if (cases["m125"]["A"], cases["m125"]["Hrows"]) != (5681, 7120):
        raise ValueError("registered 125M control differs")
    for name in ("m125", "mistral_t512_probe", "mistral_t1024_probe"):
        c = cases[name]
        expected = f'endpoint=Ok({c["endpoint_rows"]}) boundary=Ok({c["endpoint_rows"] + 1})'
        if seams.get(name) != expected:
            raise ValueError(f"{name} seam constructors refused or disagreed: {seams.get(name)}")
    return cases, domains


def account(c: dict, domains: dict) -> dict:
    n, ir, q = c["cols"], c["rate"], 256
    nn = n * ir
    # CommittedZk retains raw data, encoded rows, pads, salts and a full
    # Merkle tree. Leaves and salted leaves are temporary extra copies.
    def commitment(rows: int) -> dict:
        return {"data": rows * n * 8, "encoded": rows * nn * 8,
                "pads": rows * q * 8, "salts": nn * 32,
                "tree_nodes": (2 * nn - 1) * 32}
    a = commitment(c["A"])
    h = commitment(c["Hrows"])
    endpoint = commitment(c["endpoint_rows"])
    boundary = commitment(c["endpoint_rows"] + 1)
    mask_encoded = c["M"] * 4096 * 8
    witness_plane_words = sum(v["size"] * v["Aplanes"] for dom, v in domains.items() if dom != "Tab")
    result = {
        "shape": {k: c[k] for k in ("T", "d", "f", "Hheads", "KV", "dh", "cols", "rate")},
        "rows": {k: c[k] for k in ("A", "Adata", "Hrows", "Hdata", "M", "endpoint_rows")},
        "one_encoded_row_bytes": nn * 8,
        "one_data_row_bytes": n * 8,
        "A_commitment": a, "H_commitment": h,
        "A_H_retained_payload_bytes": sum(a.values()) + sum(h.values()),
        "A_H_data_and_codeword_bytes": a["data"] + a["encoded"] + h["data"] + h["encoded"],
        "A_H_retained_after_codeword_release_bytes": sum(a.values()) + sum(h.values()) - a["encoded"] - h["encoded"],
        "M_encoded_bytes": mask_encoded,
        "endpoint_commitment_payload_bytes": sum(endpoint.values()),
        "internal_boundary_payload_bytes": sum(boundary.values()),
        "A_H_M_two_boundaries_payload_floor_bytes": sum(a.values()) + sum(h.values()) + mask_encoded + 2 * sum(boundary.values()),
        "after_codeword_release_M_two_boundaries_floor_bytes": sum(a.values()) + sum(h.values()) - a["encoded"] - h["encoded"] + mask_encoded + 2 * sum(boundary.values()),
        "H_commit_with_A_codeword_released_floor_bytes": sum(a.values()) + sum(h.values()) - a["encoded"] + mask_encoded + 2 * sum(boundary.values()),
        "witness_A_plane_i64_payload_bytes": witness_plane_words * 8,
        "looked_i64_payload_bytes": c["u8_lookups"] * 8,
        "exp_delta_i64_payload_bytes": domains["S"]["size"] * 8,
        "act_index_i64_payload_bytes": domains["F"]["size"] * 8,
        "receipt_counted_bytes_per_block": c["receipt"],
    }
    return result


def main() -> None:
    cases, domains = parse((HERE / "layout_probe.log").read_text())
    report = {name: account(c, domains[name]) for name, c in cases.items()}
    (HERE / "layout_account.json").write_text(json.dumps(report, indent=2) + "\n")
    for name in report:
        r = report[name]
        print(name, "A+H retained GiB", round(r["A_H_retained_payload_bytes"] / 2**30, 3),
              "A+H+M+2B GiB", round(r["A_H_M_two_boundaries_payload_floor_bytes"] / 2**30, 3),
              "witness GiB", round(r["witness_A_plane_i64_payload_bytes"] / 2**30, 3),
              "looked GiB", round(r["looked_i64_payload_bytes"] / 2**30, 3))


if __name__ == "__main__":
    main()
