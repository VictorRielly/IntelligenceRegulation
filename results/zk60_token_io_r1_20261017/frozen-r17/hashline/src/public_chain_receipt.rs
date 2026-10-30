//! Experimental PUBLIC composition of exactly two fixed T32/d16/f16 blocks.
//! All external/intermediate tensors and constituent B4 proofs are public.
//! Not recursion, private composition, token generation, or a security audit.
//! Expected contracts/context/I/O must be approved independently of the bytes.
use crate::causal_oracle::{FixedCausalOracle, PublicBlockWeights};
use crate::merkle::Digest;
use crate::private_block_contract::ApprovedP1BlockContract;
use crate::public_block_receipt::{
    check_profile, verify_public_receipt, ExpectedPublicBlock, PublicBlockReceipt,
    PublicReceiptOracle, MAX_RECEIPT_BYTES, WORDS,
};

const COUNT: usize = 2;
const EXPECTED_MAGIC: &[u8; 8] = b"HLB5REQ1";
const RECEIPT_MAGIC: &[u8; 8] = b"HLB5RCP1";
pub const EXPECTED_CHAIN_BYTES: usize = 8 + 8 + 96 + 4 * WORDS;
const FRAME_OVERHEAD: usize = 8 + 32 + 8 + 2 * WORDS + 2 * 8 + 1;
pub const MAX_CHAIN_BYTES: usize = FRAME_OVERHEAD + 2 * MAX_RECEIPT_BYTES;

fn check_contracts(approved: &[ApprovedP1BlockContract; 2]) -> Result<(), String> {
    for (i, contract) in approved.iter().enumerate() {
        check_profile(contract)?;
        if contract.registration().attention.layer != i {
            return Err("public chain requires ordered layers 0 then 1".into());
        }
    }
    approved[0]
        .preflight_next_boundary(&approved[1])
        .map_err(|e| e.to_string())
}

/// Independent immutable public expected state. Exact replay remains valid;
/// application-level nonce consumption is outside this stateless verifier.
#[derive(Clone)]
pub struct ExpectedPublicChain {
    contracts: [Digest; 2],
    context: Digest,
    input: [i16; WORDS],
    output: [i16; WORDS],
    digest: Digest,
}
impl ExpectedPublicChain {
    pub fn new(
        approved: &[ApprovedP1BlockContract; 2],
        context: Digest,
        input: &[i16],
        output: &[i16],
    ) -> Result<Self, String> {
        check_contracts(approved)?;
        if context == [0; 32] {
            return Err("public chain requires nonzero context".into());
        }
        let mut s = Self {
            contracts: [approved[0].public_digest(), approved[1].public_digest()],
            context,
            input: input.try_into().map_err(|_| "public chain input shape")?,
            output: output.try_into().map_err(|_| "public chain output shape")?,
            digest: [0; 32],
        };
        s.digest = *blake3::hash(&s.to_bytes()).as_bytes();
        Ok(s)
    }
    pub fn digest(&self) -> Digest {
        self.digest
    }
    pub fn context(&self) -> Digest {
        self.context
    }
    pub fn input(&self) -> &[i16] {
        &self.input
    }
    pub fn output(&self) -> &[i16] {
        &self.output
    }
    pub fn to_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(EXPECTED_CHAIN_BYTES);
        out.extend_from_slice(EXPECTED_MAGIC);
        put_u32(&mut out, COUNT);
        put_u32(&mut out, WORDS);
        for digest in self.contracts {
            out.extend_from_slice(&digest);
        }
        out.extend_from_slice(&self.context);
        put_words(&mut out, &self.input);
        put_words(&mut out, &self.output);
        out
    }
    /// This file's provenance must be trusted separately from the receipt.
    pub fn from_bytes(
        approved: &[ApprovedP1BlockContract; 2],
        bytes: &[u8],
    ) -> Result<Self, String> {
        if bytes.len() != EXPECTED_CHAIN_BYTES {
            return Err("public chain expected frame size".into());
        }
        let mut r = Reader { bytes, at: 0 };
        r.tag(EXPECTED_MAGIC)?;
        r.exact(COUNT)?;
        r.exact(WORDS)?;
        for contract in approved {
            if r.take(32)? != contract.public_digest() {
                return Err("public chain expected approval/order mismatch".into());
            }
        }
        let context = r.take(32)?.try_into().map_err(|_| "context")?;
        let input = r.words()?;
        let output = r.words()?;
        r.finish()?;
        Self::new(approved, context, &input, &output)
    }
    fn check_approval(&self, approved: &[ApprovedP1BlockContract; 2]) -> Result<(), String> {
        check_contracts(approved)?;
        if self.contracts != [approved[0].public_digest(), approved[1].public_digest()] {
            return Err("public chain approval/order mismatch".into());
        }
        Ok(())
    }
    fn block_context(&self, index: usize) -> Digest {
        let mut h = blake3::Hasher::new_derive_key("ZK60 B5 public chain block context v1");
        // The digest pins format, count/order, both approved contracts, request
        // context, and ordered external tensors BEFORE either B4 commitment.
        h.update(&self.digest);
        h.update(&(index as u32).to_le_bytes());
        *h.finalize().as_bytes()
    }
    /// The candidate may supply the public middle words, but cannot independently
    /// choose the two expectations: they are the same signed INT16 tensor. B4
    /// authenticates these against actual first output and second input planes.
    pub fn block_expectations(
        &self,
        approved: &[ApprovedP1BlockContract; 2],
        intermediate: &[i16],
    ) -> Result<[ExpectedPublicBlock; 2], String> {
        self.check_approval(approved)?;
        Ok([
            ExpectedPublicBlock::new(
                &approved[0],
                self.block_context(0),
                &self.input,
                intermediate,
            )?,
            ExpectedPublicBlock::new(
                &approved[1],
                self.block_context(1),
                intermediate,
                &self.output,
            )?,
        ])
    }
}

