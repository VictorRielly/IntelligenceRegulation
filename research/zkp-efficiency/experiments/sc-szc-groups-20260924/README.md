# SC_SZC equality groups — cycle 0002

Run `20260924T024433Z-0c043a75`, 2026-09-24. **Promising exact algebra and
work-count result; no native runtime, receipt, GPU or privacy result.**

Command from the research directory:

```sh
python3 experiments/sc-szc-groups-20260924/experiment.py > experiments/sc-szc-groups-20260924/run.log 2>&1
```

The script uses only the standard library, sets one CPU affinity, lowers its
priority, and caps address space at 512 MiB, CPU at 55 s and wall time at 59 s.
Seed: `20260924`. The retained run exited 0 in 2.884 s, peak RSS 23,428 KiB,
on Intel Core Ultra 9 185H / WSL2, Python 3.10.12. `result.json` binds the
script and five read-only source files by SHA-256. The earlier successful
version is preserved in `initial/`; it used only a one-coordinate suffix and
the same scalar expression in its direct MLE oracle. The final version adds
an independently expanded scalar oracle and wider broadcast suffixes.

## Tested identity and limits

The source expression in `argument.rs:1690` is

`eq(tau,x)*ZC(x) + eq(p_ht,x[:lht])*nu0*ght(x)*(sum(x)+lam)
 + eq(p_s,x)*nu1*gs(x)*(64*s8(x)+rsl(x)-32)`.

The port includes all five softmax clauses, the exponential pair lookup,
paired and odd-tail LogUp helper relations, byte-limb recombination, both
pad-zero groups with zeta powers continuing between groups, both hosted
terms, and distinct Ht/S support gates. Lookup affine forms, plane ordering
and support shapes are **synthetic**, not extracted native Layout instances.
Witness tables include arbitrary/inconsistent field values. This tests an
evaluator identity on bad witnesses too; it does not run witness validation.

The reference materializes/folds three equality tables and computes all
degree+1 samples in the first round, then recovers the combined sample at 1
from the actual preceding unmasked round (the R1d release arithmetic).
The candidate evaluates each bracket at its own smaller degree, splits its
remaining equality table into halves, reconstructs the full public-degree
round, sums the groups, and folds witness tables once.

**New detail beyond cycle 0001:** each subgroup's next claim can be computed
locally by interpolating its own already computed round at the driver's
challenge. That supplies an actual subgroup sum without deriving it from
the combined claim or adding a transcript message. The first round is
unseeded. If the relevant equality factor at 1 is zero, the candidate
computes the missing sample explicitly. Challenges are never rejected or
resampled. Once the current coordinate is outside `p_ht`, its factor is
constant and its suffix weights broadcast over the remaining cube.

The independent oracle evaluates every original table by the Boolean-cube
MLE definition, then evaluates a separately expanded scalar expression.
Neither part uses the evaluator's folding or `inner()` implementation.
Field arithmetic is shared conventional exact Fp2 (`u^2=7`); this is not a
second field implementation. The toy message wrapper detects round/challenge
drift only. It is not native CFS and consumes no production RNG.

## Result

- 23 differential cases, 2–8 variables (4–256 cube rows), 2/3-limb groups,
  4/5 lookup values (paired and odd-tail helpers), 1–4 broadcast coordinates,
  padded/unpadded gates, base/full-extension/zero tables.
- 189 complete round points checked by the independent original-cube oracle.
- Round arrays and final table order/values agree in all three evaluators:
  reference, grouped with recovery, grouped without recovery.
- Four group-round zero-factor fallbacks, including an accumulated zero prefix.
- Five detected negative controls: combined claim used as subgroup claim;
  S gate substituted for Ht; p_ht incorrectly extended to the trailing axis;
  one altered limb; one common equality factor imposed on the whole sum.
- Two malformed fixture refusals (table length and point support).

Counts at 256 rows with `n=8, lht=4`, 23 non-equality tables:

| Bracket | R1d-style reference | Groups without subgroup recovery | Groups with derived subgroup recovery |
|---|---:|---:|---:|
| ZC, unpadded | 1,148 | 1,020 | 893 |
| each hosted bracket, unpadded | 1,148 | 510 | 383 |
| ZC, padded | 1,403 | 1,275 | 1,148 |
| each hosted bracket, padded | 1,403 | 765 | 638 |

These are **bracket evaluations**, not field multiplications or equal-cost
operations. In particular, hosted brackets are much cheaper than ZC. The
expensive padded bracket falls 18.2%; the unpadded bracket falls 22.2%.
Interpolation, table loads, duplicated per-group table interpolation, suffix
weight multiplication, folds and allocation are not priced by these counts.
The Python implementation prioritizes a readable oracle over loop fusion.
It may lose runtime despite fewer bracket evaluations; no A/B timing claim.
The largest split equality table pair contains 24 elements, excluding points,
prefixes, pending rounds and witness tables; reference equality tables begin
at 3*256 entries. Neither count is a total memory estimate.

## Integration gate

See `../../handoffs/20260924-sc-szc-groups.md`. The precise Rust source pins
are in `result.json`; all match cycle 0001's inspected files. Source-to-port
agreement has been read, not mechanically verified against native closures.
Native closure/IR, masking/RNG and full-receipt comparison remain required.
No production files, instructions, receipts or reviewer artifacts were edited.

## Blockers and provenance corrections

- A first read used the wrong local path
  `results/zk60_sumcheck_rounds_20260922/dense-ab-1/measured-summary.json` and
  returned "No such file or directory". `rg --files` located the real summary
  at the parent result directory; it was read successfully. No data loss.
- Native web reported cache misses for several GitHub commit/license pages;
  API metadata URLs were "not accessible via this tool"; the 2025/611 PDF was
  denied by robots.txt. No alternate network client or permission bypass used.
  Available repository README/history and primary abstract metadata were used
  with explicit incomplete-date/license/commit qualifiers in `sources.jsonl`.
- Live ePrint 2024/1210 metadata says received **2024-07-27**, correcting
  cycle 0001's 2024-07-28 entry. Old records remain preserved.
