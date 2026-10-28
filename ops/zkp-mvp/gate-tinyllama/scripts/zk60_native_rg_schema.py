#!/usr/bin/env python3
"""[TINYLLAMA PORT, tools v5, 2026-10-17 round 4; independent review finding
P-10] A capture is PUBLISHED data (D21: a retained capture counts as
publishing), so the gate checks, on the reader's side, that a bundle carries
nothing but what the writer's allow-list names and that its binary store holds
nothing no reference points at.

    python3 zk60_native_rg_schema.py --bundle <dir> [--bundle <dir> ...] \
        [--controls] --evidence <dir> --name <name>

S1  CLOSED KEY SCHEMA: every object key of `run.json`, every `stage-NN.json`
    and `manifest.json` (parsed as JSON, every depth) is in `ALLOWED_KEYS`,
    transcribed below from the capture writer
    `hashline/src/private_block/run_capture.rs::ALLOWED_KEYS` (222 keys; the
    same list at the digests this gate READ: tree A `c69e5776`, R5
    `9c5f844b`).  Before v5 only the Rust writer-side test applied it.
S2  FORBIDDEN WORDS: none of the writer test's ten words (`witness`,
    `plaintext`, `hidden_input`, `hidden_plane`, `plane_values`,
    `mask_coefficient`, `unopened`, `ZkRng`, `seed`, `secret`) occurs in
    `run.json` before its `not_in_a_capture` member, or in a stage file.
S3  ARRAYS COVERAGE: the union of the byte ranges `[offset, offset + bytes)`
    of every array reference in `run.json` and the stage files is exactly
    `[0, size(arrays.bin))` -- no byte of the store that no member references
    (a store of a bundle without `arrays.bin`, schema /4-run, is reported as
    having none).

NOTHING HERE IS A PRIVACY STATEMENT.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os

ALLOWED_KEYS = (
    'schema',
    'kind',
    'coverage',
    'profile',
    'transcript_domain',
    'block_profile',
    'blocks',
    'boundaries',
    'fully_verified',
    'privacy',
    'privacy_review_complete',
    'weight_policy',
    'field_modulus',
    'extension_nonresidue',
    'public_tables_included',
    'source_commit',
    'run_binding',
    'context',
    'calibration',
    'public_statement_digest',
    'parameter_line',
    'schedule_digest',
    'expected_policy',
    'expected_policy_sha256',
    'run_shape_words',
    'shape',
    'external_endpoints',
    'block_digests',
    'internal_boundaries',
    'boundary_scales',
    'stage_lines',
    'layout_description',
    'stage_files',
    'transcript_domain_bytes',
    'hash_tag',
    'rule',
    'contexts',
    'keys_hex',
    'transcript',
    'column',
    'leaf',
    'node',
    'transcript_labels',
    'transcript_program',
    'mask_domain',
    'label',
    'what',
    'log_dom',
    'not_in_a_capture',
    'plane_index',
    'a_data_rows',
    'h_data_rows',
    'a_planes',
    'h_planes',
    'id',
    'domain',
    're_first_row',
    'im_first_row',
    're_offset',
    'im_offset',
    'slot_planes',
    'planes',
    'name',
    'tokens',
    'width',
    'hidden',
    'q_heads',
    'kv_heads',
    'head_dim',
    't_pad',
    'd_pad',
    'h_pad',
    'f_pad',
    'log_cols',
    'cols',
    'inv_rate',
    'opened_cols',
    'f_e',
    'endpoint_rows',
    'endpoint_log_n',
    'endpoint_inv_rate',
    'endpoint_general',
    'norm_wrho',
    'wrho_s',
    'slots',
    'a_groups',
    'h_groups',
    'n_slots',
    'trained_calibration',
    'norm_tn',
    'norm_cn_a',
    'norm_cn_m',
    'norm_ceps',
    'sh_ao',
    'sh_qkv',
    'sh_s',
    'sh_o',
    'sh_g',
    'sh_h',
    'sh_z',
    'd_max',
    # [v17, gate round 14] a DD profile's public dictionary geometry (D30;
    # the gate's R9 capture patch H-2), written only when dd_cap > 0
    'dd_cap',
    'dd_log',
    'dd_helpers',
    'tag_dd',
    'm_rows',
    'n_functionals',
    'input_root',
    'output_root',
    'rows',
    'data_rows',
    'log_n',
    'input_scale',
    'output_scale',
    'opened_at_stage',
    'boundary',
    'index',
    'scale',
    'sites',
    'plane',
    'site_rows',
    'prox_row',
    'checks',
    'statement_digest',
    'row_rule',
    'committed_at_stage',
    'claim_sites',
    'site',
    'stage',
    'slot',
    'first_row',
    'opening_in_stage_file',
    'block_digest',
    'segment_bytes',
    'segment_sha256',
    'start_tag',
    'end_tag',
    'boundary_committed',
    'root',
    'a_root',
    'a_rows',
    'h_root',
    'h_rows',
    'mask_root',
    'logup_challenges',
    'layout_digest',
    'opening_order',
    'header',
    'arguments',
    'mask',
    'roles',
    'transcript_sites',
    'before',
    'after',
    'before_definition',
    'state',
    'next',
    'main',
    'extension',
    'degree',
    'definition_challenges',
    'c',
    'scalar',
    'claimed_sum',
    'rho',
    'sumcheck_final',
    'mask_eval',
    'terminal_polynomial',
    'terminals',
    'rounds',
    'hosted',
    'tables',
    'coefficient',
    'start',
    'point',
    'len',
    'sha256',
    'values',
    'role',
    'claim',
    'log_size',
    'mask_row',
    'extension_round',
    'slices',
    'offset',
    'coordinates',
    'flip',
    'fixed',
    'specs',
    'theta',
    'proximity_rhos',
    'functionals',
    'value',
    'terms',
    'weights',
    'q',
    'prox',
    'columns',
    'commitment_kind',
    'params',
    'num_col_checks',
    'commitment',
    'sum_rows',
    'claim_sources',
    'claims',
    'parts',
    'groups',
    'members',
    'lambdas',
    'key',
    'tail',
    'vector',
    'proximity_vector',
    'q_pad',
    'row_roles',
    'row',
    'public_linear_constraints',
    'relation',
    'source',
    'salt',
    'path',
    'array',
    'elem',
    'file',
    'bytes',
    'source_pins',
    'files',
    'total_bytes',
)

FORBIDDEN = ("witness", "plaintext", "hidden_input", "hidden_plane",
             "plane_values", "mask_coefficient", "unopened", "ZkRng", "seed",
             "secret")
REF_KEYS = {"array", "elem", "len", "offset", "bytes"}


def _keys(o, out):
    if isinstance(o, dict):
        for k, v in o.items():
            out.append(k)
            _keys(v, out)
    elif isinstance(o, list):
        for v in o:
            _keys(v, out)
    return out


def _refs(o, out):
    if isinstance(o, dict):
        if set(o) == REF_KEYS:
            out.append((int(o["offset"]), int(o["bytes"])))
            return out
        for v in o.values():
            _refs(v, out)
    elif isinstance(o, list):
        for v in o:
            _refs(v, out)
    return out


def coverage(ranges, size):
    """the gaps and overruns of a set of byte ranges against [0, size)"""
    gaps, end = [], 0
    for off, n in sorted(ranges):
        if off > end:
            gaps.append([end, off])
        end = max(end, off + n)
    if end < size:
        gaps.append([end, size])
    return gaps, max(0, end - size)


def bundle_files(d):
    names = sorted(n for n in os.listdir(d) if n.startswith("stage-") and n.endswith(".json"))
    return ["run.json"] + names + ["manifest.json"]


def check_docs(docs: dict, raw: dict, arrays_size) -> dict:
    """S1-S3 over parsed documents (name -> object) and raw bytes"""
    f = []
    allowed = set(ALLOWED_KEYS)
    keys_checked = 0
    for name, doc in docs.items():
        ks = _keys(doc, [])
        keys_checked += len(ks)
        bad = sorted(set(k for k in ks if k not in allowed))
        if bad:
            f.append(f"S1: {name} carries field(s) not on the capture allow-list: {bad[:5]}")
    for name, b in raw.items():
        if name == "manifest.json":
            continue
        end = b.find(b'"not_in_a_capture"') if name == "run.json" else -1
        scan = b[:end] if end >= 0 else b
        for w in FORBIDDEN:
            if w.encode() in scan:
                f.append(f"S2: {name} contains the forbidden word {w!r}")
    ranges = []
    for name, doc in docs.items():
        if name != "manifest.json":
            _refs(doc, ranges)
    cov = {"references": len(ranges)}
    if arrays_size is None:
        cov["arrays_bin"] = None
        if ranges:
            f.append("S3: array references but no arrays.bin")
    else:
        gaps, over = coverage(ranges, arrays_size)
        cov.update({"arrays_bin_bytes": arrays_size, "gaps": gaps[:5],
                    "gap_count": len(gaps), "bytes_past_the_end": over,
                    "covered_exactly": not gaps and not over})
        if gaps:
            f.append(f"S3: {len(gaps)} byte range(s) of arrays.bin no reference "
                     f"covers (first {gaps[0]})")
        if over:
            f.append(f"S3: references run {over} bytes past the end of arrays.bin")
    return {"keys_checked": keys_checked, "coverage": cov, "findings": f,
            "ok": not f}


def load_docs(d):
    docs, raw = {}, {}
    for name in bundle_files(d):
        with open(os.path.join(d, name), "rb") as fh:
            raw[name] = fh.read()
        docs[name] = json.loads(raw[name])
    ab = os.path.join(d, "arrays.bin")
    return docs, raw, (os.path.getsize(ab) if os.path.exists(ab) else None)


def schema_controls(docs, raw, size) -> dict:
    """each check must refuse one in-memory perturbation"""
    ctl = []

    def go(name, what, d2, r2, s2, want):
        out = check_docs(d2, r2, s2)
        named = [x for x in out["findings"] if x.startswith(want)]
        ctl.append({"control": name, "what": what, "fires": (not out["ok"]) and bool(named),
                    "findings_naming_it": named[:2]})
    d2 = copy.deepcopy(docs)
    st = next(n for n in d2 if n.startswith("stage-"))
    d2[st]["extra_private_field"] = [1, 2, 3]
    go("SC-1", f"an unlisted key added to {st}", d2, raw, size, "S1")
    d2 = copy.deepcopy(docs)
    d2["run.json"]["shape"]["hidden_debug"] = 0
    go("SC-2", "an unlisted key nested in run.json's shape", d2, raw, size, "S1")
    r2 = dict(raw)
    r2[st] = raw[st] + b" seed"
    go("SC-3", f"the word 'seed' appended to {st}'s bytes", docs, r2, size, "S2")
    if size is not None:
        go("SC-4", "arrays.bin eight bytes longer than every reference covers",
           docs, raw, size + 8, "S3")
    return {"controls": ctl, "all_fire": bool(ctl) and all(c["fires"] for c in ctl),
            "ok": bool(ctl) and all(c["fires"] for c in ctl)}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--bundle", action="append", required=True)
    ap.add_argument("--controls", action="store_true")
    ap.add_argument("--evidence", required=True)
    ap.add_argument("--name", required=True)
    a = ap.parse_args(argv)
    rows = []
    for d in a.bundle:
        docs, raw, size = load_docs(d)
        r = {"bundle": os.path.basename(d), "files": list(docs)}
        r.update(check_docs(docs, raw, size))
        if a.controls:
            r["controls"] = schema_controls(docs, raw, size)
            r["ok"] = r["ok"] and r["controls"]["ok"]
        rows.append(r)
        print(f"{r['bundle']:44s} keys {r['keys_checked']:8d} refs "
              f"{r['coverage']['references']:6d} covered "
              f"{r['coverage'].get('covered_exactly')} ok {r['ok']}", flush=True)
        del docs, raw
    with open(os.path.abspath(__file__), "rb") as fh:
        me = hashlib.sha256(fh.read()).hexdigest()
    out = {"what": "closed key schema, forbidden words and arrays.bin coverage "
           "(finding P-10)", "tool_sha256": me, "allowed_keys": len(ALLOWED_KEYS),
           "bundles": rows, "ok": all(r["ok"] for r in rows),
           "privacy_property_established": False, "privacy_acceptance": False}
    os.makedirs(a.evidence, exist_ok=True)
    p = os.path.join(a.evidence, f"{a.name}.json")
    with open(p, "w") as fh:
        json.dump(out, fh, indent=1, sort_keys=True)
        fh.write("\n")
    print(f"record: {p}   ok={out['ok']}")
    return 0 if out["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
