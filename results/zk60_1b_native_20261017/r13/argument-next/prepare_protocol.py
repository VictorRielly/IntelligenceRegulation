"""Stage ACT3 histogram/helper plumbing, without activating R13 proofs."""
from pathlib import Path

out=Path(__file__).resolve().parent
text=(out/'protocol.ctx.candidate.rs').read_text()

def replace(old,new):
    global text
    assert text.count(old)==1,old[:100]
    text=text.replace(old,new)

replace('''    let (_, act_missed) = act_histogram(&act_indices(lay, wit), &wit.planes[ids.at(A_A16)], &blk.feed_forward().act);''','''    let (_, act_missed) = match blk.accuracy() {
        Some(data)=>super::accuracy_act::histogram(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)])?,
        None=>act_histogram(&act_indices(lay,wit),&wit.planes[ids.at(A_A16)],&blk.feed_forward().act),
    };''')
replace('''    let act_idx = act_indices(lay, &wit);
    let (mut m_act, act_missed) = act_histogram(&act_idx, &wit.planes[ids.at(A_A16)], &ff.act);''','''    let act_idx = if blk.accuracy().is_some() {Vec::new()} else {act_indices(lay,&wit)};
    let (mut m_act, act_missed) = match blk.accuracy() {
        Some(data)=>super::accuracy_act::histogram(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)])?,
        None=>act_histogram(&act_idx,&wit.planes[ids.at(A_A16)],&ff.act),
    };''')
replace('''        a_data[lay.a_off[ids.at(A_MACT)] + i] = Fp::new(m_act[i]);
    }
    ph.mark''','''    }
    // ACT3 has one registered 4096-row table per public group; its support
    // is independent of the 256-entry byte/exp families. The remaining
    // committed multiplicity entries stay zero.
    for (i,&count) in m_act.iter().enumerate() {
        a_data[lay.a_off[ids.at(A_MACT)] + i]=Fp::new(count);
    }
    ph.mark''')
replace('''        assert!(from < U8_LEN && to >= U8_LEN && to < sh.size(Dom::Tab) && to % U8_LEN == from, "the hook moves a count to the PADDED COPY of its own row");''','''        assert!(from < m.len() && to >= m.len() && to < sh.size(Dom::Tab), "the hook moves a count outside its family's registered support");''')
replace('''    let act_den = act_idx.iter().zip(wit.planes[ids.at(A_A16)].iter()).map(|(i, a)| alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*a))).add(g_act))).collect();''','''    let act_den = match blk.accuracy() {
        Some(data)=>super::accuracy_act::query_values(sh,data,&wit.planes[ids.at(A_G8)],&wit.planes[ids.at(A_A16)],beta,g_act)?
            .into_iter().map(|query|alpha.sub(query)).collect(),
        None=>act_idx.iter().zip(wit.planes[ids.at(A_A16)].iter()).map(|(i,a)|alpha.sub(Fp2::from_i64(*i).add(beta.mul(Fp2::from_i64(*a))).add(g_act))).collect(),
    };''')
replace('''    let [gu8, gexp, gact] = hids.table_helpers();
    for (plane, tv, m) in [''','''    let [gu8, gexp, gact] = hids.table_helpers();
    let act_table=match blk.accuracy() {
        Some(data)=>{
            let table=super::accuracy_act::table(data,sh.size(Dom::Tab),beta,g_act)?;
            table.compressed[..table.entries].to_vec()
        },
        None=>table_values_act(ff,beta,g_act),
    };
    for (plane, tv, m) in [''')
replace('''        (gact, table_values_act(ff, beta, g_act), &m_act),''','''        (gact, act_table, &m_act),''')
replace('''            _ => (gact, super::argument::table_values_act_at(tab_len, ff, beta, g_act)),''','''            _ => (gact,match blk.accuracy() {
                Some(data)=>super::accuracy_act::table(data,tab_len,beta,g_act)?.compressed,
                None=>super::argument::table_values_act_at(tab_len,ff,beta,g_act),
            }),''')
# Do not carry the misleading 256-only description into the new branch.
replace('''    // The three histograms are indexed by a TABLE ENTRY, so they are `U8_LEN`
    // long and their in-class guards test `[0, U8_LEN)` — never the row width
    // `N` (trap T-1). The two guards that index `public.exp` (256 words) and
    // `ff.act` (`[i16; 256]`) are what stops a widened `N` from turning a
    // graceful bucket-0 fallback into an out-of-bounds panic (missed pin M-4).''','''    // Histograms are indexed by registered table entries, never row width:
    // byte/exp and legacy ACT have 256 entries; ACT3 has groups*4096.
    // Invalid queries retain the bucket-0/miss refusal before A masks.''')
(out/'protocol.act3.candidate.rs').write_text(text)
print('Staged ACT3 histogram, all-entry inversions, helpers and tail-mutation hook; proof activation refusal remains.')
