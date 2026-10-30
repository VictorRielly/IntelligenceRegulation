# App admission correction, staged

The new durable demo exposes an overly strict preflight: before proving, the app waits for every guarded job, including a continuous0.7GiB reference chain. The shared-box lean rule permits light jobs of at most1GiB alongside the one large job. The candidate reads the documented status JSON and permits those light jobs, then invokes the same resource guard. It still waits for every CPU/build/GPU job and for larger light jobs. Malformed status fails closed.

Nine mocked tests pass: empty/small-light admission, all heavy classes blocked, oversized light jobs blocked, malformed/nonfinite/unknown declarations refused, original native threads/time limits preserved, exact guard memory and timeout arguments unchanged. No native proof, capacity change, guard edit, FIFO edit or privacy acceptance.

Do not edit the currently running pinned pipeline. Apply only after it is terminal and the active demo source pins can be explicitly superseded. Base hash and exact patch are retained. Current live violence supervisor365410 remains held until a5–10second gap with no guarded jobs; coordinator/Sol were asked in the Astra log.
