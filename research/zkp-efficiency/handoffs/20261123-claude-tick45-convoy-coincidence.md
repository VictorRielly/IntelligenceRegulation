# Research handoff: what ends the long waits that do not end at a buffer end, and a convoy test (2026-11-23, claude-tick 45, queue item 73)

From Claude, the background researcher. One cycle; local reading and a standard-library script; no web, no GPU, no build, no Git. **Triage material, not a work order;** nothing here changes a committed word, proof byte or the verifier.

**Question.** Tick 44 found that 35 to 40% of prover buffers waiting over 5 ms start within 0.5 ms after another queue's buffer end and about 60% do not. (1) For the long waiters, does the start coincide with another buffer's commit, host done, a clustered start, or nothing? (2) Test the co-coordinator's convoy hypothesis: lanes queue behind one long buffer, finish together, sit in host work together (nothing in flight), commit together and queue again.

**Read:** the item, tick 44's handoff and script, `results/zk60_lanes_trace_20261121/README.md` and `wait_owner_check.py`, and every row of the compressed traces of legs 2 (six lanes, 37,408 rows) and 5 (eight lanes, 38,763 rows). Script: `20261123-claude-tick45-convoy-coincidence.py` (`python3 -I -B <script> <raw/traces> [coin|convoy|supp]`, about a minute in all). The pass and fail lines are in the script's docstring and were written before the first count; section 'supp' was added after and is labelled not pre-registered. Labels: MEASURED (trace rows), DERIVED (script output), ARGUED. Central window: starts between 15% and 85% of the trace's span; events from the whole trace; whole traces, as in the co-coordinator's owner check.

## 0. Headline

1. **Convoy hypothesis, as pre-registered: REJECTED (B3 fails at both legs).** Buffers committed in the 5 ms after the end of a nothing-in-flight stretch are LESS often long waiters than average: 1.9% against 15.2% (x0.12) at six lanes, 2.5% against 31.0% (x0.08) at eight, equal to the shifted-queue null (x0.12, x0.08); they hold 3.7% and 2.2% of all long waiters (line: at least 40%; fail line: under 20%). B1 also fails (a cluster of ends before the gap: x1.06 and x1.14 of the null; fail line under x1.2). B2 passes but the band is too wide to discriminate (section 2).
2. **Nothing-in-flight stretches are real and not a null artefact** (MEASURED): at least 1 ms with no buffer committed-and-unfinished on any queue is 16.1% of the central window at six lanes (null 4.1%) and 19.6% at eight (null 0.6%); median length 2.7 and 2.9 ms. This agrees with tick 34's synchrony (lanes in host work together). It is not where the waits form: a buffer committed into an empty device starts at once, and its followers within 5 ms are also not long waiters.
3. **Commit and host DONE stamps of other queues are not the coincidence** (kinds 3, 4, section 1): the commit rate before a long waiter's start is BELOW the control (2.3% against 5.3%; 4.5% against 6.8%); host done is +1.4 and +0.9 points, under the line.
4. **What is real beyond a buffer end: other queues' prover buffers START together with it.** Among long waiters, 19.8% (six lanes) and 33.6% (eight) have no end in the 0.5 ms before but another queue's start within +-0.5 ms (control 4.6% and 3.8%; excess +15.1 and +29.8 points). Added to the end kinds, 63.0% (six) and 75.6% (eight) of long waiters coincide with an end or a start of another queue; the residue with nothing is 32.2% and 17.3%.
5. **The partners are long waiters too** (supplement, not pre-registered): 69.5% (six) and 80.7% (eight) of the prover buffers that start within 0.5 ms of such a long waiter wait over 5 ms themselves (all buffers: 15.2% and 30.7%). So the picture is a gang admission, several queued buffers on different queues starting together, not a convoy formed at the host.

## 1. Part A: the kind of coincidence, prover buffers with a wait over 5 ms (DERIVED; `coin`)

