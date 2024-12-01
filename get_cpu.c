#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <sched.h>

int main() {
    int cpu = sched_getcpu();
    printf("%d\n", cpu);
    return 0;
}

