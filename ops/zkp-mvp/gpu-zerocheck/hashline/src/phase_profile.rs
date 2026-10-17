//! Opt-in, thread-local CPU wall attribution. Labels are fixed source strings;
//! values, tensor digests, dimensions inferred from values, and device counters
//! are never collected. Timings themselves may expose private-data properties.
//! Measure blocking Rayon calls on their calling thread, not worker CPU sums.

use std::cell::RefCell;
use std::collections::BTreeMap;
use std::marker::PhantomData;
use std::rc::Rc;
use std::time::{Duration, Instant};

#[derive(Default)]
struct State {
    stack: Vec<(&'static str, Duration)>,
    phases: BTreeMap<&'static str, (Duration, usize)>,
}
thread_local! { static STATE: RefCell<Option<State>> = const { RefCell::new(None) }; }

pub struct Capture {
    active: bool,
    _thread_local: PhantomData<Rc<()>>,
}

#[derive(Debug)]
pub struct Phase {
    pub name: &'static str,
    pub seconds: f64,
    pub calls: usize,
}

impl Capture {
    pub fn begin(enabled: bool) -> Self {
        if enabled {
            STATE.with(|state| {
                let mut state = state.borrow_mut();
                assert!(state.is_none(), "nested profiling captures are unsupported");
                *state = Some(State::default());
            });
        }
        Self { active: enabled, _thread_local: PhantomData }
    }

    pub fn finish(mut self) -> Option<Vec<Phase>> {
        if !self.active { return None; }
        let state = STATE.with(|state| state.borrow_mut().take().unwrap());
        self.active = false;
        assert!(state.stack.is_empty(), "unclosed profiling scope");
        Some(state.phases.into_iter().map(|(name, (elapsed, calls))|
            Phase { name, seconds: elapsed.as_secs_f64(), calls }).collect())
    }
}

impl Drop for Capture {
    fn drop(&mut self) {
        if self.active { STATE.with(|state| { state.borrow_mut().take(); }); }
    }
}

pub struct Span {
    start: Option<(Instant, &'static str)>,
    _thread_local: PhantomData<Rc<()>>,
}

pub fn span(name: &'static str) -> Span {
    let start = STATE.with(|state| {
        let mut state = state.borrow_mut();
        state.as_mut().map(|state| {
            let start = Instant::now();
            state.stack.push((name, Duration::ZERO));
            (start, name)
        })
    });
    Span { start, _thread_local: PhantomData }
}

impl Drop for Span {
    fn drop(&mut self) {
        if let Some((start, name)) = self.start {
            let elapsed = start.elapsed();
            STATE.with(|state| {
                let mut state = state.borrow_mut();
                let state = state.as_mut().expect("profiling capture ended before scope");
                let (expected, children) = state.stack.pop().unwrap();
                assert_eq!(name, expected, "profiling scopes closed out of order");
                let exclusive = elapsed.checked_sub(children).expect("overlapping profiling scopes");
                let entry = state.phases.entry(name).or_default();
                entry.0 += exclusive;
                entry.1 += 1;
                if let Some(parent) = state.stack.last_mut() { parent.1 += elapsed; }
            });
        }
    }
}

#[inline]
pub fn measure<T>(name: &'static str, f: impl FnOnce() -> T) -> T {
    let _scope = span(name);
    f()
}

fn quoted(value: &str) -> String {
    let mut out = String::from("\"");
    for c in value.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if c < ' ' => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

/// Only fixed phase labels and durations are emitted. Prover lap intervals are
/// sequential host wall intervals; nested GPU/event counters are excluded.
#[allow(clippy::too_many_arguments)]
pub fn report(phases: Option<Vec<Phase>>, privacy: &str, layer: usize, tokens: usize,
              d: usize, f: usize, witness_s: f64, prove_s: f64, prover: &[(String, f64)]) {
    let Some(phases) = phases else { return; };
    let witness = phases.iter().map(|p| format!("{{\"phase\":{},\"seconds\":{:.9},\"calls\":{}}}", quoted(p.name), p.seconds, p.calls)).collect::<Vec<_>>().join(",");
    let prover = prover.iter().map(|(name, seconds)| format!("{{\"phase\":{},\"seconds\":{:.9}}}", quoted(name), seconds)).collect::<Vec<_>>().join(",");
    println!(concat!("HASHLINE_PROFILE {{\"schema\":1,\"coverage\":\"ffn-only\",\"privacy\":{},",
        "\"layer\":{},\"tokens\":{},\"d\":{},\"f\":{},\"witness_s\":{:.9},\"prove_s\":{:.9},",
        "\"witness_exclusive\":[{}],\"prover_sequential\":[{}],",
        "\"device_counters_included\":false,\"private_timing_diagnostics\":true}}"),
        quoted(privacy), layer, tokens, d, f, witness_s, prove_s, witness, prover);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn disabled_profiling_preserves_result_and_records_nothing() {
        let capture = Capture::begin(false);
        assert_eq!(measure("fixed", || vec![1, 2, 3]), [1, 2, 3]);
        assert!(capture.finish().is_none());
    }

    #[test]
    fn nested_profile_costs_are_exclusive() {
        let capture = Capture::begin(true);
        let start = Instant::now();
        measure("outer", || {
            for _ in 0..2 {
                measure("inner", || { for i in 0..1000 { std::hint::black_box(i * 2); } });
            }
        });
        let elapsed = start.elapsed().as_secs_f64();
        let phases = capture.finish().unwrap();
        assert_eq!(phases.len(), 2);
        assert_eq!(phases.iter().find(|p| p.name == "inner").unwrap().calls, 2);
        assert!(phases.iter().map(|p| p.seconds).sum::<f64>() <= elapsed);
        assert!(phases.iter().all(|p| p.seconds >= 0.0));
    }

    #[test]
    fn profile_capture_cleans_up_after_unwind() {
        assert!(std::panic::catch_unwind(|| {
            let _capture = Capture::begin(true);
            measure("fixed", || panic!("fixture"));
        }).is_err());
        assert!(Capture::begin(true).finish().unwrap().is_empty());
        assert_eq!(quoted("a\n\"\\"), "\"a\\u000a\\\"\\\\\"");
    }
}
