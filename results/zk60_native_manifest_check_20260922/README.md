# `results/zk60_native_manifest_check_20260922/` — the toy gate's manifest cross-check: the silent skip, and the fix

Round 9e, 2026-09-22, lane `zk60-native-jointview`. The reading is §8.7 of
`docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md` and ledger section R9e
of `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE_PROGRESS.md`; this directory holds
what those were computed from. **Nothing here is a privacy acceptance and
nothing here establishes a privacy property.** It is one defect in one
bookkeeping check of one tool.

## The defect, in one paragraph

`manifest_check` in `scripts/zk60_native_jv_capture.py` cross-checks a
capture directory's manifest against the bundle on disk: the artifact
digests, the accepted list, the source commit. It knew **one** file name,
`validation.json`. The integrator's bundle of 2026-09-22 carries the same
manifest under the name its capture runner writes,
`capture-validation.json`, so the check returned
`{"validation_json": "absent"}`, both gates ran to the end, and both passed
with the cross-check switched off and nothing in the record saying so. Round
9d found it (`ZK60_NATIVE_D22_REPIN_4751B93.md` §8.5, observation 1) and
worked around it with a staging shim. Three neighbouring shapes were no
better: a manifest whose `accepted` is a single record rather than a list, an
unparsable file, and an `accepted` of any other shape all raised
`TypeError`/`JSONDecodeError` from inside a dict literal, naming neither the
file nor the directory. And a manifest that genuinely **disagreed** with the
bundle returned a `mismatch` list that neither gate folds into its `ok`.

## The files

| file | what it is |
|---|---|
| `failing_first.py`, `failing_first_before.log`, `failing_first_after.log` | S1. Seven cases run against the tool **as it stood at `d837d50`, loaded straight out of git**, and against the tool in the tree, side by side. The `before` log was taken before a byte was touched (both columns identical, as they must be); the `after` log after the fix. The temp-directory names differ from run to run; nothing else does |
| `run.sh`, `run.log`, `run.done` | S4+S5. The five gate runs, detached under `flock /tmp/zk-heavy.lock` inside an 8 GiB `systemd-run` scope |
| `repin_diff.py`, `repin_diff.txt` | S4. Each of the three guarded records against its own committed bytes at `d837d50`, leaf by leaf: only `tool_sha256/zk60_native_jv_capture.py` and `seconds` may move |
| `p10_as_delivered_fixed/`, `jointview_as_delivered_fixed/` | S5. The round-9d replay once more with the fixed tool, straight at the integrator's directory, **no shim** |
| `vs9d.py`, `vs9d.txt` | S5. Those two records against round 9d's two pairs: against 9d's as-delivered runs (where the check was skipped) and against 9d's staged runs (where the shim made it fire) |
| `leafdiff_p10.txt`, `leafdiff_jointview.txt` | S5. Round 9d's own A/B/N leaf diff re-run on the new records, with `moved` the verdict |
| `suite.sh`, `suite.log`, `suite.done` | S6. The toy gate's seven modules and the record guard |

## The fix

Inside `manifest_check` and its two callers, and nowhere else
(`git --no-pager -C . diff d837d50 HEAD -- scripts/`):

* the manifest is looked for under **either** name, `validation.json` first,
  then `capture-validation.json`;
* `accepted` is read as a **list or a single record**, and each record must
  carry `proof_sha256`;
* every way the cross-check can fail to be made — absent, unreadable, not an
  object, `accepted` neither shape, or any disagreement with the bundle — now
  raises `ManifestRefusal`, which names the directory, the file and the
  reason;
* the one way past a missing manifest is for the caller to declare it,
  `--no-validation-file`, and the declaration is written into the record
  (`declared_absent_by_the_caller`). Declaring absence when a manifest is
  present is itself a refusal;
* both gates call the check **before** any analysis and, on a refusal, print
  `REFUSED (manifest cross-check): …` and exit **3** — distinct from 2 (no
  captures) and 1 (the gate ran and is not ok) — writing no record at all.

**Records produced from a directory that HAS a `validation.json` with a list
`accepted` are unaffected**, and that is machine-checked rather than argued:
`tests/test_zk60_native_joint_view.py::ManifestCheckRefusesByName::
test_the_records_of_record_are_answered_exactly_as_before_the_fix` compares
the fixed function's answer on `results/zk60_native_captures_20260919/` with
`d837d50`'s answer on it, key for key. Only the records' `tool_sha256` had to
move, because the tool's bytes moved; that is the re-pin below.

## One malformed shape still refused without a name

If a manifest's `artifacts` key is present but is not an object of per-file
records (a list, say), the check raises `AttributeError` rather than a named
refusal. It is loud — the gate exits non-zero and writes no record, so it
cannot pass silently, which is the defect this round is about — but it does
not name the file. It is left because closing it changes the tool's bytes
again and therefore costs a re-take of all three guarded records; it should
be closed the next time those records are re-taken for another reason. Every
shape the ruling names (absent, unreadable, an `accepted` that is neither a
list nor a record, a record without `proof_sha256`, and any disagreement with
the bundle) is refused **by name**.

## One thing the record still does not say

A passing record reports `validation_json: "present"` without naming **which**
of the two files was read. That was chosen so the manifest block of every
record of record stays byte-identical across this fix, which is what makes
the re-pin provably a re-pin and nothing more. The name is in every refusal
message, and the delivered bundle's name is recorded here and in §8.7. If a
later round wants the name in the record, it is one key and one more re-take
of the three records — worth doing the next time those records are re-taken
for another reason, not on its own.

## Reproduce

```
python3 /home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922/failing_first.py
bash    /home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922/run.sh
python3 /home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922/repin_diff.py
python3 /home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922/vs9d.py
bash    /home/victor/wt-zk60-jointview/results/zk60_native_manifest_check_20260922/suite.sh
```

The integrator's directory
(`/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922/`,
uncommitted in the main tree) is read-only throughout: nothing in it was
written, renamed or staged, and this round needed **no copy of it at all**.
