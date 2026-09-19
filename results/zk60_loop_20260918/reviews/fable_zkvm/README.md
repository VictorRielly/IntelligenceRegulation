# Original Fable 5.1 zkVM construction proposal

Unmodified delivery from the isolated Claude lane at baseline `5d6f101`.
See `index.json` for source hashes. This is a proposal, not accepted security
evidence. Its recalled vendor facts need source verification. The missing
toolchain/source observations describe the start of that lane; the integrator
subsequently installed Rust 1.97.0 and fetched pinned RISC Zero 3.0.6 sources.

The parent task brief's reference to a mandatory 128-bit security threshold
was not established by the current project requirements. It must not create
a new approval gate. Actual security accounting remains necessary.

The proposed 260-byte journal is not the implemented 144-byte Rust profile.
The current experiment fixes shape/calibration in the verifier's guest image
and binds all public weight/table bytes through one model digest. It cannot
chain endpoints across roles. No claim of compatibility with old PCS roots
is made. Do not run this archived codec as a validator for the Rust profile.
