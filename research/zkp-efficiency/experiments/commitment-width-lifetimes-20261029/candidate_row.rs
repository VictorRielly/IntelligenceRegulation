// Candidate only: replace initialize_row in the pinned R13 CPU encoder.
// The caller has checked the shapes and keeps Vec length zero until all rows join.
fn candidate_row<'a>(
    ntt: &NttTables, data: &[Fp], pads: &[Fp], pows: &[Fp],
    out: &'a mut [MaybeUninit<Fp>],
) -> &'a mut [Fp] {
    let n = data.len();
    let q = pads.len();
    assert_eq!(out.len(), pows.len());
    assert!(n.checked_add(q).is_some_and(|end| end <= out.len()));
    let (message, tail) = out.split_at_mut(n);
    // Only form an Fp slice over the initialized prefix; tail is still uninitialized.
    for (dst, src) in message.iter_mut().zip(data) { dst.write(*src); }
    {
        // SAFETY: the loop wrote all n Fp values, with their original alignment.
        // The exclusive borrow ends before the enclosing output slice is formed.
        let coeffs = unsafe {
            std::slice::from_raw_parts_mut(message.as_mut_ptr().cast::<Fp>(), n)
        };
        ntt.inverse(coeffs);
        for (i, value) in coeffs.iter_mut().enumerate() {
            let x = if i < q { value.sub(pads[i]) } else { *value };
            *value = x.mul(pows[i]);
        }
    }
    let (pad, zeros) = tail.split_at_mut(q);
    for (i, dst) in pad.iter_mut().enumerate() {
        // q > n retains both overlapping pad contributions.
        let x = if n + i < q { pads[i].sub(pads[n + i]) } else { pads[i] };
        dst.write(x.mul(pows[n + i]));
    }
    for dst in zeros { dst.write(Fp::ZERO); }
    // SAFETY: prefix, pad and zero tail have all been initialized, disjointly.
    // Fp is Copy with no destructor; an earlier panic leaves the owner's length zero.
    unsafe { std::slice::from_raw_parts_mut(out.as_mut_ptr().cast::<Fp>(), out.len()) }
}
