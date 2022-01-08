#!/bin/sh
for i in `psql -h pg12-01 cov2 -t -c "SELECT id FROM transmitters ORDER BY st_distance(geom,st_setsrid(st_makepoint(-119.5588,49.9474),4326));"`; do bin/run_coverage_transmitter.sh $i; done
