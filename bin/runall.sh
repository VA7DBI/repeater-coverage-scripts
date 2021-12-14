#!/bin/sh
for i in `psql -h pg12-01 cov2 -t -c "SELECT distinct callsign FROM transmitters WHERE length(callsign) = 6"`; do bin/run_coverage_transmitter.sh $i; done
