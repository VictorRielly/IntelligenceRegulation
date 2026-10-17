// Review-only sketch. Uncompiled; no native proof or performance gate run.
// Use only at the public fixed-width coefficient seam, never global Fp2 mul.
fn mul_3x2(a: [Fp2; 3], b: [Fp2; 2]) -> [Fp2; 4] {
    let p0 = a[0].mul(b[0]);
    let p2 = a[1].mul(b[1]);
    let middle = a[0].add(a[1]).mul(b[0].add(b[1])).sub(p0).sub(p2);
    [p0, middle, p2.add(a[2].mul(b[0])), a[2].mul(b[1])]
}
