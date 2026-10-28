// Local authored language-rule probe. Synthetic public bytes, no dependencies.
// A Drop counter makes temporary scope observable. This is not an allocator/RSS
// measurement of the production Vec implementation or a loader benchmark.
use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::ops::Deref;

#[derive(Default)]
struct Counter { live: Cell<usize>, peak: Cell<usize>, visits: RefCell<Vec<usize>> }
struct Decoded { values: Vec<i8>, counter: Rc<Counter> }
impl Deref for Decoded {
    type Target = [i8];
    fn deref(&self) -> &[i8] { &self.values }
}
impl Drop for Decoded {
    fn drop(&mut self) { self.counter.live.set(self.counter.live.get() - self.values.len()); }
}
fn decode(bytes: &[u8], c: &Rc<Counter>) -> Decoded {
    let live = c.live.get() + bytes.len();
    c.live.set(live); c.peak.set(c.peak.get().max(live));
    Decoded { values: bytes.iter().map(|b| *b as i8).collect(), counter: c.clone() }
}
fn pad(w: &[i8], c: &Rc<Counter>) -> Vec<i8> {
    c.visits.borrow_mut().push(c.live.get());
    let mut out = vec![0; w.len()+3];
    out[1..w.len()+1].copy_from_slice(w);
    out
}
fn run(mode: usize, bytes: &[Vec<u8>;9]) -> (Vec<Vec<i8>>, Vec<usize>, usize) {
    let c = Rc::new(Counter::default());
    let aw; let fw;
    if mode == 0 {
        aw = [pad(&decode(&bytes[0], &c), &c), pad(&decode(&bytes[1], &c), &c),
              pad(&decode(&bytes[2], &c), &c), pad(&decode(&bytes[3], &c), &c),
              pad(&decode(&bytes[4], &c), &c)];
        assert_eq!(c.live.get(), 0);
        fw = [pad(&decode(&bytes[5], &c), &c), pad(&decode(&bytes[6], &c), &c),
              pad(&decode(&bytes[7], &c), &c), pad(&decode(&bytes[8], &c), &c)];
    } else if mode == 1 {
        let a0 = pad(&decode(&bytes[0], &c), &c);
        let a1 = pad(&decode(&bytes[1], &c), &c);
        let a2 = pad(&decode(&bytes[2], &c), &c);
        let a3 = pad(&decode(&bytes[3], &c), &c);
        let a4 = pad(&decode(&bytes[4], &c), &c);
        aw = [a0,a1,a2,a3,a4];
        let f0 = pad(&decode(&bytes[5], &c), &c);
        let f1 = pad(&decode(&bytes[6], &c), &c);
        let f2 = pad(&decode(&bytes[7], &c), &c);
        let f3 = pad(&decode(&bytes[8], &c), &c);
        fw = [f0,f1,f2,f3];
    } else {
        // Negative: naming REFERENCES extends temporary lifetimes to this block.
        let a0 = &decode(&bytes[0], &c); let a1 = &decode(&bytes[1], &c);
        let a2 = &decode(&bytes[2], &c); let a3 = &decode(&bytes[3], &c);
        let a4 = &decode(&bytes[4], &c);
        aw = [pad(a0,&c),pad(a1,&c),pad(a2,&c),pad(a3,&c),pad(a4,&c)];
        let f0 = &decode(&bytes[5], &c); let f1 = &decode(&bytes[6], &c);
        let f2 = &decode(&bytes[7], &c); let f3 = &decode(&bytes[8], &c);
        fw = [pad(f0,&c),pad(f1,&c),pad(f2,&c),pad(f3,&c)];
    }
    assert_eq!(c.live.get(),0);
    let visits = c.visits.borrow().clone();
    (aw.into_iter().chain(fw).collect(),visits,c.peak.get())
}
fn main() {
    let sizes = [256,64,64,256,16,16,400,400,400];
    let bytes: [Vec<u8>;9] = std::array::from_fn(|i|
        (0..sizes[i]).map(|j| ((j*73+i*19)%256) as u8).collect());
    let b=run(0,&bytes); let a=run(1,&bytes); let bad=run(2,&bytes);
    assert_eq!(b.0,a.0); assert_eq!(b.0,bad.0);
    assert_eq!(b.1,vec![256,320,384,640,656,16,416,816,1216]);
    assert_eq!(a.1,sizes); assert_eq!(b.2,1216); assert_eq!(a.2,400);
    assert!(bad.2 > b.2); assert_ne!(bad.1,a.1);
    println!("{{\"status\":\"PASS\",\"baseline_visits\":{:?},\"candidate_visits\":{:?},\"negative_visits\":{:?},\"baseline_peak_decode_bytes\":{},\"candidate_peak_decode_bytes\":{},\"negative_peak_decode_bytes\":{},\"outputs_equal\":true}}",b.1,a.1,bad.1,b.2,a.2,bad.2);
}
