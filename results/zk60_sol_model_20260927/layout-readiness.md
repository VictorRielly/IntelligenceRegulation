# Allocation-free Mistral geometry probe (2026-09-27)

This probes the current generic private-block candidate at
`/tmp/zk60-groups-20260926` for the **historical 7.24B-parameter Mistral
8B-class proxy**. Victor's literal >=8B target remains unmet. No Mistral
private-block profile or complete calibration is registered. The probes
use a distinct `unregistered-layout-probe/1` string and never build a
witness, PCS commitment or receipt.

The test-only harness in
`/tmp/zk60-sol-model-20260927/hashline/src/private_block/shape.rs`
calls the candidate's actual `Shape::new`, `Layout::for_shape`, and
`Shape::totals`. It also calls the registered `Shape::toy` and
`Shape::m125` controls. The former exactly reproduced frozen 455 A / 384 H
rows and the 2,816,472-byte counted receipt; the latter reproduced 5,681 A
/ 7,120 H rows. The Rust test passed under `cargo test --offline --locked
-j 2` with `/tmp/zk-build.lock`; its output is `layout_probe.log`.
`layout_account.py` reads that output, checks those controls, and produces
`layout_account.json`. All quantities below are **computed payload bytes**,
not measured peak RSS, VRAM, transfers or proof speed. The inspected
baseline source hashes are in `layout_source_pins.txt`, and the isolated
test-only addition is preserved as `layout_probe.patch`.

## Geometry and committed matrices

Both proposed shapes use Mistral config `d=4096`, `f=14336`, 32 query heads,
8 KV heads, `dh=128`; the probe asks for the registered 125M path's
`log_cols=14`, inverse rate 4, `F_E=9`. These are **probe choices**, not an
accepted Mistral profile. `Shape::new` and `Layout::for_shape` returned
success at both T512 and T1024. The endpoint row requests follow
`endpoint_g.rs`: `ceil(T·d/16384)+5` = 133 and 261. For a two-site
internal run boundary, `boundary.rs` instead gives data rows + 6 = 134
and 262. The harness also called `EndpointSpecG::new_with_tag` and
`BoundarySpec::new_with_tag`; both returned those row counts at both probes.
The constructors' success is only a geometry result; it does not
establish a valid integer window, quantization, model binding or privacy.

| Count from the constructors | T512 | T1024 |
|---|---:|---:|
| A rows (data rows) | 18,633 (18,379) | 50,315 (50,061) |
| H rows (data rows) | 23,032 (22,922) | 64,376 (64,266) |
| A/H claim sites | 126 / 54 | 126 / 54 |
| M rows, fixed 4,096-column mask codeword | 50 | 50 |
| One A/H data row, 16,384 `Fp` | 131,072 B | 131,072 B |
| One encoded A/H row, 65,536 `Fp` | 524,288 B | 524,288 B |
| A raw data / encoded matrix | 2,442,264,576 / 9,769,058,304 B | 6,594,887,680 / 26,379,550,720 B |
| H raw data / encoded matrix | 3,018,850,304 / 12,075,401,216 B | 8,437,891,072 / 33,751,564,288 B |
| A + H raw/codeword plus PCS pads, salts and Merkle nodes | **27,403,487,168 B (25.52 GiB)** | **75,411,363,776 B (70.23 GiB)** |
| A + H plus M encoded plus two live internal boundaries | **27,593,893,760 B (25.70 GiB)** | **75,770,066,816 B (70.57 GiB)** |
| One hypothetical block receipt, `Shape::receipt_bytes` | 100,290,760 B | 250,373,272 B |

The A/H counts include all source-defined data rows, two mask rows per claim
site and each commitment's proximity pair. A/H `CommittedZk` retains its
raw `Vec<Fp>`, full rate-4 encoded matrix, 256 pad symbols per row, 65,536
32-byte salts and a 131,071-node Merkle tree. The M line includes its
`50×4096×8 = 1,638,400`-byte encoded matrix; its masks, coefficient vectors,
salts and tree are extra. Each internal boundary count includes its own
raw data, encoded matrix, pads, salts and tree. One boundary is ~90 MiB
at T512 and ~170 MiB at T1024. Hashing temporarily holds leaf/salted-leaf
vectors; encoders have per-thread NTT scratch; openings and the serialized
segment add more. Thus the bold totals are **strict live-set floors**, not
peak predictions.

