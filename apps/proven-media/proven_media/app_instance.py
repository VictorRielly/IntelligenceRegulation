"""One app instance per private store; kernel-owned lock, never a PID marker."""
import fcntl
import os
from pathlib import Path
import stat

from proven_media.provers import ProverError


class AppInstanceLock:
    def __init__(self, private):
        self.fd=None
        path=Path(private)/'app-instance.lock'
        fd=os.open(path,os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW|os.O_NONBLOCK,0o600)
        try:
            value=os.fstat(fd)
            if not stat.S_ISREG(value.st_mode) or value.st_uid!=os.getuid() or value.st_mode & 0o077:
                raise ProverError('The app instance lock must be an owner-only regular file.')
            try:fcntl.flock(fd,fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError as exc:
                raise ProverError('Another app instance already owns this private store.') from exc
            os.set_inheritable(fd,False)
            self.fd=fd
        except BaseException:
            os.close(fd)
            raise

    def close(self):
        if self.fd is not None:
            os.close(self.fd);self.fd=None
        # Never unlink: a replacement inode would permit two lock owners.
