use super::*;
use std::process::{Child, Command, Stdio};
use std::sync::{Arc, Barrier};
use std::time::Duration;

struct TestDir(PathBuf);
impl TestDir {
    fn new(label: &str) -> Self {
        let p =
            std::env::temp_dir().join(format!("hl-wcache-atomic-{}-{label}", std::process::id()));
        std::fs::create_dir(&p).unwrap();
        Self(p)
    }
}
impl Drop for TestDir {
    fn drop(&mut self) {
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn tree_fixture() -> (PcsParams, MerkleTree) {
    let params = PcsParams {
        log_cols: 12,
        inv_rate: 4,
        num_col_checks: 8,
    };
    let leaves = (0..params.enc_cols())
        .map(|i| *blake3::hash(&(i as u64).to_le_bytes()).as_bytes())
        .collect();
    (params, MerkleTree::build(leaves))
}

#[test]
fn concurrent_same_key_saves_all_publish_complete_entries() {
    let dir = TestDir::new("threads");
    let path = Arc::new(dir.0.join("shared.wc"));
    let (params, tree) = tree_fixture();
    let tree = Arc::new(tree);
    let key = [17; 32];
    let expected_bytes = save_tree(&path, &key, &params, 1, &tree).unwrap();
    let start = Arc::new(Barrier::new(8));
    let workers: Vec<_> = (0..8)
        .map(|_| {
            let (path, tree, start) = (path.clone(), tree.clone(), start.clone());
            std::thread::spawn(move || {
                let mut outcomes = Vec::new();
                for _ in 0..12 {
                    start.wait();
                    outcomes.push(save_tree(&path, &key, &params, 1, &tree));
                }
                outcomes
            })
        })
        .collect();
    let mut lost = Vec::new();
    for worker in workers {
        for result in worker.join().unwrap() {
            match result {
                Ok(bytes) => assert_eq!(bytes, expected_bytes),
                Err(error) => lost.push(error.to_string()),
            }
        }
    }
    assert!(
        lost.is_empty(),
        "same-key writers lost {} of 96 saves: {lost:?}",
        lost.len()
    );
    let (loaded, bytes) = load_tree(&path, &key, &params, 1).unwrap();
    assert_eq!(loaded.levels, tree.levels);
    assert_eq!(bytes, expected_bytes);
    assert_eq!(
        std::fs::read_dir(&dir.0).unwrap().count(),
        1,
        "no temporary files remain"
    );
}

#[test]
fn readers_keep_complete_entries_while_other_writers_are_partial() {
    let dir = TestDir::new("reader");
    let destination = dir.0.join("shared.wc");
    let (params, tree) = tree_fixture();
    let key = [18; 32];
    save_tree(&destination, &key, &params, 1, &tree).unwrap();
    let bytes = std::fs::read(&destination).unwrap();
    let mut first = PendingEntry::create(&destination).unwrap();
    let mut second = PendingEntry::create(&destination).unwrap();
    assert_ne!(first.path, second.path);
    first.file.as_mut().unwrap().write_all(&bytes).unwrap();
    second
        .file
        .as_mut()
        .unwrap()
        .write_all(&bytes[..17])
        .unwrap();
    let released_name = first.path.clone();
    first.publish(&destination).unwrap();
    // A writer in another PID namespace can now reserve this released name.
    std::fs::write(&released_name, b"new owner").unwrap();
    drop(first);
    assert_eq!(std::fs::read(&released_name).unwrap(), b"new owner");
    std::fs::remove_file(released_name).unwrap();
    // Publishing the first writer must not publish the second writer's
    // partial inode. Keep a reader open across the next atomic replacement.
    let mut reader = std::fs::File::open(&destination).unwrap();
    assert_eq!(
        load_tree(&destination, &key, &params, 1).unwrap().0.levels,
        tree.levels
    );
    second
        .file
        .as_mut()
        .unwrap()
        .write_all(&bytes[17..])
        .unwrap();
    second.publish(&destination).unwrap();
    let mut observed = Vec::new();
    std::io::Read::read_to_end(&mut reader, &mut observed).unwrap();
    assert_eq!(observed, bytes);
    assert_eq!(std::fs::read(&destination).unwrap(), bytes);
    assert_eq!(std::fs::read_dir(&dir.0).unwrap().count(), 1);
}

#[test]
fn unfinished_and_failed_publications_clean_up_only_their_own_files() {
    let dir = TestDir::new("cleanup");
    let destination = dir.0.join("shared.wc");
    std::fs::write(&destination, b"existing entry").unwrap();
    let foreign = dir.0.join("unrelated.wc.tmp");
    std::fs::write(&foreign, b"another writer").unwrap();
    let mut pending = PendingEntry::create(&destination).unwrap();
    let path = pending.path.clone();
    pending
        .file
        .as_mut()
        .unwrap()
        .write_all(b"partial")
        .unwrap();
    drop(pending); // write error or unwind before publication
    assert!(!path.exists());
    assert_eq!(std::fs::read(&destination).unwrap(), b"existing entry");
    let blocked = dir.0.join("directory.wc");
    std::fs::create_dir(&blocked).unwrap();
    std::fs::write(blocked.join("keep"), b"keep").unwrap();
    let (params, tree) = tree_fixture();
    assert!(save_tree(&blocked, &[19; 32], &params, 1, &tree).is_err());
    assert_eq!(std::fs::read(blocked.join("keep")).unwrap(), b"keep");
    assert_eq!(std::fs::read(&foreign).unwrap(), b"another writer");
    assert_eq!(std::fs::read_dir(&dir.0).unwrap().count(), 3);
}

struct Children(Vec<Child>);
impl Drop for Children {
    fn drop(&mut self) {
        for child in &mut self.0 {
            if child.try_wait().ok().flatten().is_none() {
                let _ = child.kill();
            }
            let _ = child.wait();
        }
    }
}

fn wait_until(mut ready: impl FnMut() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(30);
    while !ready() {
        assert!(
            Instant::now() < deadline,
            "cache writer subprocess timed out"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
}

#[test]
fn concurrent_processes_publish_without_lost_saves_or_partial_reads() {
    const CHILD_DIR: &str = "HL_WCACHE_ATOMIC_CHILD_DIR";
    let (params, tree) = tree_fixture();
    let key = [20; 32];
    if let Some(dir) = std::env::var_os(CHILD_DIR) {
        let dir = PathBuf::from(dir);
        std::fs::write(dir.join(format!("ready-{}", std::process::id())), b"ready").unwrap();
        wait_until(|| dir.join("go").exists());
        // A crashed process whose PID was reused may leave this name behind.
        // The first reservation must skip it without opening or truncating it.
        let stale = dir.join(format!("shared.wc.tmp.{}.0", std::process::id()));
        std::fs::write(&stale, b"stale writer's bytes").unwrap();
        for _ in 0..24 {
            save_tree(&dir.join("shared.wc"), &key, &params, 1, &tree).unwrap();
        }
        assert_eq!(std::fs::read(&stale).unwrap(), b"stale writer's bytes");
        std::fs::remove_file(stale).unwrap();
        return;
    }
    let dir = TestDir::new("processes");
    let path = dir.0.join("shared.wc");
    let bytes = save_tree(&path, &key, &params, 1, &tree).unwrap();
    let mut children = Children(Vec::new());
    for _ in 0..4 {
        let log =
            std::fs::File::create(dir.0.join(format!("child-{}.log", children.0.len()))).unwrap();
        children.0.push(Command::new(std::env::current_exe().unwrap())
            .args(["--exact", "wcache::atomic_tests::concurrent_processes_publish_without_lost_saves_or_partial_reads", "--nocapture", "--test-threads=1"])
            .env(CHILD_DIR, &dir.0).env("RAYON_NUM_THREADS", "2")
            .stdout(Stdio::from(log.try_clone().unwrap())).stderr(Stdio::from(log))
            .spawn().unwrap());
    }
    wait_until(|| {
        children
            .0
            .iter()
            .all(|c| dir.0.join(format!("ready-{}", c.id())).exists())
    });
    std::fs::write(dir.0.join("go"), b"go").unwrap();
    let mut reads = 0;
    wait_until(|| {
        let (loaded, nbytes) = load_tree(&path, &key, &params, 1).unwrap();
        assert_eq!(loaded.levels, tree.levels);
        assert_eq!(nbytes, bytes);
        reads += 1;
        children
            .0
            .iter_mut()
            .all(|c| c.try_wait().unwrap().is_some())
    });
    assert!(reads > 0);
    for (i, child) in children.0.iter_mut().enumerate() {
        let log = std::fs::read_to_string(dir.0.join(format!("child-{i}.log"))).unwrap();
        assert!(child.wait().unwrap().success(), "{log}");
        assert!(log.contains("1 passed; 0 failed; 0 ignored"), "{log}");
    }
    assert!(std::fs::read_dir(&dir.0).unwrap().all(|e| !e
        .unwrap()
        .file_name()
        .to_string_lossy()
        .contains(".tmp")));
}
