// LD_PRELOAD shim for bench/stall: logs every fsync/fdatasync the app makes (wall-clock start,
// duration, file) to $IOTRACE_FILE, so slow requests can be matched against durability syscalls.
//
//   cc -O2 -shared -fPIC -o iotrace.so bench/lib/iotrace.c -ldl
#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

static int log_fd = -2;

static long long now_us(void) {
  struct timespec ts;
  clock_gettime(CLOCK_REALTIME, &ts);
  return (long long)ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
}

static void record(const char *what, int fd, long long t0, long long t1) {
  if (log_fd == -2) {
    const char *path = getenv("IOTRACE_FILE");
    log_fd = path ? open(path, O_WRONLY | O_CREAT | O_APPEND | O_CLOEXEC, 0644) : -1;
  }
  if (log_fd < 0) return;
  char link[64], target[512] = "?";
  snprintf(link, sizeof link, "/proc/self/fd/%d", fd);
  ssize_t n = readlink(link, target, sizeof target - 1);
  if (n > 0) target[n] = 0;
  char line[700];
  int len = snprintf(line, sizeof line, "%lld %lld %s %s\n", t0, t1 - t0, what, target);
  if (len > 0) write(log_fd, line, len);
}

#define WRAP(name)                                              \
  int name(int fd) {                                            \
    static int (*real)(int);                                    \
    if (!real) real = (int (*)(int))dlsym(RTLD_NEXT, #name);    \
    long long t0 = now_us();                                    \
    int r = real(fd);                                           \
    record(#name, fd, t0, now_us());                            \
    return r;                                                   \
  }

WRAP(fsync)
WRAP(fdatasync)
