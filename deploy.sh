#!/bin/bash

# copy test script
printf "Updating test script\n"
rsync -v xenomai"$1"-torizon-tests.sh torizon@torizon-x86.local:

# execute test script
printf "Starting tests\n\n"
ssh -t torizon@torizon-x86.local "/home/torizon/xenomai$1-torizon-tests.sh"