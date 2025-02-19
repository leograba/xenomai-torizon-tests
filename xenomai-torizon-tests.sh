#!/bin/bash

### VARIABLES ###

CURRENT_XENOMAI_VERSION=0
XENOMAI_TESTS_TAG=0
XENOMAI_TESTS_VERSION=0
GRAPHICS_TESTS_VERSION="stable-rc"
STRESS_TESTS_DURATION=60
### XENOMAI 3 ###
XENOMAI3_VERSION="v3.3"
### XENOMAI 4 ###
LIBEVL_VERSION="r50"

### CODE ###

# Welcome
printf "#---- Xenomai Test Report ----#\n\n"

# Print system info
# Inspired by tdx-info
printf "Kernel version: %s\n" "$(uname -rv)"
printf "Distro name: %s\n" "$(grep ^NAME /etc/os-release)"
printf "Distro version: %s\n" "$(grep VERSION_ID /etc/os-release)"
printf "Distro variant: %s\n" "$(grep VARIANT /etc/os-release)"
printf "Hostname: %s\n" "$(cat /etc/hostname)"

# Check the kernel command line
printf "\nKernel command line:\n%s\n\n" "$(cat /proc/cmdline)"

# Print the display connectors state
printf "Display connectors state is:\n"
for d in /sys/class/drm/*/status; do
    conn=$(basename "$(dirname "$d")")
    status=$(cat "$d")
    enabled=$(cat "$(dirname "$d")/enabled")
    printf "%s: %s / %s\n" "$conn" "$status" "$enabled"
done

# Check i-pipe, Dovetail, EVL and Xenomai kernel config
printf "\nKernel config - i-pipe, Dovetail, and EVL:\n"
zcat /proc/config.gz | grep -e DOVETAIL -e XENO -e IPIPE -e EVL

# Check the kernel logs for things related to Xenomai
printf "\nCheck for traces of Xenomai in the kernel logs:\n"
dmesg | grep -ie xenomai -ie evl -ie dovetail

# Determine Xenomai major version and setup conditional values
if [[ -f /proc/xenomai/version ]]; then
    CURRENT_XENOMAI_VERSION=3
    XENOMAI_TESTS_VERSION="$XENOMAI3_VERSION"
    XENOMAI_TESTS_TAG="xeno3"
elif zcat /proc/config.gz 2>/dev/null | grep -iq "CONFIG_EVL=y"; then
    CURRENT_XENOMAI_VERSION=4
    XENOMAI_TESTS_VERSION="$LIBEVL_VERSION"
    XENOMAI_TESTS_TAG="libevl"
else
    echo "Error: Unable to determine Xenomai version."
    exit 1
fi
printf "\nXenomai major version: %s\n" "$CURRENT_XENOMAI_VERSION"
printf "Xenomai test container: %s/%s\n" "$XENOMAI_TESTS_TAG" "$XENOMAI_TESTS_VERSION"

# Setup containers environment before start
printf "\nStopping all containers before starting:\n"
if [[ $(docker ps --all --quiet) ]]; then
    # shellcheck disable=SC2046
    docker stop $(docker ps --all --quiet)
fi
if [[ $(docker ps --all --quiet) ]]; then
    # shellcheck disable=SC2046
    docker rm $(docker ps --all --quiet)
fi

printf "\nPulling the latest version of containers:\n"
docker pull --quiet leograba/${XENOMAI_TESTS_TAG}:${XENOMAI_TESTS_VERSION}
#docker pull --quiet leograba/weston:rc
docker pull --quiet torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

printf "\nStarting containers in the background:\n"

# Start graphics-tests container
docker run --name graphics-tests -dt --rm  \
        --privileged \
        -v /dev:/dev -v /tmp:/tmp \
        torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

# Start container with Xenomai userspace tools
docker run --name xenomai --privileged --rm -d -v /dev:/dev \
        leograba/${XENOMAI_TESTS_TAG}:${XENOMAI_TESTS_VERSION} sleep infinity

printf "\nContainers started!\n"

# Run kmscube
docker exec -dt graphics-tests kmscube
printf "Starting kmscube...\n"

# stress the system
docker exec -dt xenomai sh -c 'while :; do hackbench > /dev/null ; done'
docker exec -dt xenomai sh -c 'dd if=/dev/zero of=/dev/null bs=128M'
printf "Starting stress tests...\n\n"

if [[ "$CURRENT_XENOMAI_VERSION" == "4" ]]; then

    # Run evl unit tests
    printf "EVL unit test results:\n"
    docker exec -it xenomai evl test

    printf "\nRunning Hectic and Latmus concurrently for %s seconds\n" \
        "$STRESS_TESTS_DURATION"
    # Run hectic test for 10 seconds
    #docker exec -it xenomai hectic -T 10
    # Alternative long-run test for 24 hours
    docker exec -dt xenomai sh -c "hectic -q -T $STRESS_TESTS_DURATION"

    # Run latmus test for 1 minute
    #docker exec -it xenomai latmus -q -T 300
    # Alternative long-run test for 24 hours
    docker exec -it xenomai latmus -q -T $STRESS_TESTS_DURATION

    # Run evl kernel config check
    printf "\nEVL kernel config check:\n"
    docker exec -it xenomai evl check

elif [[ "$CURRENT_XENOMAI_VERSION" == "3" ]]; then
    # Run smokey unit tests
    printf "\n\nSmokey unit test results:\n"
    docker exec -it xenomai smokey --run -k

    # Run clocktest
    printf "\nRunning clocktest for %s seconds\n" "$STRESS_TESTS_DURATION"
    docker exec -it xenomai sh -c "clocktest -D -T $STRESS_TESTS_DURATION -C CLOCK_HOST_REALTIME || clocktest -T $CLOCKTEST_SWITCHTEST_DURATION"

    printf "\nRunning switchtest and latency concurrently for %s seconds\n" "$STRESS_TESTS_DURATION"
    # Run switchtest test for 10 seconds
    #docker exec -it xenomai switchtest -T 10
    docker exec -dt xenomai sh -c "switchtest -q -T $STRESS_TESTS_DURATION"

    # Run latency test for 1 minute
    #docker exec -it xenomai latency -q -T 300
    docker exec -it xenomai bash -c 'echo 0 > /proc/xenomai/latency'
    docker exec -it xenomai latency -q -T $STRESS_TESTS_DURATION
fi

# Bye bye
exit 0