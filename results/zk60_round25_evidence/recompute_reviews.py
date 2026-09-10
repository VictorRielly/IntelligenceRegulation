"""Recompute O11's actual ranks; preserve the delivered record unchanged."""
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"scripts"))
import zk60_io_repeated_view as R

manifest = ROOT/"results/zk60_round22_captures.json"
directory = ROOT/"results/zk60_round22_captures"
pre = R.O.preflight(str(directory), str(manifest), log=lambda *args: None)
assert pre["pass"] and all(c["pass"] for c in pre["checks"])
reproduction = ROOT/"results/zk60_opus_io_capture_analysis_round22.json"
R.gate.check_report(json.loads(reproduction.read_text()), set(R.O.load_manifest(str(manifest))["entries"]))
caps = [R.O.IoCapture(str(path)) for path in sorted(directory.glob("*.json"))]
delivered = json.loads((ROOT/"results/zk60_opus_repeated_view_review.json").read_text())
cases = []
for privacy in ("P1", "P3"):
    pair = [c for c in caps if c.privacy == privacy]
    joint, meta = R.model(pair)
    steps = []
    for count in range(3):
        model = R.O.JointModel(meta["observations"], meta["aliases"], zero_sum=False, extras=meta["extras"][:count])
        steps.append(model.analyze(planes=False)["joint"]["disclosed_total"])
    assert steps == [0, 2, 4]
    augmented = R.O.JointModel(meta["observations"], meta["aliases"], zero_sum=False,
                             extras=meta["extras"]+meta["identities"])
    increment = augmented.rank(augmented.all_gens())["rank"] - joint.rank(joint.all_gens())["rank"]
    assert increment == 0
    # Counterfactual H aliases change merged coordinates. Remap both extras
    # before adding constraints; copying old merged row numbers would be wrong.
    h_indices = [i for i, o in enumerate(meta["observations"]) if o.role.startswith("H@")]
    left, right = [meta["observations"][i] for i in h_indices]
    aliases = list(meta["aliases"]) + [((left.role, row), (right.role, row))
                                      for row in range(left.rows) if left.row_kind[row] == "data"]
    provisional = R.O.JointModel(meta["observations"], aliases, zero_sum=False)
    extras = []
    for ci in h_indices:
        re, im = meta["observations"][ci].layout["zero_sum_pair"]
        extras.append(dict(name="counterfactual H zero sum", commitment=meta["observations"][ci].role,
                           source="remapped source zero-sum pair under artificial data aliases",
                           coefs={provisional.merged_of[(ci, re)]: R.O.ONE,
                                  provisional.merged_of[(ci, im)]: R.O.U}, public_value=R.O.ZERO))
    counter = R.O.JointModel(meta["observations"], aliases, zero_sum=False, extras=extras)
    counter_total = counter.analyze(planes=False)["joint"]["disclosed_total"]
    assert counter_total == delivered["H_proof_locality"]["counterfactual"]["aliased_disclosed_total"]
    ablated, _ = R.model(pair, {"Input"}, ablate_first_input=True)
    ablation = ablated.analyze(planes=False)["joint"]["disclosed_total"]
    assert ablation == 256
    cases.append(dict(privacy=privacy, zero_sum_steps=steps, public_identity_increment=increment,
                      counterfactual_H_alias_disclosure=counter_total, endpoint_mask_ablation=ablation))
    print(privacy, steps, "H counterfactual", counter_total, "ablation", ablation, flush=True)
report = dict(status="passed", cases=cases, rank_engine_independent=False,
              general_H_omission_harmlessness_proved=False, full_privacy_review_complete=False,
              strict_extra_O8_reproduction_gate=True,
              tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest())
with (ROOT/"results/zk60_round25_review_recomputation.json").open("x") as stream:
    json.dump(report, stream, indent=2)
    stream.write("\n")
