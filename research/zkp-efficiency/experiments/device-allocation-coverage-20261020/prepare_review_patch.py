"""Review-only textual diff, never applied/compiled; active GPU lane owns source."""
import difflib,hashlib,json,pathlib
HERE=pathlib.Path(__file__).resolve().parent
old=(HERE/'source/gpu__cuda.rs').read_text()
new=old
anchor='''        let mut keep: Vec<CudaSlice<u64>> = Vec::new();
        for (t, sp) in srcs.iter().enumerate() {'''
replacement='''        let mut keep: Vec<CudaSlice<u64>> = Vec::new();
        // RESEARCH REVIEW CANDIDATE: reuse storage only, never private values.
        // cudarc 0.13.9 copy_into uses this device's stream and synchronizes;
        // each upload therefore follows the preceding table consumer.
        // Lazy allocation: fully resident sources allocate no staging here.
        let mut host_stage: Vec<CudaSlice<u64>> = Vec::new();
        for (t, sp) in srcs.iter().enumerate() {'''
assert new.count(anchor)==1;new=new.replace(anchor,replacement)
anchor='''                            let d_src = dev.htod_sync_copy(as_u64s(&host[*off..*off + l])).map_err(|e| format!("fzc upload: {e}"))?;
                            unsafe { f_fp.clone().launch(cfg, (&d_src, &mut dst, l as i32)) }.map_err(|e| format!("k_tab_from_fp: {e}"))?;
                            keep.push(d_src);'''
replacement='''                            if host_stage.is_empty() {
                                let b = unsafe { dev.alloc::<u64>(l) }.map_err(|e| format!("fzc upload: {e}"))?;
                                host_stage.push(b);
                            }
                            dev.htod_sync_copy_into(as_u64s(&host[*off..*off + l]), &mut host_stage[0]).map_err(|e| format!("fzc upload: {e}"))?;
                            unsafe { f_fp.clone().launch(cfg, (&host_stage[0], &mut dst, l as i32)) }.map_err(|e| format!("k_tab_from_fp: {e}"))?;'''
assert new.count(anchor)==1;new=new.replace(anchor,replacement)
anchor='''                            let d_re = dev.htod_sync_copy(as_u64s(&host[*re..*re + l])).map_err(|e| format!("fzc upload: {e}"))?;
                            let d_im = dev.htod_sync_copy(as_u64s(&host[*im..*im + l])).map_err(|e| format!("fzc upload: {e}"))?;
                            unsafe { f_fp2.clone().launch(cfg, (&d_re, &d_im, &mut dst, l as i32)) }.map_err(|e| format!("k_tab_from_fp2: {e}"))?;
                            keep.push(d_re);
                            keep.push(d_im);'''
replacement='''                            while host_stage.len() < 2 {
                                let b = unsafe { dev.alloc::<u64>(l) }.map_err(|e| format!("fzc upload: {e}"))?;
                                host_stage.push(b);
                            }
                            let (left, right) = host_stage.split_at_mut(1);
                            let d_re = &mut left[0];
                            let d_im = &mut right[0];
                            dev.htod_sync_copy_into(as_u64s(&host[*re..*re + l]), d_re).map_err(|e| format!("fzc upload: {e}"))?;
                            dev.htod_sync_copy_into(as_u64s(&host[*im..*im + l]), d_im).map_err(|e| format!("fzc upload: {e}"))?;
                            unsafe { f_fp2.clone().launch(cfg, (&*d_re, &*d_im, &mut dst, l as i32)) }.map_err(|e| format!("k_tab_from_fp2: {e}"))?;'''
assert new.count(anchor)==1;new=new.replace(anchor,replacement)
anchor='''        drop(keep);
        note_vram(&g);
        st.secs_build = t0.elapsed().as_secs_f64();'''
replacement='''        drop(keep);
        drop(host_stage); // the existing build synchronize has completed every consumer
        note_vram(&g);
        st.secs_build = t0.elapsed().as_secs_f64();'''
assert new.count(anchor)==1;new=new.replace(anchor,replacement)
patch=''.join(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),fromfile='a/hashline/src/gpu/cuda.rs',tofile='b/hashline/src/gpu/cuda.rs'))
(HERE/'review-only-host-stage-reuse.patch').write_text(patch)
(HERE/'candidate-cuda.rs').write_text(new)
(HERE/'patch-manifest.json').write_text(json.dumps(dict(status='UNBUILT_UNAPPLIED_REVIEW_ONLY',source_sha256=hashlib.sha256(old.encode()).hexdigest(),candidate_sha256=hashlib.sha256(new.encode()).hexdigest(),patch_sha256=hashlib.sha256(patch.encode()).hexdigest(),scope='host-backed Base/Pair only; same requested-length raw storage; no production edits'),indent=2)+'\n')
print('Review-only patch prepared; no native compile or application.')
