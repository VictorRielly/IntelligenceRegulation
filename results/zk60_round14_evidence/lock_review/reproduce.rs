use std::fs::OpenOptions;
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::os::unix::net::UnixStream;
use std::os::unix::process::CommandExt;
use std::process::Command;
use std::time::Duration;

unsafe extern "C" {
    fn read(fd: i32, buf: *mut u8, count: usize) -> isize;
    fn write(fd: i32, buf: *const u8, count: usize) -> isize;
    fn alarm(seconds: u32) -> u32;
}

// Always release the controlled child, including on an assertion panic.
struct Release(UnixStream);
impl Drop for Release {
    fn drop(&mut self) { let _ = self.0.write_all(&[1]); }
}

fn reproduce(explicit_unlock: bool) -> bool {
    let path = std::env::temp_dir().join(format!("zk60-fork-lock-{}-{explicit_unlock}", std::process::id()));
    let file = OpenOptions::new().read(true).write(true).create_new(true).open(&path).unwrap();
    file.try_lock().unwrap();
    let second = OpenOptions::new().read(true).write(true).open(&path).unwrap();
    assert!(second.try_lock().is_err());
    drop(second);
    let (mut parent, child) = UnixStream::pair().unwrap();
    parent.set_read_timeout(Some(Duration::from_secs(10))).unwrap();
    let release = Release(parent.try_clone().unwrap());
    let thread = std::thread::spawn(move || {
        let fd = child.as_raw_fd();
        let mut cmd = Command::new("/bin/true");
        // Only async-signal-safe syscalls run between fork and exec. Alarm
        // bounds even an unexpected failure of the parent release path.
        unsafe {
            cmd.pre_exec(move || {
                alarm(10);
                let mut byte = 1u8;
                if write(fd, &byte, 1) != 1 || read(fd, &mut byte, 1) != 1 {
                    return Err(std::io::Error::from_raw_os_error(5));
                }
                alarm(0);
                Ok(())
            });
        }
        let mut process = cmd.spawn().unwrap();
        assert!(process.wait().unwrap().success());
    });
    parent.read_exact(&mut [0u8]).unwrap();
    if explicit_unlock { file.unlock().unwrap(); }
    drop(file);
    let reopened = OpenOptions::new().read(true).write(true).open(&path).unwrap();
    let success = reopened.try_lock().is_ok();
    if success { reopened.unlock().unwrap(); }
    drop(reopened);
    drop(release);
    thread.join().unwrap();
    let final_open = OpenOptions::new().read(true).write(true).open(&path).unwrap();
    final_open.try_lock().unwrap();
    final_open.unlock().unwrap();
    drop(final_open);
    std::fs::remove_file(path).unwrap();
    success
}

fn main() {
    let close_only = reproduce(false);
    let explicit = reproduce(true);
    println!("CLOSE_ONLY_REOPEN_WHILE_CHILD_PREEXEC={close_only}");
    println!("EXPLICIT_UNLOCK_REOPEN_WHILE_CHILD_PREEXEC={explicit}");
    assert!(!close_only && explicit);
}
