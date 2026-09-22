# The D22 condition-7 PRE-READ of lane stage 36 (`fee1a8d`..`29cba9a`)

**Status: `OPEN` (skeleton).** Opened 2026-09-22 11:33 PDT on the review
worktree `/home/victor/wt-zk60-block125m-review`, branch
`zk60-private-block-125m-review`, at `29cba9a` (identical to the lane tip).

**What this is.** An independent adversarial pre-read of the lane's stage 36
— the read-only test observers — against the conditions of the accepted toy
privacy statement (`ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md` §5 conditions 1–7,
§8, §9 items 5–8 and 11), written so that the security owner can re-pin the
statement on the day the integrator merges the delta. Every claim of the
stage is assumed wrong until re-derived here by a DIFFERENT method.

**What this is NOT** (written first, so it cannot be read as more):

* **Not the re-pin.** Only the security owner moves a pin of D22. This page
  is the reading and the arithmetic they would otherwise have to do.
* **Not a statement about the integrator's merge**, which does not exist yet.
  It says what the merge CAN produce and what must be re-checked when it does.
* **Not a privacy claim.** Stage 36 establishes no privacy property and
  neither does this pre-read. What is at issue is condition 7 — whether the
  changed files are still the files the gates' ports describe.
* **Not a review of the lane's stages 1–35**, nor of main's host changes.

## Sections (filled in below as each is established)

1. The delta, and what it touches
2. The production-identity claim, re-derived — proof and evidence separated
3. Conditions 1–7, one by one
4. §9 items 5, 6, 7, 8 and 11
5. The attacks, and what they found
6. The three-way digest table, and the re-pin the security owner can paste
7. Findings P36-1 …
8. Verdict

*(sections to follow in the next commits)*
