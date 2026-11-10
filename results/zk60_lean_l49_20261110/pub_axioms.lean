/- D63 lane L49, sub-agent pub: the axiom audit of every declaration of BlockR13HostPub.lean and of the checker's
theorems (BlockR13HostExportCheck.lean). Expected: at most propext, Classical.choice, Quot.sound. -/
import ZK60Formal.BlockR13HostPub
import ZK60Formal.BlockR13HostExportCheck

section
open ZK60.Exec.Block.Join.R13H.Pub
#print axioms pubsR13
#print axioms pubsR13_rest
#print axioms pubR_of
#print axioms gateLS
#print axioms gateLS_rung
#print axioms restR13_three
#print axioms restR13L
#print axioms restR13L_three
#print axioms restR13L_ne
#print axioms rest3R13L_getD
#print axioms PubCfg
#print axioms pubCfg_rung
#print axioms pubCfg_shield
#print axioms idsR13_e
#print axioms zeroPl_L
#print axioms lzc_gate
#print axioms rawSlot3_tabs
#print axioms pubsR13L
#print axioms pubR_of_L
#print axioms pubsR13L_three_getD
#print axioms pubsR13L_tab
end

section
open ZK60.Exec.Block.Join.R13H.Pub.Chk
#print axioms pubsR13_pubsRF
#print axioms foldTabR_eq
#print axioms pubsRFast_eq
#print axioms shieldTab_eq
end
