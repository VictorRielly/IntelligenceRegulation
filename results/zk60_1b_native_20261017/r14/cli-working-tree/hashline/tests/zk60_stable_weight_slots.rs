//! Real process lifetime/locking checks for the public slot journal, not P3 proofs.
use hashline::field::Fp;
use hashline::pcs::{Commitment, PcsParams, ZkOpts};
use hashline::stable_weight_slots::{SlotError, SlotJournal, SlotPolicy, StableWeightBinding};
use std::io::Read;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

fn policy() -> SlotPolicy {
    SlotPolicy::new(StableWeightBinding {
        manifest: [11; 32],
        layer: 0,
        layout: [12; 32],
        commitment: Commitment {
            root: [13; 32],
            rows: 12,
            log_cols: 4,
        },
        params: PcsParams {
            log_cols: 4,
            inv_rate: 4,
            num_col_checks: 4,
        },
        opts: ZkOpts {
            q_pad: 32,
            coset: Fp::new(7),
        },
        budget: 8,
    })
    .unwrap()
}
struct Scratch(PathBuf);
impl Scratch {
    fn new() -> Self {
        let stamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let path =
            std::env::temp_dir().join(format!("zk60-slot-process-{}-{stamp}", std::process::id()));
        std::fs::create_dir(&path).unwrap();
        Self(path)
    }
    fn journal(&self) -> PathBuf {
        self.0.join("journal")
    }
}
impl Drop for Scratch {
    fn drop(&mut self) {
        std::fs::remove_dir_all(&self.0).unwrap();
    }
}
// Kill/wait our own child even if a parent assertion fails, so no lock holder
// or blocked stdin reader survives a failed test.
struct Client(Child);
impl Drop for Client {
    fn drop(&mut self) {
        let _ = self.0.kill();
        let _ = self.0.wait();
    }
}
fn client(path: &Path, mode: &str) -> Client {
    Client(
        Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "slot_client_process",
                "--nocapture",
                "--test-threads=1",
            ])
            .env("HL_TEST_SLOT_PATH", path)
            .env("HL_TEST_SLOT_MODE", mode)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .unwrap(),
    )
}
fn wait(client: &mut Client) -> (std::process::ExitStatus, String) {
    let start = Instant::now();
    loop {
        if let Some(status) = client.0.try_wait().unwrap() {
            let mut output = String::new();
            client
                .0
                .stdout
                .take()
                .unwrap()
                .read_to_string(&mut output)
                .unwrap();
            client
                .0
                .stderr
                .take()
                .unwrap()
                .read_to_string(&mut output)
                .unwrap();
            return (status, output);
        }
        assert!(
            start.elapsed() < Duration::from_secs(20),
            "slot client timed out"
        );
        std::thread::sleep(Duration::from_millis(10));
    }
}

#[test]
fn slot_client_process() {
    let Some(path) = std::env::var_os("HL_TEST_SLOT_PATH") else {
        return;
    };
    let mode = std::env::var("HL_TEST_SLOT_MODE").unwrap();
    let path = PathBuf::from(path);
    if mode == "busy" {
        assert!(matches!(
            SlotJournal::open(&path, policy()),
            Err(SlotError::Busy)
        ));
        return;
    }
    let start = Instant::now();
    let mut journal = loop {
        match SlotJournal::open(&path, policy()) {
            Ok(j) => break j,
            Err(SlotError::Busy) if start.elapsed() < Duration::from_secs(10) => {
                std::thread::sleep(Duration::from_millis(10))
            }
            Err(e) => panic!("slot client failed: {e}"),
        }
    };
    let slot = journal.reserve().unwrap();
    println!("RESERVED_SLOT={}", slot.index());
    if mode == "hold" {
        // This marker comes after sync and token return. Killing this process
        // exercises lock release and restart with a spent, uncompleted attempt.
        std::fs::write(path.with_extension("ready"), slot.index().to_string()).unwrap();
        let mut input = String::new();
        std::io::stdin().read_to_string(&mut input).unwrap();
    }
}

#[test]
fn process_death_releases_lock_without_refunding_the_slot() {
    let scratch = Scratch::new();
    let path = scratch.journal();
    drop(SlotJournal::create(&path, policy()).unwrap());
    let mut holder = client(&path, "hold");
    let start = Instant::now();
    while !path.with_extension("ready").exists() {
        assert!(
            holder.0.try_wait().unwrap().is_none(),
            "holder died before reservation"
        );
        assert!(
            start.elapsed() < Duration::from_secs(20),
            "holder did not reserve"
        );
        std::thread::sleep(Duration::from_millis(10));
    }
    assert_eq!(
        std::fs::read_to_string(path.with_extension("ready")).unwrap(),
        "0"
    );
    let (status, output) = wait(&mut client(&path, "busy"));
    assert!(status.success(), "{output}");
    holder.0.kill().unwrap();
    assert!(!holder.0.wait().unwrap().success());
    let mut recovered = SlotJournal::open(&path, policy()).unwrap();
    assert_eq!(recovered.used(), 1);
    assert_eq!(recovered.reserve().unwrap().index(), 1);
}

#[test]
fn competing_processes_reserve_each_slot_once() {
    let scratch = Scratch::new();
    let path = scratch.journal();
    drop(SlotJournal::create(&path, policy()).unwrap());
    let mut slots = Vec::new();
    // Two clients at a time respect the shared box's concurrency budget.
    for _ in 0..4 {
        let mut clients = [client(&path, "reserve"), client(&path, "reserve")];
        for process in &mut clients {
            let (status, output) = wait(process);
            assert!(status.success(), "{output}");
            let marker = output.find("RESERVED_SLOT=").expect(&output);
            let value = output[marker + "RESERVED_SLOT=".len()..]
                .split_whitespace()
                .next()
                .unwrap();
            slots.push(value.parse::<u32>().unwrap());
        }
    }
    slots.sort_unstable();
    assert_eq!(slots, (0..8).collect::<Vec<_>>());
    let mut journal = SlotJournal::open(&path, policy()).unwrap();
    assert_eq!(journal.used(), 8);
    assert!(matches!(journal.reserve(), Err(SlotError::Exhausted)));
}
