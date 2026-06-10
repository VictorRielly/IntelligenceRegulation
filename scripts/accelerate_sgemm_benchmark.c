#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

static double now_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

static void fill_matrix(float *matrix, int n, float scale) {
    for (int i = 0; i < n * n; i++) {
        matrix[i] = (float)(((i * 1315423911u) ^ (i >> 3)) & 1023) * scale;
    }
}

static double time_sgemm(int n, double target_seconds, int *used_reps) {
    float *a = NULL;
    float *b = NULL;
    float *c = NULL;
    if (posix_memalign((void **)&a, 64, (size_t)n * (size_t)n * sizeof(float)) != 0 ||
        posix_memalign((void **)&b, 64, (size_t)n * (size_t)n * sizeof(float)) != 0 ||
        posix_memalign((void **)&c, 64, (size_t)n * (size_t)n * sizeof(float)) != 0) {
        fprintf(stderr, "allocation failed for n=%d\n", n);
        exit(2);
    }

    fill_matrix(a, n, 1.0f / 1024.0f);
    fill_matrix(b, n, 1.0f / 2048.0f);
    fill_matrix(c, n, 0.0f);

    cblas_sgemm(
        CblasRowMajor, CblasNoTrans, CblasNoTrans,
        n, n, n,
        1.0f, a, n, b, n,
        0.0f, c, n
    );

    int reps = 1;
    double best = 1.0e300;
    volatile float sink = 0.0f;

    for (int trial = 0; trial < 5; trial++) {
        double elapsed = 0.0;
        while (1) {
            double start = now_seconds();
            for (int r = 0; r < reps; r++) {
                cblas_sgemm(
                    CblasRowMajor, CblasNoTrans, CblasNoTrans,
                    n, n, n,
                    1.0f, a, n, b, n,
                    0.0f, c, n
                );
            }
            elapsed = now_seconds() - start;
            if (elapsed >= target_seconds || reps >= 1000000) {
                break;
            }
            double factor = target_seconds / (elapsed > 1e-12 ? elapsed : 1e-12);
            reps = (int)ceil((double)reps * factor * 1.1);
            if (reps < 1) {
                reps = 1;
            }
        }
        double average = elapsed / (double)reps;
        if (average < best) {
            best = average;
            *used_reps = reps;
        }
        sink += c[(size_t)(trial % n) * (size_t)n + (size_t)(trial % n)];
    }

    if (sink == -1.0f) {
        fprintf(stderr, "impossible sink value\n");
    }

    free(a);
    free(b);
    free(c);
    return best;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "usage: %s n [n...]\n", argv[0]);
        return 1;
    }

    const double target_seconds = 0.05;
    printf("n,sgemm_s,gflops,reps\n");
    for (int i = 1; i < argc; i++) {
        int n = atoi(argv[i]);
        if (n <= 0) {
            fprintf(stderr, "invalid n: %s\n", argv[i]);
            return 1;
        }
        int reps = 1;
        double seconds = time_sgemm(n, target_seconds, &reps);
        double gflops = (2.0 * (double)n * (double)n * (double)n) / seconds / 1e9;
        printf("%d,%.12f,%.3f,%d\n", n, seconds, gflops, reps);
    }
    return 0;
}
