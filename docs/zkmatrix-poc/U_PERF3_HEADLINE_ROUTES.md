# U-PERF3 — the headline within the lattice line: what 5-15 s at 8B would take (design/literature memo, no code)

Status: SKELETON (2026-08-18, U-PERF3 round 1, lane T, worktree
wt-uperf3-t). Sections are filled and committed one at a time; the
"Agent T status" block in PROGRESS_UPERF3.md says which are done.

Scope: Victor's ruling of 2026-08-18 ("be more creative and find a
solution anyway") applied to the lattice line (Route R: MLWE/MSIS
commitments, exact-integer range facts, masked lookup, HVZK for the
declared private set). Question: the line measures 21.0 s for the
12x512 slice (1.4e9 proven int8 MAC/s, laptop GPU + 8 threads); the
contract needs 1.9-5.8e11 MAC/s (5-15 s at 8B x 512); the counted
route-1 change (U_PERF3_OPENING_LAYER_DESIGN.md Stage A/B) buys
<= ~2.5x; the eval proof (the lattice opening) is the floor and scales
~x100. What moves the exponent while keeping the assumption class?

Labels: [MEASURED] / [COUNTED] / [MODEL] / [ASSUMED] / [EXTERNAL]
(external numbers are unverified unless from a paper with code).

## 0. Recommendation (one paragraph)

(to be written last)

## 1. The built pass located in the family map, and what scales x100

(pending)

## 2. Candidates, with counts

### 2.1 (i) The full family-(c) O(sqrt N) reroute of the eval proof

(pending)

### 2.2 (ii) Folding across the 32 identical layers

(pending)

### 2.3 (iii) Batching level-0 claims beyond the R-row

(pending)

### 2.4 (iv) GPU-native restructuring: serial vs parallel, desktop board, N boards, the field

(pending)

### 2.5 (v) 2025-26 literature that fits

(pending)

### 2.6 (vi)+ own candidates

(pending)

## 3. Compositions and the honest reach

(pending)

## 4. Recommendation for a second design freeze + THE ONE spike

(pending)

## 5. References (with labels)

(pending)
