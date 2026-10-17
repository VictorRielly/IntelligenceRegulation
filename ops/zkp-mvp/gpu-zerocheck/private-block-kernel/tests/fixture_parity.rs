//! Cross-implementation parity against PUBLIC fixtures exported by
//! `hashline/examples/zk60_kernel_fixture.rs` (the canonical oracle).
//!
//! Set `ZK60_KERNEL_FIXTURE=<file>[:<file>...]` and run with `--ignored`;
//! each file holds one or more `zk60-kernel-fixture v1` records. Missing
//! fixtures fail an explicitly requested parity run. Fixture format:
//!
//! ```text
//! zk60-kernel-fixture v1
//! meta <key> <value...>                       (ignored here)
//! status ok | status refused <Range|Relation> <site...>
//! tensor <name> <len> <v_0> ... <v_len-1>
//! end
//! ```
use private_block_kernel::*;
use std::collections::HashMap;

struct Record {
    status: String,
    tensors: HashMap<String, Vec<i64>>,
}

fn parse(text: &str) -> Vec<Record> {
    let mut out = Vec::new();
    let mut cur: Option<Record> = None;
    for (n, line) in text.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let (head, rest) = line.split_once(' ').unwrap_or((line, ""));
        match head {
            "zk60-kernel-fixture" => {
                assert_eq!(rest, "v1", "line {}: unsupported fixture version", n + 1);
                assert!(cur.is_none(), "line {}: unterminated record", n + 1);
                cur = Some(Record { status: String::new(), tensors: HashMap::new() });
            }
            "meta" => {}
            "status" => cur.as_mut().expect("status outside record").status = rest.to_string(),
            "tensor" => {
                let mut it = rest.split_ascii_whitespace();
                let name = it.next().expect("tensor name").to_string();
                let len: usize = it.next().expect("tensor len").parse().expect("tensor len");
                let vals: Vec<i64> = it.map(|v| v.parse().expect("tensor value")).collect();
                assert_eq!(vals.len(), len, "line {}: tensor {name} length", n + 1);
                let rec = cur.as_mut().expect("tensor outside record");
                assert!(rec.tensors.insert(name, vals).is_none(), "line {}: duplicate tensor", n + 1);
            }
            "end" => out.push(cur.take().expect("end outside record")),
            other => panic!("line {}: unknown item {other}", n + 1),
        }
    }
    assert!(cur.is_none(), "unterminated final record");
    out
}

fn get<'a>(r: &'a Record, name: &str) -> &'a [i64] {
    r.tensors.get(name).unwrap_or_else(|| panic!("missing tensor {name}"))
}
fn i8s(r: &Record, name: &str) -> Vec<i8> {
    get(r, name).iter().map(|v| i8::try_from(*v).expect("i8 word")).collect()
}
fn i16s(r: &Record, name: &str) -> Vec<i16> {
    get(r, name).iter().map(|v| i16::try_from(*v).expect("i16 word")).collect()
}

fn check(r: &Record, idx: usize) {
    let w = PublicWeights::from_slices(
        &i8s(r, "wq"),
        &i8s(r, "wk"),
        &i8s(r, "wv"),
        &i8s(r, "wo"),
        &i8s(r, "gamma_a"),
        &i8s(r, "gamma_m"),
        &i8s(r, "wg_t"),
        &i8s(r, "wu_t"),
        &i8s(r, "wd_t"),
    )
    .expect("fixture weights");
    let tab = PublicTables::from_slices(get(r, "rope_cos"), get(r, "rope_sin"), get(r, "exp"), &i16s(r, "act"))
        .expect("fixture tables");
    let input = i16s(r, "input");
    let mut tr = Box::new(Trace::zeroed());
    let got = run_block_slice(&input, &w, &tab, Some(&mut *tr));
    if r.status == "ok" {
        let out = got.unwrap_or_else(|e| panic!("record {idx}: kernel refused ({e}) but oracle accepted"));
        let planes: [(&str, &[i64]); 23] = [
            ("na_dd", &tr.na_dd),
            ("na_y", &tr.na_y),
            ("q8", &tr.q8),
            ("k8", &tr.k8),
            ("v8", &tr.v8),
            ("qr8", &tr.qr8),
            ("kr8", &tr.kr8),
            ("s8", &tr.s8),
            ("m_row", &tr.m_row),
            ("arg", &tr.arg),
            ("sum", &tr.sum),
            ("p", &tr.p),
            ("o8", &tr.o8),
            ("ao8", &tr.ao8),
            ("xres1", &tr.xres1),
            ("nm_dd", &tr.nm_dd),
            ("nm_y", &tr.nm_y),
            ("g8", &tr.g8),
            ("a16", &tr.a16),
            ("u16", &tr.u16),
            ("h16", &tr.h16),
            ("z16", &tr.z16),
            ("xres2", &tr.xres2),
        ];
        for (name, mine) in planes {
            let theirs = get(r, name);
            let bad = mine.iter().zip(theirs).filter(|(a, b)| a != b).count();
            // Report counts only, not values.
            assert!(mine.len() == theirs.len() && bad == 0, "record {idx}: plane {name} differs in {bad} elements");
        }
        assert!(out.iter().zip(get(r, "xres2")).all(|(a, b)| i64::from(*a) == *b));
    } else {
        let want = r.status.strip_prefix("refused ").unwrap_or_else(|| panic!("record {idx}: bad status"));
        let e = got.err().unwrap_or_else(|| panic!("record {idx}: oracle refused ({want}) but kernel accepted"));
        let mine = match e {
            KernelError::Range(s) => format!("Range {s}"),
            KernelError::Relation(s) => format!("Relation {s}"),
            other => panic!("record {idx}: kernel-only refusal {other}"),
        };
        assert_eq!(mine, want, "record {idx}: refusal site");
    }
}

#[test]
#[ignore = "requires canonical exported fixtures; run with ZK60_KERNEL_FIXTURE and --ignored"]
fn oracle_fixture_parity() {
    let paths = std::env::var("ZK60_KERNEL_FIXTURE").expect("canonical fixture paths required");
    let mut n = 0;
    for path in paths.split(':').filter(|p| !p.is_empty()) {
        let text = std::fs::read_to_string(path).unwrap_or_else(|e| panic!("read {path}: {e}"));
        for rec in parse(&text) {
            check(&rec, n);
            n += 1;
        }
    }
    assert!(n > 0, "ZK60_KERNEL_FIXTURE named no records");
    eprintln!("oracle parity: {n} PUBLIC fixture records matched");
}
