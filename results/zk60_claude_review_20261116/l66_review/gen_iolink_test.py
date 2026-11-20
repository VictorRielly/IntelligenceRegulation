D='/Users/victorrielly/IntelligenceRegulation/results/zk60_claude_review_20261116/l66_review/'
b=open(D+'RunStgShieldIOLink_branch.lean').read()
test = r'''
namespace ZK60.ProtocolClassify
open ZK60 ZK60.Exec ZK60.Exec.Link ZK60.Sound
open ZK60.Exec.StageV (IncV OutcV)
open ZK60.Circuit (gP GF)

-- REVIEW TEST (reviewer-generated). The three conjuncts of hCsIO are copied verbatim from
-- RunBlkPinsHd.lean:3385-3387, with csIOI := csIOO := stgCsIOv ... . The branch theorems are applied with their own
-- extra hypotheses (hU, and the width hypotheses hle) left as explicit assumptions.
example {K : Type} [Field K] [Algebra GF K] (U : K) (hbij : Function.Bijective (ZK60.Hiding.fp2 (F := GF) U))
    (tag : MTag) {L : ℕ} (h64 : 64 ≤ L) (hU : U ^ 2 = algebraMap GF K 7) (Vi : IncV) (F : ℕ → OutcV)
    (lcI hI QI eI rI iI lcO hO QO eO rO iO : ℕ)
    (hle0 : Vi.pub.epLogN ≤ lcI) (hle1 : Vi.geo.bLogN ≤ lcO) (hleO : ∀ b, (F b).geo.bLogN ≤ lcI) :
    let csIOI : StgVw L → Block.Cm → Block.ZClaim → K := stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO
    let csIOO : StgVw L → Block.Cm → Block.ZClaim → K := stgCsIOv U tag h64 lcI hI QI eI rI iI lcO hO QO eO rO iO
    ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.pub.epLogN (ZK60.ProtocolClassify.IncPrivIO0 Vi.pub) csIOI
      ∧ ZK60.ProtocolClassify.StgCsIODeg U hbij Vi.geo.bLogN (ZK60.ProtocolClassify.IncPrivIO1 Vi.pub) csIOI
      ∧ ∀ b, ZK60.ProtocolClassify.StgCsIODeg U hbij (F b).geo.bLogN (ZK60.ProtocolClassify.OutcPrivIO (F b).pub) csIOO :=
  ⟨ssh_hIO0 U hbij tag h64 hU Vi lcI hI QI eI rI iI lcO hO QO eO rO iO hle0,
   ssh_hIO1 U hbij tag h64 hU Vi lcI hI QI eI rI iI lcO hO QO eO rO iO hle1,
   ssh_hIOO U hbij tag h64 hU F lcI hI QI eI rI iI lcO hO QO eO rO iO hleO⟩

end ZK60.ProtocolClassify
'''
open(D+'IOLinkTest.lean','w').write(b+'\n'+test)
