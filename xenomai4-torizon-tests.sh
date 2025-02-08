#!/bin/bash

### VARIABLES ###
LIBEVL_VERSION="r50"
GRAPHICS_TESTS_VERSION="stable-rc"
GRAPHICS_CARD="card1-HDMI-A-1"
LATMUS_HECTIC_DURATION=60

### CODE ###

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
docker pull --quiet leograba/libevl:${LIBEVL_VERSION}
#docker pull --quiet leograba/weston:rc
docker pull --quiet torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

printf "Starting containers in the background\n\n"

# Start graphics-tests container
docker run --name graphics-tests -dt --rm  \
        --privileged \
        -v /dev:/dev -v /tmp:/tmp \
        torizon/graphics-tests:${GRAPHICS_TESTS_VERSION}

# Start container with Xenomai EVL userspace tools
docker run --name xenomai --privileged --rm -d -v /dev:/dev \
        leograba/libevl:${LIBEVL_VERSION} sleep infinity

printf "Containers started!\n\n"

# Run kmscube
docker exec -dt graphics-tests kmscube
printf "kmscube running\n\n"

# stress the system
docker exec -dt xenomai sh -c 'while :; do hackbench > /dev/null ; done'
docker exec -dt xenomai sh -c 'dd if=/dev/zero of=/dev/null bs=128M'
printf "Stress tests running\n\n"

# Run evl unit tests
printf "EVL unit test results:\n"
docker exec -it xenomai evl test

printf "\nRunning Hectic and Latmus concurrently for %s seconds\n" \
       "$LATMUS_HECTIC_DURATION"
# Run hectic test for 10 seconds
#docker exec -it xenomai hectic -T 10
# Alternative long-run test for 24 hours
docker exec -dt xenomai sh -c "hectic -q -T $LATMUS_HECTIC_DURATION"

# Run latmus test for 1 minute
#docker exec -it xenomai latmus -q -T 300
# Alternative long-run test for 24 hours
docker exec -it xenomai bash -c 'echo 0 > /proc/xenomai/latency'
docker exec -it xenomai latmus -q -T $LATMUS_HECTIC_DURATION

# Check Dovetail and EVL kernel config
printf "\nDovetail and EVL kernel config:\n"
zcat /proc/config.gz | grep -e DOVETAIL -e EVL

# Run evl kernel config check
printf "\nEVL kernel config check:\n"
docker exec -it xenomai evl check

# Bye bye
exit 0