Kinds in priority on the 0.5 ms before the start (exclusive shares; kind 5 = another queue's device start within +-0.5 ms); control = the same classification at s +-1, 1.5, 2, 2.5, 3 ms for the same buffers.

| kind | leg 2 six lanes: measured / control | leg 5 eight lanes: measured / control |
|---|---:|---:|
| 1 end of another prover queue | 41.1% / 6.0% (x6.8) | 40.0% / 7.9% (x5.0) |
| 2 end of a sealing buffer | 2.1% / 0.5% | 2.0% / 0.4% |
| 3 commit on another queue | 2.3% / 5.3% (x0.43) | 4.5% / 6.8% (x0.66) |
| 4 host DONE on another queue | 2.7% / 1.3% | 2.6% / 1.7% |
| 5 a start on another queue, +-0.5 ms | 19.8% / 4.6% (x4.3) | 33.6% / 3.8% (x8.9) |
| 6 nothing | 32.2% / 82.3% | 17.3% / 79.3% |
| n (share of starts) | 2,886 (15.2%) | 5,961 (31.0%) |

The same table for buffers that wait up to 0.5 ms shows ratios of 1.0 to 1.2 on every kind (no coincidence beyond control; the 'end' kind +2.8 and +5.7 points); for 0.5 to 5 ms the end and start kinds are real at 0.3 to 0.5 of the long waiters' excess. **Pass rule of part A as written** ('nothing' at most 50% of the no-end long waiters at both legs, and one of kinds 3 to 5 real at both): leg 5 yes (29.8%), leg 2 NO (56.6% of the 1,640 starts with no end; kinds 3, 4, 5 hold 43.4%), so the rule is not met at six lanes. Kind 5 is real at both legs, kinds 3 and 4 at neither.

Supplement (`supp`, long waiters with no end before them, 1,640 and 3,454): a prover start of another queue in (s - 0.5, s] 21.2% (control 3.0%) at six lanes, 53.6% (2.5%) at eight; in (s, s + 0.5] 16.2% (3.1%) and 27.6% (2.8%); on both sides 0.4% and 16.1%. At six lanes the group is mostly a pair; at eight lanes there are groups of three or more. ARGUED: this is the signature of a release of several waiting buffers at once (the later side cannot have caused this start; it is a sibling, not a cause).

## 2. Part B: the convoy (DERIVED; `convoy`)

In flight = committed to device end, any buffer on any queue, sealing included. A gap = at least 1 ms with none in flight. Null: each prover queue and each sealing thread shifted by its own random offset around the trace, 20 draws.

| | leg 2 | leg 5 |
|---|---:|---:|
| gaps; share of window (null) | 4,036; 16.1% (4.1%) | 3,197; 19.6% (0.6%) |
| median gap length | 2.67 ms (null 2.47) | 2.90 ms (null 2.31) |
| B1 distinct queues with an end in the 1 ms before a gap start | 1.31 (null 1.24), x1.06: FAIL | 1.45 (null 1.27), x1.14: FAIL |
| B2 median gap in the per-queue host gaps' 25th to 75th percentile | inside (1.52 to 28.7 ms) | inside (1.68 to 37.5 ms) |
| B3 long-waiter share of buffers committed in [gap end, +5 ms] | 1.9% against 15.2%, x0.12 (null x0.12): FAIL | 2.5% against 31.0%, x0.08 (null x0.08): FAIL |
| share of all long waiters they hold | 3.7% (null 9.8%) | 2.2% (null 1.9%) |

The variant with gaps defined by execution (nothing executing) gives 19.9% and 24.3% of the window and the same verdicts (B3 x0.21 and x0.13). B2 is passed by almost any value (the per-queue gap distribution spans a factor of 19 between its quartiles) and carries no weight. **Caution on B3:** a buffer committed into an empty device cannot wait, so B3 was weak against the first commits by construction; what makes the rejection firm is that the followers within 5 ms also are not long waiters, and that the null gives the same ratio (the rejection is of "long waiters are committed at the end of a nothing-in-flight stretch", not of "lanes are synchronous on the host", which tick 34 and the excess of gaps over null above support).

## 3. What this says and does not say (ARGUED)

- A long wait has 63 to 76% of its starts explained as an end or a start on another queue; the starts are the new part, and they come in groups of waiting buffers. That is device-side: the traces cannot say whether it is the scheduler admitting queued buffers when some resource frees, the driver waking several queues together, or the stamp resolution making sequential starts look simultaneous.
- It is NOT evidence for a host convoy as the cause of the waits. Tick 34's host-side synchrony remains a separate fact (the gaps), not shown to cause the waits.
- Tick 44's stage-2 failure stands. A gang release was not tried in the replay (tick 44 released one or all at an end); adding it would be a refit, the replay line was stopped by item 60's own rule, and this tick proposes no replay.

## 4. Falsifiable next test (reading only; not scheduled)

**G-leg3:** run the same classification on leg 3 (six lanes, A36 on, 12 queues). Prediction under "the device admits waiting buffers in groups": the partners of a long waiter are long waiters (at least 60%) and kind 5 is real (ratio at least x3) on leg 3 as at legs 2 and 5. Fail: ratio under x1.5 on leg 3, then the grouping belongs to the queue-per-lane layout of those two legs. Leg 4 (one shared queue) cannot be read by this script (queues are the lane identity); a thread-based version is a small change.

## 5. Expected effect, risks, not verified

- **Committed words per request: 0. Proved tokens per second: none claimed.** A diagnostic of waiting only; no candidate is ranked, and per the standing rule it justifies no sealing-side or host-side work.
- **Risks:** gpu_start and gpu_end may be scheduled rather than executed times (a 0.5 ms 'simultaneous start' could be a stamp artefact: the mirror side's rise argues against pure chance, not against a stamp artefact); controls are +-1 to 3 ms shifts of the same buffers, which assumes the flat level; the shifted-queue null keeps each queue's waits and so breaks device sharing too; the central window and one trace per setting; the partner share counts prover buffers only; kind priority is a choice and the exclusive shares depend on it (the effect of testing kind 5 alone was not run).
- **Not verified:** whether the groups share a size, a slot or a tag (not split); the cause of any admission rule; what the 32% and 17% 'nothing' starts are (the control's own 'nothing' share is about 80%, so chance explains little of them); leg 3 and leg 4.
