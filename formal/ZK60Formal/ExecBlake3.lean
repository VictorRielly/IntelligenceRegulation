/-
D63 step L5 (the executable verifier), the foundation: BLAKE3, executable, in its three modes (plain `hash`, keyed
`keyed_hash` = `blake3::Hasher::new_keyed`, and `derive_key`), with the extendable output.

What is mirrored: the BLAKE3 specification (O'Connor, Aumasson, Neves, Wilcox-O'Hearn, 2020-01-09,
`github.com/BLAKE3-team/BLAKE3-specs`, `blake3.pdf` §2) and its reference implementation (`reference_impl/
reference_impl.rs` in `github.com/BLAKE3-team/BLAKE3`), which the `blake3` crate 1.8.7 the code links
(`zkp-core/Cargo.toml`: `blake3 = "1.8"`) computes byte for byte:
* the compression function: the IV of SHA-256, the message permutation `[2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14,
  15, 8]`, seven rounds of the `G` mixing on the columns then the diagonals (rotations 16, 12, 8, 7), the 64-bit counter
  in words 12–13, the block length and the flags in words 14–15, and the output feed-forward
  (`state[i] ^= state[i + 8]`, `state[i + 8] ^= cv[i]`);
* the flags `CHUNK_START = 1`, `CHUNK_END = 2`, `PARENT = 4`, `ROOT = 8`, `KEYED_HASH = 16`, `DERIVE_KEY_CONTEXT = 32`,
  `DERIVE_KEY_MATERIAL = 64`;
* chunks of 1024 bytes and blocks of 64, the last block zero-padded, `CHUNK_START` on a chunk's first block and
  `CHUNK_END` on its last; the empty input is one empty block; the chunk counter is the chunk's index;
* the tree: more than one chunk splits into a left subtree of the largest power of two of chunks below the count and the
  rest (`hazmat::left_subtree_len`), parents are a compression of the two children's chaining values under the key with
  `PARENT`, and the root node is compressed with `ROOT`, its output blocks counted from `0` (the extendable output);
* the modes: `hash` keys with the IV, `keyed_hash` with the key's little-endian words and `KEYED_HASH`, and `derive_key`
  hashes the context string with `DERIVE_KEY_CONTEXT` and then the material under that context key with
  `DERIVE_KEY_MATERIAL`.

Nothing here is proved about BLAKE3 itself: the security model treats it as a random oracle (decision D19; ruling T-1:
a family of independent random functions indexed by the mode and key), so the verifier's theorems
(`ExecTranscript.lean`, `ExecMerkle.lean`) are stated for EVERY hash function `H`, and this file only supplies the `H`
that the executable verifier runs. That it is BLAKE3 is a TEST, not a proof: `L5Check.lean` checks it against all 35
cases × 3 modes × 131 bytes of the official test vectors (`test_vectors/test_vectors.json` of the BLAKE3 repository,
pinned in `results/zk60_lean_l5_20261106/blake3_test_vectors.json`) and against the Rust crate's outputs in the corpus.
The definitions are written for `lean --run` (arrays, no proofs); the kernel never evaluates them.
-/
import ZK60Formal.ExecField

namespace ZK60.Exec.Blake3

