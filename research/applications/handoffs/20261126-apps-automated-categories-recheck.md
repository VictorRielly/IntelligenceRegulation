# Coordinator's check of A17 (2026-11-26)

Astra's handoff, [which categories dominate automated moderation filings](20261126-apps-automated-categories.md), is carried forward: every figure in it was reproduced twice from the same archive.

## What was checked

1. **The file.** I fetched the publisher's checksum myself (73 bytes): `4f7936a6eb735d4fef78771a6255f9ed568822a2  sor-global-2026-11-02-light.zip`. It equals the constant the handoff's program asserts. The checksum address redirects to a storage address that refuses a HEAD request, so it was fetched with one GET capped at 1 MB.
2. **The handoff's own program.** I extracted it unchanged from the handoff's code block and ran it on the archive Astra downloaded (1,555,344,992 bytes, kept outside the repository). It exited 0, so the file's SHA-1 equals the publisher's and the row total is 30,120,164. Its 78 cells are in [the cells file](20261126-apps-automated-categories-recheck.cells.csv).
3. **A second count by a different method.** [My script](20261126-apps-automated-categories-recheck.py) reads the inner archives in memory, keys the cells by the raw field values and splits the additional-category field into blank, empty list and non-empty list. Its cells equal the program's 78 cells. The raw values confirm the two spellings the program tests for: `automated_detection` is `Yes` or `No`, and `automated_decision` takes three values, one of them `AUTOMATED_DECISION_FULLY`.
4. **Every figure in the handoff.** [The compare script](20261126-apps-automated-categories-recheck-compare.py) derives each number of the handoff's text and two tables from the cells and looks for it in the handoff: 22 checks, all passed ([output](20261126-apps-automated-categories-recheck.out.txt), [second count's data](20261126-apps-automated-categories-recheck.json)).

Both counts ran under the resource guard, class light: 87 s and 92 s on one core.

## What I add: the same day by size of filer

Fixed in the script before the count ran. A filer's class is the number of its statements with automated detection on that day. "Catch-all" means the primary category is `OTHER_VIOLATION_TC` or `NOT_SPECIFIED_NOTICE`. No filer is named, here or in the output files.

| Detected statements filed that day | Filers | Filers with a catch-all majority | Detected statements | Catch-all share |
| --- | ---: | ---: | ---: | ---: |
| 1M and more | 4 | 2 | 22,920,709 | 77.00% |
| 100k to 1M | 6 | 4 | 1,948,277 | 74.28% |
| 10k to 100k | 14 | 8 | 369,875 | 44.02% |
| 1k to 10k | 25 | 16 | 92,451 | 59.78% |
| under 1k | 55 | 30 | 8,502 | 48.05% |
| **All** | **104** | **60** | **25,339,814** | **76.24%** |

- The 76 percent is a volume-weighted figure: the 4 filers of the top class filed 90.45 percent of the detected statements.
- Counted by filer, 60 of 104 (57.7 percent) have a catch-all majority among their own detected statements; 44 file mostly under a named category.
- In the three classes under 100,000 detected statements a day (94 filers, 470,828 statements) the pooled catch-all share is 47.19 percent.

So A13's kill condition holds for this day by statement count and for a small majority of filers. It is not uniform: among smaller filers about half of the automated filings carry a named category.

## Limits

- One day. The handoff says the day was chosen before the category counts were seen; I cannot check that.
- A named category is still broad, and each would need a mapping to a specific policy (the handoff's point).
- Both fields are reported by the filer.
- The size classes here are by detected statements on one day; the classes of A28 are by all statements, as a monthly mean. They are not the same classes.
