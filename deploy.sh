#!/bin/bash

# copy test script
printf "Updating test script\n"
rsync -v xenomai-torizon-tests.sh torizon@torizon-x86.local:

# execute test script
printf "Starting tests\n\n"
ssh -t torizon@torizon-x86.local '/home/torizon/xenomai-torizon-tests.sh'