#!/bin/bash

# Print the display connector state
printf "Display connector state is: %s\n\n" "$(cat /sys/class/drm/card0-HDMI-A-1/status)"

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
docker pull --quiet leograba/xeno3:ubuntu-22.04
#docker pull --quiet leograba/weston:rc
docker pull --quiet torizon/graphics-tests:rc

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
        torizon/graphics-tests:rc

# Start container with Xenomai 3 userspace tools
docker run --name xenomai --privileged --rm -d -v /dev:/dev \
        leograba/xeno3:ubuntu-22.04 sleep infinity

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
DURATION=30
printf "\nRunning clocktest for %s seconds\n" "$DURATION"
docker exec -it xenomai clocktest -D -T 30 -C CLOCK_HOST_REALTIME || clocktest -T 30

DURATION=60
printf "\nRunning switchtest and latency concurrently for %s seconds\n" "$DURATION"
# Run switchtest test for 10 seconds
#docker exec -it xenomai switchtest -T 10
docker exec -dt xenomai sh -c "switchtest -q -T $DURATION"

# Run latency test for 1 minute
#docker exec -it xenomai latency -q -T 300
docker exec -it xenomai bash -c 'echo 0 > /proc/xenomai/latency'
docker exec -it xenomai latency -q -T $DURATION

# Check Dovetail and Xenomai kernel config
printf "\nDovetail and EVL kernel config:\n"
zcat /proc/config.gz | grep -e DOVETAIL -e XENO

# Bye bye
exit 0