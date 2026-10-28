# Cycle 0101: native NTT gather sectors

Run `20261020T091854Z-d57182bc`. Research only; no native build or GPU.

Baseline: `k_ntt_p1` fuses a bit-reversed source gather with the first
min(12,logN) DIT stages in a 4096-word shared tile. `n_src` is both source
row stride and zero-extension bound, including the compact hiding n+q route.
No standalone reorder pass exists here. Nonhiding DIF/DIT already consumes
bit-reversed coefficients and is a separate route.

Refined question: can changing only ownership of the first-pass loads
reduce warp 32-byte sector requests while preserving each logical shared
tile? Test literal ownership, moving 1/2 low loop bits to the high shared
index, and fully reversed tile ownership. Count both requested global
sectors and shared-bank address pressure. Distinguish aggregate requests
from unique source sectors, cache misses, physical DRAM bytes, and time.

Eliminated work: no arithmetic, proof, masking, commitments, transforms,
stored bytes or passes. At most some first-pass source sector requests.
Added costs: integer index permutation and conflicting shared stores; no
extra buffer/barrier in the model. Registers, occupancy, compiler lowering,
cache behavior and actual exclusive elapsed fraction remain unknown.

Ceiling: if f is the measured complete-workload fraction of affected loads,
even deleting it gives 1/(1-f); actual candidate is narrower and adds costs.
No numerical whole-proof/GPU/token estimate without that measurement.
Falsify the broad claim if intra-CTA reordering cannot reduce sectors at
large native transforms, or shared pressure rises; reject any byte/address/
zero-tail mismatch. Owner must separately demonstrate enclosing improvement.

Independent reference: scalar bit-string reversal, per-byte interval sector
sets, explicit row bounds, and original-slot values. Native-style model uses
32-bit bitwise reversal and alternative load ownership. Include row/view
misalignment, compact n+q, q>n, zero extension, dense/DIF routes, 32/256/512
threads and large-domain sampled blocks. Negative controls alter each of
stride, bound, permutation, bank accounting and sector accounting.

One CPU thread, <=60s per leaf, <=512MiB address space; synthetic public
indices and generated values only. Never interpret Python wall time as NTT
or proving time. Pins and commands retained. Current native/profile/privacy
gates and fresh per-proof masks/openings remain mandatory.
