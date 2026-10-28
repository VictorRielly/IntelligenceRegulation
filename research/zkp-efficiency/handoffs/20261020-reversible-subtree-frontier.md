# Disposable reversible tiles — negative integration note

Cycle0111, `20261020T191854Z-93bbe548`. **Do not port this schedule as a saving.**
Research patch/interface: [frontier.py](../experiments/reversible-subtree-frontier-20261020/frontier.py),
`Frontier(read,n,f,mode,leaf_inverse).layer(d)` and `consume(...)`.
Read returns the original ordered `(numerator,denominator)` native-field pair.
Modes: direct reduction, per-tile batch recovery, final-leaf reciprocal cache.
The last callback reads the current attempt's original source key; this read
is charged and cannot be reused across proof attempts.

At the matched8B T128one-block schedule, allarms36.022MiB selected peak and
identical313.066M/293.012M nonDD/DDsourcegenerations. Tiles add construction,
recovery and inversions; cached leaf recovery adds35.389M/33.620M keyreads.
No native work removed. Whole-column capacity negative and earlier naive
per-intermediate-mask negative remain. Per-tile inversion is tested; cross-tile
batch inversion or coalesced GPU layouts would be different experiments.

Main3470checks/472consumers/63controls; independent6280checks/354consumers,
528capacityevents,22pins,10prior count profiles pass. Source hashes,commands,
seed,source/refusal/order controls and corrected pin-bookkeeping failure are
retained in the [experiment](../experiments/reversible-subtree-frontier-20261020/README.md).

Native eventual seams remain frozenR9 `protocol::lookup_values_at` (line394),
`u8_denominator_inverses` (712), `helper_one` (764), `write_h` (850), and
`argument::helper_sum` (934)/SC_TAB. This supplies no production patch or private
GKR, CFS, original-A input-consistency, commitment or PCS adapter. Publishing
the unmasked rows/roots would reveal data. Native refusal/RNG/transcript order,
numeric Id/point mapping, whole-proof security and current privacy gates must
be reviewed independently. No mask/opening reuse or profile change authorized.

Next local: exact public LUT/cardinality census for D32 versus DD, avoiding
duplicate owned fidelity/native jobs. Owner's GPU/resident/phase work and
all-elevenFZC A/B take priority. Main/Claude reviews any integration; no merge.
