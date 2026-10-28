# Reversible fraction storage: exact, full-column capacity negative

Cycle0110, run `20261020T181854Z-27090273`. Research-only Python candidate:
[reversible.py](../experiments/reversible-fraction-tree-20261020/reversible.py).
**Do not promote a native full-column replacement on these results.**

Interface: `Tree(read,n).build()`, then `expand('batch'|'individual')` and
nonmutating `layer()` in original adjacent-subtree order. `consume()` plugs the
layer factory into the prior exact native-Fp2 tiled cubic consumer. This is an
arithmetic/storage seam, not a native private-proof implementation. The natural
order model uses strided reads; OpenVM's bit-reversed GPU layout was not ported.

Both N,D reconstruct exactly from a parent and preserved right child. Main
2,838 checks /306 consumers; independent5,745 checks /174layers /348MSB MLEs,
16pins,10 symbolic profiles. All controls and commands are in the
[experiment](../experiments/reversible-fraction-tree-20261020/README.md).

For max2^21 leaves,64MiB retained tree +16MiB batch-prefix scratch gives80MiB
selected peak withq>=3, versus prior36.022MiB selected consumer. q0..2 peak
128.023/96.016/80.012MiB. Consumer folds must use separate storage or they
destroy future restoration data. All native masks/CFS/PCS/allocator/source
owners are additional and unknown. Individual inverses avoid prefix scratch
but cost51.94M/48.40M inversions per8B T128 nonDD/DD forest; batch mode uses
1569/1551 and adds311.62M/290.39M recovery Fp2 multiplications.

Conditional source scans fall to one per column, avoiding261.13M/244.61M reads
vs the prior adaptive model. That is no native time saving: no production
fraction-tree protocol exists here. Existing256-entry U8 reciprocal caching
must remain credited to the baseline. Zero denominators with zero numerator
and root-preserving wrong ordered sources are checked, but native refusal/RNG/
transcript timing and original numeric Id/PCS mapping remain unimplemented.

Next local gate: bounded reversible subtrees plus immutable frontier under the
prior selected budget. Count frontier, rescans and all consumer/prefix capacity.
Existing leaf reciprocals might reduce last-layer inversion scratch; untested.
Retain this full-column negative and the prior per-intermediate-mask negative.

Native seams remain `protocol::lookup_values_at/u8_denominator_inverses/helper_one/
write_h`, `argument::helper_sum/SC_TAB` and private claim/CFS/PCS construction.
The original ordered-A/table reduction and integrated private recursion need a
reviewable design first. No public roots/claims, reused private openings/masks,
or weakened relation is authorized. No production diff, build, GPU job or merge.
Main/Claude reviews before integration; complete phase/capacity/resident workload
measurements and all-elevenFZC A/B remain higher priority.