/-- The IV (SHA-256's). -/
def IV : Array UInt32 :=
  #[0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19]

/-- The message permutation. -/
def PERM : Array Nat := #[2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8]

def CHUNK_START : UInt32 := 1
def CHUNK_END : UInt32 := 2
def PARENT : UInt32 := 4
def ROOT : UInt32 := 8
def KEYED_HASH : UInt32 := 16
def DERIVE_KEY_CONTEXT : UInt32 := 32
def DERIVE_KEY_MATERIAL : UInt32 := 64

def BLOCK_LEN : Nat := 64
def CHUNK_LEN : Nat := 1024

/-- `u32::rotate_right`. -/
@[inline] def rotr (x n : UInt32) : UInt32 := (x >>> n) ||| (x <<< (32 - n))

/-- The mixing function `G` on four state words with two message words. -/
def g (s : Array UInt32) (a b c d : Nat) (mx my : UInt32) : Array UInt32 :=
  let s := s.set! a (s[a]! + s[b]! + mx)
  let s := s.set! d (rotr (s[d]! ^^^ s[a]!) 16)
  let s := s.set! c (s[c]! + s[d]!)
  let s := s.set! b (rotr (s[b]! ^^^ s[c]!) 12)
  let s := s.set! a (s[a]! + s[b]! + my)
  let s := s.set! d (rotr (s[d]! ^^^ s[a]!) 8)
  let s := s.set! c (s[c]! + s[d]!)
  s.set! b (rotr (s[b]! ^^^ s[c]!) 7)

/-- One round: the columns, then the diagonals. -/
def round (s m : Array UInt32) : Array UInt32 :=
  let s := g s 0 4 8 12 m[0]! m[1]!
  let s := g s 1 5 9 13 m[2]! m[3]!
  let s := g s 2 6 10 14 m[4]! m[5]!
  let s := g s 3 7 11 15 m[6]! m[7]!
  let s := g s 0 5 10 15 m[8]! m[9]!
  let s := g s 1 6 11 12 m[10]! m[11]!
  let s := g s 2 7 8 13 m[12]! m[13]!
  g s 3 4 9 14 m[14]! m[15]!

def permute (m : Array UInt32) : Array UInt32 := PERM.map (fun i => m[i]!)

/-- The compression function: 16 output words. -/
def compress (cv m : Array UInt32) (counter : UInt64) (blockLen flags : UInt32) : Array UInt32 :=
  let s0 : Array UInt32 := #[cv[0]!, cv[1]!, cv[2]!, cv[3]!, cv[4]!, cv[5]!, cv[6]!, cv[7]!,
    IV[0]!, IV[1]!, IV[2]!, IV[3]!, counter.toUInt32, (counter >>> 32).toUInt32, blockLen, flags]
  let s := round s0 m
  let m := permute m
  let s := round s m
  let m := permute m
  let s := round s m
  let m := permute m
  let s := round s m
  let m := permute m
  let s := round s m
  let m := permute m
  let s := round s m
  let m := permute m
  let s := round s m
  (Array.range 16).map (fun i => if i < 8 then s[i]! ^^^ s[i + 8]! else s[i]! ^^^ cv[i - 8]!)

def first8 (w : Array UInt32) : Array UInt32 := w.extract 0 8

/-- The byte at `i` of the input, `0` at or beyond `lim` (the zero padding of a short last block). -/
@[inline] def byteAt (inp : ByteArray) (lim i : Nat) : UInt32 := if i < lim then (inp.get! i).toUInt32 else 0

/-- The 16 little-endian message words of the block at `off`, `len ≤ 64` bytes long. -/
def blockWords (inp : ByteArray) (off len : Nat) : Array UInt32 :=
  let lim := off + len
  (Array.range 16).map (fun i =>
    let o := off + 4 * i
    byteAt inp lim o ||| (byteAt inp lim (o + 1) <<< 8) ||| (byteAt inp lim (o + 2) <<< 16)
      ||| (byteAt inp lim (o + 3) <<< 24))

/-- A node not yet compressed: its input chaining value, block, counter, block length and flags. -/
structure Output where
  cv : Array UInt32
  m : Array UInt32
  counter : UInt64
  blockLen : UInt32
  flags : UInt32

def Output.chainingValue (o : Output) : Array UInt32 := first8 (compress o.cv o.m o.counter o.blockLen o.flags)

/-- The root's output bytes (`outLen` of them): output block `t` is the root compression at counter `t`. -/
def Output.rootBytes (o : Output) (outLen : Nat) : ByteArray := Id.run do
  let mut out : ByteArray := ByteArray.empty
  let nBlocks := (outLen + 63) / 64
  for t in [0:nBlocks] do
    let w := compress o.cv o.m t.toUInt64 o.blockLen (o.flags ||| ROOT)
    for i in [0:16] do
      let x := w[i]!
      out := out.push x.toUInt8
      out := out.push (x >>> 8).toUInt8
      out := out.push (x >>> 16).toUInt8
      out := out.push (x >>> 24).toUInt8
  return out.extract 0 outLen

