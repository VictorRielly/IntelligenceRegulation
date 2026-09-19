# zk60-native-tools

A small host-only helper crate. The `zkvm-block` and `zkvm-model` wrapper CLIs
use it to check the native RISC Zero Groth16 tool directory before running any
tool in it.

## Interface

```rust
let tools = zk60_native_tools::validate_tool_directory(Path::new(tool_dir))?;
// tools.dir: the canonicalized directory
// tools.files: name, path, len, and sha256 hex for each pinned file
// tools.path("prover"), tools.path("stark_verify"), ...
```

`ToolError` implements `std::error::Error`, so `?` works with `Box<dyn Error>`.
`validate_with_pins(dir, pins)` runs the same check against caller-supplied
pins. It exists for tests; the wrappers should call `validate_tool_directory`.

## What is checked

1. The directory is canonicalized with `Path::canonicalize`, the same call the
   wrappers use, and must be a directory.
2. For each pinned file, `lstat` on the final path component must report a
   regular file. Symlinks, directories, other non-regular files, and missing
   files are rejected. `prover` and `stark_verify` must have at least one
   execute bit set.
3. The `lstat` size must equal the pinned length, so a wrong-sized file is
   rejected before any of it is read.
4. The file is opened and its device and inode are compared with the `lstat`
   result. The file is then read in 64 KiB chunks, stopping after the pinned
   length plus one byte. The byte count and the SHA-256 must both match the
   pin. Memory use does not depend on file size, so the 2.2 GB proving key is
   never loaded into RAM.

The crate only reads files. It does not run commands, download anything,
delete files, or use the network. Its only dependency is `sha2 = "=0.10.9"`,
and it contains no `unsafe` code.

## Pinned source

These files are from the official image `risczero/risc0-groth16-prover:v2025-04-03.1`,
manifest `sha256:7f173963196570b7a71816ed70565a4579264c5d2e3e0ecb028102538ad0e331`:

| file | bytes | sha256 |
|---|---:|---|
| `prover` | 14627939 | `a30a45c2f38b116fd123fee219ec3e40925670b64585f196e291a22d3cef281e` |
| `stark_verify.cs` | 260664474 | `0670f7c8ce8fe757d0cf4808c5d5cd92c85ac7a96ea98170c2f6f756d49e80b5` |
| `stark_verify_final.pk.dmp` | 2255766633 | `6d76b07e187e3329b1d82498a5f826366c3b2e04fc6d99de3d790248eb1ea71f` |
| `stark_verify` | 148060624 | `e407f61d2c6b9ee338e8194e10bef6ed815bd7497f9fac4687aa4944faa169c9` |
| `stark_verify.dat` | 46203464 | `f120ed88d4d090f7b4b78aef7dcc94bd98ecff6e592ea9f7a629c4279231b8b4` |

## Limitations

- This is a provenance check at validation time: it shows the bytes matched the
  pinned release when they were read. It does not verify the Groth16 trusted
  setup ceremony or the correctness of the tools.
- It cannot protect against another process running as the same user that
  changes or replaces a file after validation, or during hashing, but before
  the wrapper executes or reads it. The inode comparison only catches a swap
  between `lstat` and `open`. Keep the tool directory in private scratch space
  owned by the user who runs the wrapper, as the wrappers already require.
- Only the final path component is checked for symlinks. Symlinks in parent
  directories are resolved by canonicalization, the same way the rest of the
  CLI handles them.
- The pins are only as trustworthy as the image manifest they were taken from.
- Unix only (uses `std::os::unix`).

## Tests

`cargo test` in this directory. The tests use a scratch directory under the
system temp dir, write 2 to 4 byte files, and check them against a test pin
for `"abc"`: matching contents, wrong contents of the same size, truncated,
oversized, symlink, a directory in place of the file, a missing file, a
missing execute bit, and a file passed as the directory. They also check that
the shipped pins are well formed. They never read or hash the real native
tools, and they never allocate anything large.
