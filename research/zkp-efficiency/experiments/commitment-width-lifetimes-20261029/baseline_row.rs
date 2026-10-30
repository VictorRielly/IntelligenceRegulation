fn baseline_row<'a>(
    ntt: &NttTables, data: &[Fp], pads: &[Fp], pows: &[Fp],
    out: &'a mut [MaybeUninit<Fp>],
) -> &'a mut [Fp] {
    let n = data.len();
    let q = pads.len();
    assert_eq!(out.len(), pows.len());
    assert!(n.checked_add(q).is_some_and(|end| end <= out.len()));
    let mut coeffs = data.to_vec();
    ntt.inverse(&mut coeffs);
    let (message, tail) = out.split_at_mut(n);
    let (pad, zeros) = tail.split_at_mut(q);
    // These disjoint slices cover ALL of out, including the padding tail.
    // Preserve the existing encoder's interleaved pad addition/subtraction
    // even when q > n: coefficient j then contains pad[j-n] - pad[j].
    for (i, v) in message.iter_mut().enumerate() {
        let x = if i < q { coeffs[i].sub(pads[i]) } else { coeffs[i] };
        v.write(x.mul(pows[i]));
    }
    for (i, v) in pad.iter_mut().enumerate() {
        let x = if n + i < q { pads[i].sub(pads[n + i]) } else { pads[i] };
        v.write(x.mul(pows[n + i]));
    }
    for v in zeros { v.write(Fp::ZERO); }
    // SAFETY: the three loops above initialized every element. MaybeUninit<T>
    // has the same size/alignment as T. The returned slice borrows exactly
    // this initialized, exclusive row, not any other worker's storage.
    unsafe { std::slice::from_raw_parts_mut(out.as_mut_ptr().cast::<Fp>(), out.len()) }
}