/-- One chunk (`len ≤ 1024` bytes at `off`, chunk index `idx`): every block but the last compressed into the chaining
value; the last one left as the chunk's output, with `CHUNK_END`. -/
def chunkOutput (key : Array UInt32) (flags : UInt32) (inp : ByteArray) (off len : Nat) (idx : UInt64) : Output :=
  Id.run do
    let nb := if len = 0 then 1 else (len + 63) / 64
    let mut cv := key
    for b in [0:nb - 1] do
      let start := if b = 0 then CHUNK_START else 0
      cv := first8 (compress cv (blockWords inp (off + 64 * b) 64) idx 64 (flags ||| start))
    let lastOff := off + 64 * (nb - 1)
    let lastLen := len - 64 * (nb - 1)
    let start := if nb = 1 then CHUNK_START else 0
    return { cv := cv, m := blockWords inp lastOff lastLen, counter := idx, blockLen := lastLen.toUInt32,
             flags := flags ||| start ||| CHUNK_END }

/-- A parent node over two chaining values. -/
def parentOutput (key : Array UInt32) (flags : UInt32) (l r : Array UInt32) : Output :=
  { cv := key, m := l ++ r, counter := 0, blockLen := 64, flags := flags ||| PARENT }

/-- The largest power of two strictly below `n ≥ 2` (`hazmat::left_subtree_len` in chunks). -/
def leftChunks (n : Nat) : Nat := 2 ^ Nat.log2 (n - 1)

/-- The chaining value of the subtree over `n ≥ 1` chunks starting at chunk `c0` (`fuel ≥ n` bounds the recursion). -/
def subtreeCV (key : Array UInt32) (flags : UInt32) (inp : ByteArray) : Nat → Nat → Nat → Array UInt32
  | 0, _, _ => key
  | fuel + 1, c0, n =>
    if n ≤ 1 then
      let off := CHUNK_LEN * c0
      (chunkOutput key flags inp off (min CHUNK_LEN (inp.size - off)) c0.toUInt64).chainingValue
    else
      let l := leftChunks n
      (parentOutput key flags (subtreeCV key flags inp fuel c0 l) (subtreeCV key flags inp fuel (c0 + l) (n - l)))
        |>.chainingValue

/-- The root node of the whole input. -/
def rootOutput (key : Array UInt32) (flags : UInt32) (inp : ByteArray) : Output :=
  let n := if inp.size = 0 then 1 else (inp.size + CHUNK_LEN - 1) / CHUNK_LEN
  if n = 1 then chunkOutput key flags inp 0 inp.size 0
  else
    let l := leftChunks n
    parentOutput key flags (subtreeCV key flags inp n 0 l) (subtreeCV key flags inp n l (n - l))

/-- BLAKE3 under a key's words and mode flags, `outLen` bytes. -/
def hashWith (key : Array UInt32) (flags : UInt32) (inp : ByteArray) (outLen : Nat) : ByteArray :=
  (rootOutput key flags inp).rootBytes outLen

/-- A 32-byte key's little-endian words. -/
def keyWords (k : ByteArray) : Array UInt32 := blockWords k 0 32 |>.extract 0 8

/-- `blake3::hash` (any output length). -/
def hash (inp : ByteArray) (outLen : Nat := 32) : ByteArray := hashWith IV 0 inp outLen

/-- `blake3::keyed_hash` / `blake3::Hasher::new_keyed(key)`. -/
def keyedHash (key inp : ByteArray) (outLen : Nat := 32) : ByteArray := hashWith (keyWords key) KEYED_HASH inp outLen

/-- `blake3::derive_key(context, material)` (any output length). -/
def deriveKey (context : ByteArray) (material : ByteArray) (outLen : Nat := 32) : ByteArray :=
  let ck := hashWith IV DERIVE_KEY_CONTEXT context 32
  hashWith (keyWords ck) DERIVE_KEY_MATERIAL material outLen

end ZK60.Exec.Blake3