/// Complete ordinary B4 receipts, not aggregation. The fixed array prevents a
/// typed caller from omitting/adding blocks; the parser independently checks 2.
#[derive(Clone, Debug)]
pub struct PublicChainReceipt {
    pub request_digest: Digest,
    pub intermediate: [i16; WORDS],
    pub blocks: [PublicBlockReceipt; 2],
}
impl PublicChainReceipt {
    pub fn to_bytes(&self) -> Result<Vec<u8>, String> {
        let bodies = [self.blocks[0].to_bytes()?, self.blocks[1].to_bytes()?];
        let length = FRAME_OVERHEAD + bodies[0].len() + bodies[1].len();
        if length > MAX_CHAIN_BYTES {
            return Err("public chain byte budget".into());
        }
        let mut out = Vec::new();
        out.try_reserve_exact(length)
            .map_err(|_| "public chain allocation refused")?;
        out.extend_from_slice(RECEIPT_MAGIC);
        out.extend_from_slice(&self.request_digest);
        put_u32(&mut out, COUNT);
        put_u32(&mut out, WORDS);
        put_words(&mut out, &self.intermediate);
        for (index, body) in bodies.iter().enumerate() {
            put_u32(&mut out, index);
            put_u32(&mut out, body.len());
            out.extend_from_slice(body);
        }
        out.push(0xe5);
        Ok(out)
    }
    /// Outer framing is fully checked before either nested decoder allocates.
    /// Two B4 codecs each cap requested decoded Vec capacity at 16 MiB: at most
    /// 32 MiB total plus fixed structs. Caller input, allocator overhead and
    /// subsequent legacy verifier copies/workspace are separate, not an RSS cap.
    pub fn from_bytes(bytes: &[u8]) -> Result<Self, String> {
        let frame = Frame::parse(bytes)?;
        Ok(Self {
            request_digest: frame.request_digest,
            intermediate: frame.intermediate,
            blocks: [
                PublicBlockReceipt::from_bytes(frame.blocks[0])?,
                PublicBlockReceipt::from_bytes(frame.blocks[1])?,
            ],
        })
    }
}

struct Reader<'a> {
    bytes: &'a [u8],
    at: usize,
}
impl<'a> Reader<'a> {
    fn take(&mut self, n: usize) -> Result<&'a [u8], String> {
        let end = self
            .at
            .checked_add(n)
            .ok_or("public chain length overflow")?;
        let bytes = self
            .bytes
            .get(self.at..end)
            .ok_or("public chain truncated frame")?;
        self.at = end;
        Ok(bytes)
    }
    fn tag(&mut self, tag: &[u8]) -> Result<(), String> {
        if self.take(tag.len())? != tag {
            return Err("public chain frame/version tag".into());
        }
        Ok(())
    }
    fn u32(&mut self) -> Result<usize, String> {
        Ok(u32::from_le_bytes(self.take(4)?.try_into().map_err(|_| "count")?) as usize)
    }
    fn exact(&mut self, want: usize) -> Result<(), String> {
        if self.u32()? != want {
            return Err("public chain fixed count/shape/order".into());
        }
        Ok(())
    }
    fn words(&mut self) -> Result<[i16; WORDS], String> {
        let bytes = self.take(2 * WORDS)?;
        let mut words = [0; WORDS];
        for (word, bytes) in words.iter_mut().zip(bytes.chunks_exact(2)) {
            *word = i16::from_le_bytes([bytes[0], bytes[1]]);
        }
        Ok(words)
    }
    fn finish(&self) -> Result<(), String> {
        if self.at != self.bytes.len() {
            return Err("public chain trailing bytes".into());
        }
        Ok(())
    }
}
struct Frame<'a> {
    request_digest: Digest,
    intermediate: [i16; WORDS],
    blocks: [&'a [u8]; 2],
}
impl<'a> Frame<'a> {
    fn parse(bytes: &'a [u8]) -> Result<Self, String> {
        if bytes.len() < FRAME_OVERHEAD || bytes.len() > MAX_CHAIN_BYTES {
            return Err("public chain frame size/budget".into());
        }
        let mut r = Reader { bytes, at: 0 };
        r.tag(RECEIPT_MAGIC)?;
        let request_digest = r.take(32)?.try_into().map_err(|_| "digest")?;
        r.exact(COUNT)?;
        r.exact(WORDS)?;
        let intermediate = r.words()?;
        let mut blocks: [&[u8]; 2] = [&[]; 2];
        for (index, block) in blocks.iter_mut().enumerate() {
            r.exact(index)?;
            let n = r.u32()?;
            if !(44..=MAX_RECEIPT_BYTES).contains(&n) {
                return Err("public chain constituent byte budget".into());
            }
            *block = r.take(n)?;
        }
        r.tag(&[0xe5])?;
        r.finish()?;
        Ok(Self {
            request_digest,
            intermediate,
            blocks,
        })
    }
}
fn put_u32(out: &mut Vec<u8>, value: usize) {
    // Only fixed constants or already bounded B4 encoded lengths reach here.
    out.extend_from_slice(&(value as u32).to_le_bytes());
}
fn put_words(out: &mut Vec<u8>, words: &[i16; WORDS]) {
    for word in words {
        out.extend_from_slice(&word.to_le_bytes());
    }
}