The domain jump explains T1024's cost. `S` goes from 8,388,608 to
33,554,432 elements (attention's `H·T²`), moving each S plane from 512 to
2,048 rows; 13 A and 9 H planes live on S. `F` doubles from 8,388,608 to
16,777,216 padded elements: Mistral's 14,336 hidden channels round to
16,384. Domain counts and padding are recorded per shape in the probe log.

## Lifetimes and capacity

In `protocol.rs`, A is committed first and retained while M is committed.
H data is then allocated while A, M, the witness and looked-up byte columns
still exist. After H's last helper use, the code explicitly drops the
witness, looked columns, exponent deltas and activation indices; H is then
committed. A and H are both retained through the 23 sumcheck slots. M is
opened and dropped, then A and H are opened and dropped in order. In
`run.rs`, the next hidden boundary is prepared before the current block,
and the previous boundary is still live for its joint opening. The completed
segment is handed to `DirSink` before the next stage. Row encoding is
parallel *by row*, but `encode_rows` allocates the **entire encoded matrix**;
it does not stream one row to disk or evict it after hashing.

At T512, the witness's A-plane `Vec<i64>` payload is another counted
2.24 GiB and the `looked` `Vec<i64>` columns another 2.41 GiB before their
drop; exponent deltas and activation indices are 64 MiB each. These sets
need not overlap with both final encoded matrices, so simply adding every
listed buffer would overstate a peak. They do overlap with A plus H's raw
data during H construction. At T1024 witness and looked are 6.11 and
6.69 GiB. Uncounted matmul/attention temporaries and allocation overhead
increase the actual peak further.

| Machine | Capacity conclusion from **payload floors** | Execution status |
|---|---|---|
| Current RTX 4070 Laptop, 8 GiB VRAM; host historically ~15 GiB | T512 A's raw+codeword alone is ~11.37 GiB. A/H live floor is 25.70 GiB, above both VRAM and host RAM. | Cannot fit this materialized implementation on the current machine. |
| One RTX 5090, 32 GiB VRAM | T512 A/H/M/two-boundary floor is 25.70 GiB, leaving <6.30 GiB before witness, model weights, scratch, allocator and runtime. T1024 floor is 70.57 GiB, already beyond VRAM. | T512 **capacity is not ruled out by this floor**, but no working GPU private path or peak measurement exists. A memory-bounded schedule/streaming is required for larger T. |
| M3 Ultra, 512 GB unified memory | Both counted floors fit in unified memory, before additional scratch and OS use. | No corresponding native GPU backend; CUDA code cannot pool memory or execution across machines. CPU/unified-memory feasibility and 50 proved-token/s performance remain separate questions. |

The **frozen baseline inspected here** at `/tmp/zk60-groups-20260926`
deliberately declines the CUDA backend for tagged PCS commitments: its
device BLAKE3 column hash is unkeyed, while these private profiles require
tagged hashes. In that baseline, materialized A/H codewords reside on
**host** memory. A separate keyed GPU candidate's attempt 2 has passed
resident, streamed, compact and tagged full rung-G correctness; its
independent legacy gate remains pending. The VRAM
figures here are capacity checks for a prospective resident schedule, not
measurements of that candidate or a GPU/host co-residency claim. No 5090
throughput claim follows from these counts. Keeping all FFN export weights
resident adds 5.64 GB for 32 layers; a viable 5090 schedule would need
weight streaming or cache policy as well as committed-matrix lifetime work.

The unregistered receipt-byte figures count a single block under the
source's present layout formulas. They are not real receipts, full-stack
receipt sizes or privacy acceptance. The first runnable trained step still
needs the actual checkpoint export restored, full-block integer
calibration/witness construction, a separate Mistral profile and verification
of one trained block before a full stack can be clocked.

**Later candidate audit:** the separate keyed GPU candidate now has a
chunked A/H store that retains raw device rows, pads and powers but no full
encoded codewords, and re-encodes sampled columns at opening. Its
source-only host/VRAM accounting is in
[`gpu-chunked-memory-audit.md`](gpu-chunked-memory-audit.md). The bold
materialized floors above remain the frozen baseline or CUDA-decline
case; they should not be attributed to a successful GPU chunked run.
