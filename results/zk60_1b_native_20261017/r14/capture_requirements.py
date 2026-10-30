"""Concrete native-capture/adapter contract and necessary entropy ledger.

This is an implementation specification, not a native capture or rank result.
"""
from datetime import datetime,timezone
import hashlib,json
from pathlib import Path
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
native=json.loads((HERE/'NATIVE_BUILDERS_CENSUS.json').read_text())
examples=[]
for groups in native['groups']:
    s=next(r for r in native['inventory'] if r['base_profile']==groups['base'] and r['f_e']==9)
    N=s['n'];Q=256;roles=[]
    for role,rows,g,sites,spare in [
        ('A',s['a_rows'],groups['a_groups'],s['a_sites'],0),
        ('H',s['h_rows'],groups['h_groups'],s['h_sites'],0),
        ('external',s['joint_external_rows'],2,2,1),
        ('internal-boundary',s['joint_internal_rows'],4,4,0),
    ]:
        masks=2*sites+spare+2
        raw=2*(g+1)*(N+Q)+rows*Q
        dependencies=2*(g+1)*Q
        random=masks*N+rows*Q
        roles.append({'role':role,'rows':rows,'piece_claim_column_groups':g,'exclusive_site_pairs':sites,
            'spare_rows':spare,'proximity_rows':2,'independent_mask_rows':masks,
            'raw_clear_opening_Fp_coordinates':raw,
            'necessary_column_recombination_dependencies':dependencies,
            'clear_coordinates_after_only_these_dependencies':raw-dependencies,
            'mask_plus_all_row_pad_Fp_coordinates':random,
            'necessary_entropy_slack':random-(raw-dependencies),
            'known_identity_note':'H has the one public Fp2 LogUp sum identity and two zero-sum U rows; identify its exact rowspace separately' if role=='H' else 'none assumed',
            'status':'necessary dimension accounting only; not an actual rank certificate, does not establish privacy'})
    examples.append({'base_profile':groups['base'],'tokens':s['tokens'],'dd':s['dd'],'N':N,'Q':Q,'roles':roles})
report={'utc':datetime.now(timezone.utc).isoformat(),
    'status':'DESIGN / implementation contract only; native R14 writer and privacy adapter not yet implemented',
    'proposed_schema':'hashline-native-capture/6-split-run',
    'schema_rules':['New explicit schema; legacy4/5 readers must refuse it until ported. No legacy plane index/count substitution.',
        'Reuse only audited public field/column/claim/array-store serializers, with every R14 source file and shared backend pinned.',
        'Verifier observer only: no private witness values, pads, mask coefficients, unmasked rounds, unopened columns or unpublished salts.',
        'Observe the actual accepted run. Rebuild an independent transcript from trusted public statement, ordered stage descriptors and roots; never adopt verifier state.',
        'Write bundle only after native verifier finish succeeds, allL stages close, every replay site agrees and no recorder failure exists.',
        'Observer attachment must not change native verifier acceptance; invalid/rejected captures cannot produce a bundle.'],
    'native_hooks':[
        {'site':'split_run::Verifier new','observe':'Trusted plan/model/context/root pair and fresh independently derived Statement transcript; stage profile/physical layout/endpoint specs'},
        {'site':'split_run stage start','observe':'Stage index/profile digest/block digest and outgoing B root before core challenges; replay exact R14 begin_stage and root absorption'},
        {'site':'split_protocol core roots','observe':'A and M before beta/gamma/alpha, H afterwards; exact actualchallenge order, with R14 hash tags'},
        {'site':'split_protocol argument before every split::define','observe':'Definition start on verifier side for ALL31/32slots, including new norm/matrix builders; legacy define hook covers only some slots'},
        {'site':'argument::run_slot_scheduled','observe':'Native SlotSchedule main/ext/degree/kind, raw typed Tab definitions, public tables/Eq points, private slices/projected coords/mask pairs, SC rounds/scalars/terminals/rho/c/mask_eval and hosted coefficients'},
        {'site':'split_protocol M opening','observe':'All46/48actual ordered MaskFunctionals/specs, root, q/prox/columns, replay before/after; verify with R14 tag'},
        {'site':'split_protocol A/H opening','observe':'Verifier-derived ZClaims and actual PCS public opening, physical row/index/group geometry, whole-H sum includingUrows; replay audits and PCS with R14 tag'},
        {'site':'split_run incoming/final joint opening','observe':'Exactly2external/4internal ordered claims; role/index/context/scale, both piece row blocks, source stage/slot map, fresh exclusive pairs, root and PCS public opening'},
        {'site':'split_run stage trailer/finish','observe':'Exact end tag and acceptedL stages; forbid dropped/duplicate/out-of-order stages or partial bundle'}],
    'capture_fields':['source manifest/binary pins','public ordered model/stage calibration digests','physical A/H role extent/offset/log/component map',
        'native slot schedule and actual source-coordinate maps','joint boundary ordered piece row blocks and single scale/context',
        'native transcript site index/before-after states','public definition tables and masked SC values','M specs/functionals/opening',
        'A/H/external/boundary ZClaims and public PCS vectors/columns/salts/paths','accepted run trailer and receipt digests'],
    'privacy_adapter_acceptance':[
        'P1: exact native per-CM rank for A0, H2knownidentities, M, external and joint boundary; report kernels and exact known-identity rowspace, not only a dimension count',
        'P2: native CFS mask budget for each new combined norm/matrix/host polynomial; norm degree3 with B-gate folded into one existing public factor',
        'P3: three-stage native joint Ak/Bk/Ak+1 views, both D pieces, whole external endpoints, all four boundary claim sites and all masks/proximity/pads',
        'P4: private functional carries no sigma/lift coefficient; omitted feature bits are true broadcasts and public gates have correct native degree',
        'P5: one root per logical endpoint/boundary, one opening at the specified stage, no extra commitment-parameter channel, all root-reuse controls retained',
        'P6: no private partial accumulator or partial remainder planes; one full dot/norm and original integer rounding'],
    'necessary_entropy_examples':examples,
    'tight_boundary_observation':'Internal joint34rows =24data+8site+2proximity. Four Fp2 group vectors plus one Fp2 proximity vector expose10N Fp coordinates before columns/pads, matching10N mask coordinates after required recombination dependencies. This necessary balance is tight; full joint rank still must be measured/proved.',
    'scope_limits':'No privacy acceptance follows from this ledger or prior R13 acceptance. Experimental native source remains unregistered until freeze -> D24 -> privacy gate.',
    'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [
        HERE/'NATIVE_BUILDERS_CENSUS.json',HERE/'checkpoints/run-build-4/tree/hashline/src/private_block/split_run.rs',
        HERE/'checkpoints/run-build-4/tree/hashline/src/private_block/split_protocol.rs',
        HERE/'checkpoints/run-build-4/tree/hashline/src/private_block/split_endpoint.rs',
        HERE/'checkpoints/run-build-4/tree/hashline/src/private_block/run_capture.rs']}}
(HERE/'NATIVE_CAPTURE_IMPLEMENTATION_CONTRACT.json').write_text(json.dumps(report,indent=2)+'\n')
print('Prepared native R14 capture contract and necessary entropy accounting; no rank/privacy result')
