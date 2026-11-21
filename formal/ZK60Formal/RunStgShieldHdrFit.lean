/-
D63 lane L63 (2026-11-21, leg 17): **the binder `hhdrFit` of `sshC_productionReadyL_epP_blkEF`** (every run header's
variable-length words fit the query bound `Lq`).

`hhdrFit : ∀ hd, 64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq` speaks only of
the header-word function `hw` and of `Lq`. `hR : ShieldRun Rp` speaks only of the run's blocks (their calibrations),
and `hL20 : 2^20 ≤ Lq` only of `Lq`. `hw` is a free parameter of the top (inventory group C), so:
* **`shd_hhdrFit_indep`**: for every run `Rp` with `ShieldRun Rp` and every `Lq` (in particular every `Lq ≥ 2^20`)
  there is a header-word function for which `hhdrFit` is FALSE (one header whose shape word has `Lq` bytes).
  `hhdrFit` does NOT follow from `hR` and `hL20`;
* **`shd_hhdrFit_of_len`**: it follows from `hL20` and the length bound `shape + params + chunk ≤ 2^20 - 148` on every
  header;
* **`shd_hhdrFit_of_code`**: in particular from the code's fixed widths (`run-shape`: eleven `u64`, 88 bytes; D41's
  chunk: seven `u64`, 56 bytes; RunAbsHdr.lean's reading of classify.rs:1275-1291) and a parameter line of at most
  `2^20 - 292` bytes on every header.

No top is changed and the binder stays. Only `propext`, `Classical.choice`, `Quot.sound`.
-/
import ZK60Formal.RunStgShieldClTopEF

set_option autoImplicit false

namespace ZK60.ProtocolClassify

open ZK60.RunShape ZK60.RunShape.Shield

/-- **`hhdrFit` from a length bound** on every header's three variable-length words, with `hL20`. -/
theorem shd_hhdrFit_of_len {Hdr : Type} (hw : Hdr → ClsHdrW) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (hlen : ∀ hd : Hdr, (hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length ≤ 2 ^ 20 - 148) :
    ∀ hd : Hdr, 64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq := by
  intro hd
  have h := hlen hd
  have e : (2 : ℕ) ^ 20 = 1048576 := by norm_num
  rw [e] at hL20 h
  omega

/-- **`hhdrFit` at the code's fixed widths**: an 88-byte `run-shape` word, a 56-byte chunk word, and a parameter line of
at most `2^20 - 292` bytes, on every header. -/
theorem shd_hhdrFit_of_code {Hdr : Type} (hw : Hdr → ClsHdrW) (Lq : ℕ) (hL20 : 2 ^ 20 ≤ Lq)
    (hshape : ∀ hd : Hdr, (hw hd).shape.length = 88) (hchunk : ∀ hd : Hdr, (hw hd).chunk.length = 56)
    (hpar : ∀ hd : Hdr, (hw hd).params.length ≤ 2 ^ 20 - 292) :
    ∀ hd : Hdr, 64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq :=
  shd_hhdrFit_of_len hw Lq hL20 fun hd => by
    have h := hpar hd
    have e : (2 : ℕ) ^ 20 = 1048576 := by norm_num
    rw [hshape hd, hchunk hd]
    rw [e] at h ⊢
    omega

/-- Header words whose shape word has `n` bytes (the counterexample's, at `n = Lq`; kept symbolic in `n`). -/
def shdHdrLong (n : ℕ) : ClsHdrW :=
  ⟨List.replicate n 0, List.Vector.replicate 32 0, List.Vector.replicate 32 0, [],
    List.Vector.replicate 32 0, List.Vector.replicate 32 0, []⟩

/-- At every `Lq`, header words with an `Lq`-byte shape word do not fit `Lq`. -/
theorem shdHdrLong_not_fit (Lq : ℕ) :
    ¬ 64 + ((shdHdrLong Lq).shape.length + (shdHdrLong Lq).params.length + (shdHdrLong Lq).chunk.length + 84)
      ≤ Lq := by
  simp only [shdHdrLong, List.length_replicate, List.length_nil]
  omega

/-- **`hhdrFit` does not follow from `hR` and `hL20`**: for every run with the app's calibrations and EVERY `Lq` (so
every `Lq ≥ 2^20`) there are header words at which it fails. -/
theorem shd_hhdrFit_indep (Rp : ClassifyRunPublicP shieldS0) (_hR : ShieldRun Rp) (Lq : ℕ) :
    ∃ hw : Unit → ClsHdrW,
      ¬ ∀ hd : Unit, 64 + ((hw hd).shape.length + (hw hd).params.length + (hw hd).chunk.length + 84) ≤ Lq :=
  ⟨fun _ => shdHdrLong Lq, fun h => shdHdrLong_not_fit Lq (h ())⟩

end ZK60.ProtocolClassify
