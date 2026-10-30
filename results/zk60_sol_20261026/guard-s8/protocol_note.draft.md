

## Swap headroom update (S8, D44)

The installed guard is SHA-256 `88af4c639848d39df8da559652db11529575aa745b916a06eb522c20ea89fbd3`. While swap use exceeds 1 GiB,
admission requires MemAvailable to cover the declared need, the existing
1 GiB admission margin, and every swapped page. The normal memory check,
global declared budget, exclusive heavy lock, runtime floor and caps remain
in force. FIFO remains OFF. Both static consumers pin this release.

The guard sees only Linux/WSL VM memory. It cannot observe Windows host
memory pressure: high MemAvailable inside the VM does not establish that
the Windows host has headroom. This limitation applies to both swap rules.

Installation evidence and rollback: `results/zk60_sol_20261026/guard-s8/`
and `guard-s8-backup/`. The official 45-case, S3/FIFO 31-case and S8 policy 9-case
suites must all pass on the host without systemd skips before completion.
