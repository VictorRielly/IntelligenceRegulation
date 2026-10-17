// REVIEW SKETCH ONLY: uncompiled, no production patch or native validation.
// Intended inside a fixed-width SC_SZC row factory after prior factory gates.
// Fp2 denotes the existing canonical native field type; no global field change.
fn mul_affine(a: [Fp2; 2], b: [Fp2; 2]) -> [Fp2; 3] {
    let low = a[0].mul(b[0]);
    let high = a[1].mul(b[1]);
    let cross = a[0].add(a[1]).mul(b[0].add(b[1])).sub(low).sub(high);
    [low, cross, high]
}
