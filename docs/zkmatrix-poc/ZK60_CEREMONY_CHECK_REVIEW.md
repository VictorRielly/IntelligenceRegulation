# Ceremony-check preparation review — 2026-09-18

Codex independent, bounded source review of
`/tmp/zk60-loop-20260917/prepare_ceremony.py` and upstream snarkjs v0.7.5.
Only this document was written. No ceremony artifacts were downloaded or
hashed by this review; no setup verification, installation or heavy job was
run. Small primary-source pages were read to verify implementation claims.

**Disposition:** the chosen artifact pins are appropriate. The preparation
script's raw-key reuse gap was reported and its source fix inspected. A
disk-backed initial-key fallback can preserve the upstream verification
algorithm. Record its probabilistic checking limits and exact executed code;
neither artifact preparation nor an interrupted verifier means the ceremony
has been checked. D3/D4 remain accepted decisions. This work does not require
stopping the separate token-model implementation or reopening those decisions.

## Artifact identity and the raw-key reuse fix

The script selects the compressed key at `zkey/2024-05-17.1`, with SHA-256
`69c6056451ea814b37e30ccbc44639dbaafef73540cbfbff6ec7e68e2d325735`.
This is exactly the key pinned by the reviewed RISC Zero Dockerfile, which
converts that gzip and the generated R1CS into the native proving files.
It must not be replaced by an assumed-equivalent older raw-key URL.
[Pinned Dockerfile, lines 49–65](https://raw.githubusercontent.com/risc0/risc0/8c215e2f4ccdd935f0517bf05d90f1ae032840a9/groth16_proof/docker/prover.Dockerfile).

The R1CS SHA-256
`84d3c34b7c0eb55ad1b16b24f75e0b9de307f7b74089ea4a20a998390ee24178`
matches the vendor's published circuit artifact. Its procedure verifies the
final key against that circuit and the ceremony's Powers of Tau file.
[Official procedure](https://dev.risczero.com/api/trusted-setup-ceremony).
The script's complete BLAKE2b-512 value beginning `3063a0bd81d68711` and
ending `3b53c0ea544f` matches the published power-23 file entry, not merely
its filename. [snarkjs v0.7.5 artifact table, row 23](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/README.md).

The downloader checks size and digest after both a new/resumed transfer and
reuse, rejects artifact symlinks, checks resumed range starts, caps received
bytes and atomically publishes a completed partial through a hard link
(`prepare_ceremony.py:13`). The hard-coded sizes are transfer bounds; this
review checked the provenance of the digests, not remote object sizes.

**Original defect:** the first version skipped decompression if the raw
`stark_verify_final.zkey` already existed and simply recorded its hash.
That accepted an unrelated older raw key as prepared evidence even though
only the gzip had been pinned. A recorded hash without an expected or
derived comparison does not establish provenance.

**Source fix inspected:** current lines 45–62 reject raw symlinks and stream
the verified gzip to compute its decompressed SHA-256 and byte count,
comparing both against the raw file. This closes that reuse gap under the
trusted local filesystem assumption. The parent reports that the already
queued worker loaded the previous functions but started with an empty
directory: its initial decompression path is valid. The parent's separately
planned comparison at the actual verification gate should enforce the same
relationship regardless of which worker version prepared the files. This
review has not observed that gate execute.

## Disk-backed fallback preserves the two upstream steps

The v0.7.5 `verifyFromR1cs` implementation does exactly two operations:
generate an initial key from R1CS/PTAU using a `bigMem` output, then call
`verifyFromInit` with that initial key, the same PTAU and the candidate final
key. Replacing only the initial key's storage with a fresh disk filename
preserves this sequence; it does not replace the R1CS check with trust in an
arbitrary supplied initial key. [Upstream wrapper](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/src/zkey_verify_fromr1cs.js).

Conceptual equivalent, using the unchanged v0.7.5 implementation:

```javascript
const circuitHash = await zKey.newZKey(r1cs, ptau, freshInitPath, logger);
if (circuitHash === -1) throw new Error("initial key generation failed");
const valid = await zKey.verifyFromInit(freshInitPath, ptau, finalKey, logger);
if (valid !== true) throw new Error("final key verification failed");
```

Keep the input bytes fixed between calls; use a new private working
directory, publish/hash the initial file only after successful completion,
and bind its cache record to the exact R1CS/PTAU hashes and verifier code.
Never substitute this un-contributed initial key into the application prover.

This is not a guarantee that the fallback fits 15 GiB. `newZKey` still reads
large constraint/point sections and constructs substantial arrays; only the
initial output's storage changes. It can return `-1` for incompatible inputs
and closes its files on successful completion. [Initial-key implementation](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/src/zkey_new.js).
Retain the process-tree RSS/deadline watchdog for both steps. A 10 GiB
watchdog kill is a resource-limited, unfinished check, not evidence that the
ceremony is invalid. V8's old-space option alone does not bound all process
memory. Preserve the exact CLI attempt separately from any fallback result.

## Statistical qualification of a successful check

`verifyFromInit` checks contribution-chain consistency, circuit/header
agreement, unchanged IC/coefficient/A/B sections, and aggregate L/H pairing
relations. The L aggregate uses four random bytes per point, not a full
scalar-field element. H uses field-sized scalars from ChaCha initialized
with 32 random bytes. [Verifier, especially lines 144–190 and 214–315](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/src/zkey_verify_frominit.js).
The Node randomness helper uses `crypto.randomFillSync`.
[Randomness helper](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/src/misc.js).

**Mathematical qualification:** for a fixed nonzero L discrepancy in the
intended prime-order group, fix all coefficients except one multiplying a
nonzero discrepancy. At most one of its `2^32` possible values cancels the
aggregate. Thus the usual bound for this check is `2^-32` per pass.
Four independent passes with unchanged inputs reduce this particular bound
to `2^-128`. This is not a complete implementation-audit bound, a receipt
soundness bound, or a requirement to repeat the expensive check before
continuing the accepted implementation. Do not call one pass deterministic
verification of every key point or infer a 254-bit checking guarantee from
the curve's field size. No independent full point/subgroup-validation audit
was performed here.

A matching R1CS hash authenticates the published binary artifact; it does not
recompile or semantically audit the Circom verifier. This phase-two check
also does not independently authenticate contributor identities, prove
erasure of contribution secrets, or audit the phase-one ceremony. The vendor
lists those as separate concerns. [Official verification scope](https://dev.risczero.com/api/trusted-setup-ceremony).
Likewise, retain the existing provenance assumptions for the image's native
converter, `.pk.dmp` and circuit files: this job checks the pinned zkey, not
the complete native build. These limitations qualify the recorded check;
they do not reverse D4's accepted trusted-setup assumption.

## Other concrete preparation and reporting issues

- **Exit status:** current lines 73–77 catch failures and write `.done = 1`
  but do not exit Python with that code. The process can therefore exit zero
  on preparation failure. Propagate the code, or make the orchestration
  require the current marker and complete verification result; process exit
  zero alone is insufficient.
- **Retry handling:** exclusive creation of `npm-install.log` at line 67
  refuses any later preparation attempt after that log exists. An interrupted
  raw-key `.partial` also prevents its exclusive recreation at line 48.
  These fail closed but need explicit attempt logs/partial-file handling for
  autonomous recovery. Do not treat stale `ready.json` as a current success.
- **Tool provenance:** line 70 checks package version and line 71 records a
  newly resolved lock hash. Preserve the complete lock, registry integrity
  fields and actual verifier entrypoint hashes for later reproducibility;
  a version string alone does not pin every dependency or executable byte.
  The package's CLI uses `build/cli.cjs`, while Node ESM import uses
  `main.js`/source. Verify the path actually executed agrees with the reviewed
  source. [Package entrypoints/dependencies](https://raw.githubusercontent.com/iden3/snarkjs/v0.7.5/package.json).
- **Preparation is not verification:** `ready.json` correctly sets
  `setup_verification_run: false`. The verifier's success must be explicit:
  true result/successful exit, complete expected log, fixed input hashes,
  actual code/lock identity, and no timeout or RSS termination. A successful
  token/block receipt does not substitute for this ceremony check.

The next useful action is the already authorized, queued verification with
the raw-key equality gate and bounded execution. No new permission gate or
heavy work was introduced by this review.

## Bounded verification runner follow-up

Subsequently reviewed `/tmp/zk60-loop-20260917/verify_ceremony.py` and
`ceremony_check.mjs`, without launching them or downloading anything.
The actual plan is the equivalent disk-backed call sequence directly; this
runner does not first invoke the memory-backed CLI. Record that accurately.

**Controls verified in source:**

- `audit_inputs` independently checks all three published artifact pins and
  the decompressed key's equality to the pinned gzip. It rejects symlinks and
  non-regular artifact files; `ready.json` is not its acceptance oracle.
- The initial key is generated in a newly created `0700` `check-1` directory,
  not accepted from a previous unbound cache. Its hash/size is recorded after
  successful generation and rechecked before each verification pass.
- The ESM helper requires a 64-byte initial-key result and strictly
  `verifyFromInit(...) === true`. Each pass is a new Node process. Python
  requires exit zero, the helper's matching success record and no watchdog
  termination. A success-looking log with a failed exit is insufficient.
- The `/proc/<pid>/stat` parsing correctly selects session ID and resident
  pages. RSS is summed across processes in the new session; shared memory
  counted in several processes can make this conservative. Node worker
  threads share the process address space. `WNOWAIT` leaves the leader
  unreaped until process-group cleanup, avoiding PID/group reuse in that
  cleanup window. The `finally` block kills the process group on success,
  error or resource termination before reaping the child.
- Actual thresholds are **11 GiB session RSS**, **1.5 GiB minimum system
  MemAvailable**, a one-hour initial stage and half-hour verification stages,
  polled every 250 ms. They are watchdog thresholds, not hard allocation
  limits or guarantees against a fast memory spike. The configured V8
  old-space maximum is 7168 MiB. The initial plan's 10 GiB figure is not
  the implemented threshold.
- Result state begins with `verified: false`; ordinary caught exceptions
  preserve that state and set a nonzero marker/process exit (the interruption
  marker issue below needs correction). True is written only after four
  successful passes and a final artifact audit. Releasing the shared heavy
  lock between passes permits other jobs to run. It does not by itself make
  the input directory immutable or guarantee lock scheduling fairness.

**Evidence gaps to close or retain as assumptions:** the first inspected
`source_pins()` compared five entrypoint/verification files to upstream but
omitted `src/misc.js`, which provides the randomness underpinning the
independent-pass claim, and `src/zkey_utils.js`. Include at least those
helpers; preserve resolved dependency integrity/lock data as already
recommended. Record the Python runner, ESM helper and Node executable hashes
as well. Recheck those local source hashes across the unlocked stages rather
than fetching upstream again each time. The original runner checked code
once, whereas its final audit rechecked only input artifacts.

**Concrete interruption-marker correction:** both worker handlers initialize
`code = 0`, catch only `Exception`, and write the code in `finally`.
`KeyboardInterrupt`/`SystemExit` bypass that handler, so an interrupted run
can write a success `.done` marker without completing. Default to failure
(`code = 1`) and assign zero only after `run()` returns successfully. The
stage's process-group cleanup still runs; this issue is the inaccurate
completion marker. Requiring `result.verified` as well prevents accepting an
unfinished fresh check from that marker alone, but the marker should itself
remain fail-closed. This was sent to the parent before launch.

The original runner hashes the large inputs at the beginning and end, not
before every pass. Thus their stability between stages relies on the stated
trusted local filesystem/owner and unchanged ceremony directory. An
adversarial modify-and-restore operation would evade endpoint-only hash
comparisons. No such operation was observed; this is a precise limitation
of the evidence binding, not a demonstrated failure of the intended local
run. Fixed names and exclusive creation also make this a one-shot runner;
another attempt needs a fresh work/log identity, not reuse of stale success
files.

The corrected preparation source now has a `__main__` guard around launching
and `sys.exit(code)` after its worker handler. Its import no longer starts a
worker, and a newly started worker propagates failure status. The already
running original worker is still covered by the checker's independent input
audit and its explicit preparation marker check.

No application/guest blocker was identified. Lightweight runner controls
and the actual ceremony verification remain parent-led work; this follow-up
does not report them as passed.

## Source-fix confirmation before launch

The latest preparation and verification entrypoints now initialize
`code = 1` and assign zero only after `run()` returns successfully. Normal
completion and caught exceptions propagate the marker code through
`sys.exit`. A `BaseException` still determines its own process termination,
but now leaves a failure marker: even `SystemExit(0)` cannot produce a
successful marker before completion. This closes the interruption-marker
defect described above for newly started processes. The preparation module's
`__main__` guard also remains in place. Continue requiring the success result
and marker, not process exit alone.

The checker now compares `src/misc.js` and `src/zkey_utils.js` to upstream in
addition to the five previously checked files. Its local `code_pins()`
records the actual Node executable, both Python/ESM drivers, preparation
module, package lock and installed dependency tree. It checks those pins
again before each verification pass and after the final artifact audit.
This closes the previously reported missing-helper and cross-stage code
identity gaps under the stated trusted local filesystem assumption. The
dependency-tree record preserves consistency; it is not an independent
semantic audit of every dependency.

These corrections were confirmed by reading the updated source. The parent
reports six lightweight gate controls passed and a queued checker; this
review did not rerun those controls or observe a completed ceremony check.
The earlier statistical, phase-one, circuit-semantics and native-conversion
qualifications remain unchanged.
