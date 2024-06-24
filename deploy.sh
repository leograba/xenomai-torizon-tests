#!/bin/bash

#DEVICE="torizon-x86.local"
DEVICE="torizon-x86"

# copy test script
printf "Updating test script\n"
rsync -v xenomai"$1"-torizon-tests.sh torizon@"$DEVICE":

# execute test script
printf "Starting tests\n\n"
ssh -t torizon@"$DEVICE" "/home/torizon/xenomai$1-torizon-tests.sh"