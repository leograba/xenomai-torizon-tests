#!/bin/bash

### VARIABLES ###
XENOMAI_VERSION="v3.2.6"
GRAPHICS_TESTS_VERSION="stable-rc"
GRAPHICS_CARD="card1-HDMI-A-1"
CLOCKTEST_SWITCHTEST_DURATION=60

### CODE ###

# Welcome
printf "#---- Xenomai 3 Test Report ----#\n\n"

# Print system info
# Inspired by tdx-info
printf "Kernel version: %s\n" "$(uname -rv)"
printf "Kernel command line: %s\n\n" "$(cat /proc/cmdline)"
printf "Distro name: %s\n" "$(grep ^NAME /etc/os-release)"
printf "Distro version: %s\n" "$(grep VERSION_ID /etc/os-release)"
printf "Distro variant: %s\n\n" "$(grep VARIANT /etc/os-release)"
printf "Hostname: %s\n\n" "$(cat /etc/hostname)"

# Print the display connector state
printf "Display ${GRAPHICS_CARD} connector state is: %s\n\n" \
       "$(cat /sys/class/drm/${GRAPHICS_CARD}/status)"

# Setup before start
printf "Stopping all containers before starting\n\n"
if [[ $(docker ps --all --quiet) ]]; then
    # shellcheck disable=SC2046
    docker stop $(docker ps --all --quiet)
fi
if [[ $(docker ps --all --quiet) ]]; then
    # shellcheck disable=SC2046
    docker rm $(docker ps --all --quiet)
fi

printf "Pulling the latest version of containers\n\n"
docker pull --quiet leograba/xeno3:${XENOMAI_VERSION}
#docker pull --quiet leograba/weston:rc
docker pull --quiet torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

printf "Starting containers in the background\n\n"
# Start Weston container
#docker run --name weston -d --rm --net=host --cap-add CAP_SYS_TTY_CONFIG \
#        -v /dev:/dev -v /tmp:/tmp -v /run/udev/:/run/udev/ \
#        --device-cgroup-rule='c 4:* rmw' --device-cgroup-rule='c 13:* rmw' \
#        --device-cgroup-rule='c 226:* rmw' \
#        leograba/weston:rc --developer --tty=/dev/tty7

# Start graphics-tests container
docker run --name graphics-tests -dt --rm  \
        -v /dev:/dev --device-cgroup-rule="c 4:* rmw"  \
        --device-cgroup-rule="c 13:* rmw" --device-cgroup-rule="c 199:* rmw" \
        --device-cgroup-rule="c 226:* rmw" \
        torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

# Start container with Xenomai 3 userspace tools
docker run --name xenomai --privileged --rm -d -v /dev:/dev \
        leograba/xeno3:${XENOMAI_VERSION} sleep infinity

printf "Containers started!\n\n"

# Run kmscube
docker exec -dt graphics-tests kmscube
printf "kmscube running\n\n"

# stress the system
docker exec -dt xenomai sh -c 'while :; do hackbench > /dev/null ; done'
docker exec -dt xenomai sh -c 'dd if=/dev/zero of=/dev/null bs=128M'
printf "Stress tests running\n\n"

# Check if the Cobalt core loaded
printf "Check if Cobalt is loaded from the kernel logs:\n"
dmesg | grep -i xenomai

# Run smokey unit tests
printf "\n\nSmokey unit test results:\n"
docker exec -it xenomai smokey --run -k

# Run clocktest
printf "\nRunning clocktest for %s seconds\n" "$CLOCKTEST_SWITCHTEST_DURATION"
docker exec -it xenomai clocktest -D -T $CLOCKTEST_SWITCHTEST_DURATION -C CLOCK_HOST_REALTIME || clocktest -T $CLOCKTEST_SWITCHTEST_DURATION

printf "\nRunning switchtest and latency concurrently for %s seconds\n" "$CLOCKTEST_SWITCHTEST_DURATION"
# Run switchtest test for 10 seconds
#docker exec -it xenomai switchtest -T 10
docker exec -dt xenomai sh -c "switchtest -q -T $CLOCKTEST_SWITCHTEST_DURATION"

# Run latency test for 1 minute
#docker exec -it xenomai latency -q -T 300
docker exec -it xenomai bash -c 'echo 0 > /proc/xenomai/latency'
docker exec -it xenomai latency -q -T $CLOCKTEST_SWITCHTEST_DURATION

# Check i-pipe, Dovetail, EVL and Xenomai kernel config
printf "\ni-pipe, Dovetail, and EVL kernel config:\n"
zcat /proc/config.gz | grep -e DOVETAIL -e XENO -e IPIPE

# Bye bye
exit 0