pub struct PublicChainOracle<'a> {
    approved: &'a [ApprovedP1BlockContract; 2],
    first: FixedCausalOracle,
    blocks: [PublicReceiptOracle<'a>; 2],
}
impl<'a> PublicChainOracle<'a> {
    pub fn new(
        approved: &'a [ApprovedP1BlockContract; 2],
        weights: [PublicBlockWeights; 2],
    ) -> Result<Self, String> {
        check_contracts(approved)?;
        let [w0, w1] = weights;
        // B4 enforces CPU-only/default Ligero policy before witness execution.
        let b0 = PublicReceiptOracle::new(&approved[0], w0.clone())?;
        let b1 = PublicReceiptOracle::new(&approved[1], w1)?;
        let first = FixedCausalOracle::new(&approved[0], w0).map_err(|e| e.to_string())?;
        Ok(Self {
            approved,
            first,
            blocks: [b0, b1],
        })
    }
    pub fn prove(&self, expected: &ExpectedPublicChain) -> Result<PublicChainReceipt, String> {
        expected.check_approval(self.approved)?;
        let first = self
            .first
            .build(expected.input())
            .map_err(|e| e.to_string())?;
        let mut intermediate = [0; WORDS];
        if first.residual.xres2.len() != WORDS {
            return Err("public chain oracle output shape".into());
        }
        for (to, from) in intermediate.iter_mut().zip(&first.residual.xres2) {
            *to = i16::try_from(*from).map_err(|_| "public chain oracle output range")?;
        }
        drop(first);
        let per_block = expected.block_expectations(self.approved, &intermediate)?;
        let blocks = [
            self.blocks[0].prove(&per_block[0])?,
            self.blocks[1].prove(&per_block[1])?,
        ];
        Ok(PublicChainReceipt {
            request_digest: expected.digest,
            intermediate,
            blocks,
        })
    }
}

pub fn verify_public_chain(
    approved: &[ApprovedP1BlockContract; 2],
    expected: &ExpectedPublicChain,
    receipt: &PublicChainReceipt,
) -> Result<(), String> {
    let per_block = expected.block_expectations(approved, &receipt.intermediate)?;
    if receipt.request_digest != expected.digest {
        return Err("public chain request mismatch".into());
    }
    for i in 0..COUNT {
        verify_public_receipt(&approved[i], &per_block[i], &receipt.blocks[i])
            .map_err(|e| format!("public chain block {i}: {e}"))?;
    }
    Ok(())
}

/// No weights, witness/oracle, prover, or candidate-derived approval. Decode
/// and verify one constituent at a time after checking the complete outer frame;
/// this entrypoint retains at most one codec's 16 MiB decoded capacity budget.
/// Acceptance is all-or-nothing; no partial acceptance callback is exposed.
pub fn verify_public_chain_bytes(
    approved: &[ApprovedP1BlockContract; 2],
    expected: &ExpectedPublicChain,
    bytes: &[u8],
) -> Result<(), String> {
    let frame = Frame::parse(bytes)?;
    let per_block = expected.block_expectations(approved, &frame.intermediate)?;
    if frame.request_digest != expected.digest {
        return Err("public chain request mismatch".into());
    }
    for i in 0..COUNT {
        let block = PublicBlockReceipt::from_bytes(frame.blocks[i])?;
        verify_public_receipt(&approved[i], &per_block[i], &block)
            .map_err(|e| format!("public chain block {i}: {e}"))?;
    }
    Ok(())
}
