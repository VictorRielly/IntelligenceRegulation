"""Stage hash/key/ASCII coverage for all twelve new R13 run profiles."""
from pathlib import Path

out=Path(__file__).resolve().parent
src=out.parent/'working-tree/hashline/src/private_block'

def once(s,old,new):
    assert s.count(old)==1,old[:100]
    return s.replace(old,new)

s=(out/'trained_statement.candidate.rs').read_text()
needle='#[cfg(test)]\nmod accuracy_metadata_tests {'
s=once(s,needle,'''#[cfg(test)]
pub(super) fn accuracy_hash_model(sh:&Shape,l:usize)->TrainedModelStatement {
    accuracy_metadata_tests::hash_census_model(sh,l)
}

'''+needle)
(out/'trained_statement.candidate.rs').write_text(s)

s=(src/'s24_tests.rs').read_text()
s=once(s,'    runs.extend(super::trained_calib_tests::registered_trained_runs().into_iter().map(|(p, _)| p));',
    '    runs.extend(super::trained_calib_tests::registered_trained_runs().into_iter().map(|(p, _)| p));\n    runs.extend(super::accuracy_profile_tests::registered_runs().into_iter().map(|(p,_)|p));')
s=once(s,'    run_shapes.extend(super::trained_calib_tests::registered_trained_runs());',
    '    run_shapes.extend(super::trained_calib_tests::registered_trained_runs());\n    run_shapes.extend(super::accuracy_profile_tests::registered_runs());')
needle='    profiles.extend([RUN_PROFILE_RUNG_G, RUN_PROFILE_RUNG_K4, RUN_PROFILE_M125]);'
s=once(s,needle,needle+'''
    profiles.extend(super::trained_calib_tests::registered_trained_shapes().into_iter().map(|s|s.profile));
    profiles.extend(super::accuracy_profile_tests::registered_shapes().into_iter().map(|s|s.profile));
    profiles.extend(super::trained_calib_tests::registered_trained_runs().into_iter().map(|(p,_)|p));
    profiles.extend(super::accuracy_profile_tests::registered_runs().into_iter().map(|(p,_)|p));''')
(out/'s24_tests.candidate.rs').write_text(s)

s=(src/'s25_tests.rs').read_text()
needle="    // the registry, read out of the source exactly as stage 24 reads it"
s=once(s,needle,'''
    for (p,sh) in super::accuracy_profile_tests::registered_runs() {
        for l in [1usize,22] {
            let spec=IoSpec::new_shaped(&sh,s25_context(),0,0).unwrap();
            let model=super::trained_statement::accuracy_hash_model(&sh,l);
            let st=RunStatement::new_bound_from_digests(RunShape::accuracy(sh.clone(),l).unwrap(),s25_context(),
                ExpectedIo::from_roots(spec,[1;32],[2;32]),model.layers.iter().map(|r|r.block_digest).collect(),
                &vec![super::ENDPOINT_SCALES;l],&model).unwrap();
            profiles.push((p.to_string(),sh.clone(),Some((p,l,st))));
        }
    }
'''+needle)
needle='all_shapes.len() + every_run().len() + super::trained_calib_tests::registered_trained_runs().len()'
s=once(s,needle,needle+' + super::accuracy_profile_tests::registered_runs().len()')
(out/'s25_tests.candidate.rs').write_text(s)

s=(src/'s33_tests.rs').read_text()
needle='    built.extend(super::trained_calib_tests::registered_trained_runs().iter().map(|(p, _)| p.to_string()));'
s=once(s,needle,needle+'\n    built.extend(super::accuracy_profile_tests::registered_runs().iter().map(|(p,_)|p.to_string()));')
(out/'s33_tests.candidate.rs').write_text(s)
print('Staged complete R13 run profile/hash/key/ASCII coverage; legacy argument fixtures unchanged.')
