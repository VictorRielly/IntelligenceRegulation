/* Lane A26: a FIXED-TEST-ENTROPY harness for macOS (the Mac has no bubblewrap, so A24 could not run
 * r18/tools/run_fixed.sh). Loaded with DYLD_INSERT_LIBRARIES into a zk60_classify process, it
 * interposes open(2): a process that opens "/dev/urandom" gets, instead, a read-only descriptor on
 * the file named by A26_FIXED_ENTROPY_FILE (every open starts at its first byte, as each
 * `ZkRng::from_os` reads 32 bytes from a fresh open). Every other path is opened as asked.
 *
 * TEST ONLY, PUBLIC CONTENT ONLY: under it every "fresh" draw of the prover is the same public
 * bytes, so its receipts hide nothing. It exists so that two binaries can be run on the same
 * inputs and the same draws and their receipts compared byte for byte. Never in the app.
 *
 * Build (outside the repository): cc -dynamiclib -O2 -o <dir>/a26_fixed_entropy.dylib fixed_entropy.c
 */
#include <fcntl.h>
#include <stdarg.h>
#include <stdlib.h>
#include <string.h>

static int a26_open(const char *path, int flags, ...) {
    int mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, int);
        va_end(ap);
    }
    if (path && strcmp(path, "/dev/urandom") == 0) {
        const char *f = getenv("A26_FIXED_ENTROPY_FILE");
        if (f && *f) {
            return open(f, O_RDONLY | O_CLOEXEC);
        }
    }
    return open(path, flags, mode);
}

__attribute__((used)) static const struct {
    const void *replacement;
    const void *replacee;
} a26_interposers[] __attribute__((section("__DATA,__interpose"))) = {
    {(const void *)a26_open, (const void *)open},
};
