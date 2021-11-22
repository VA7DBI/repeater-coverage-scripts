#!/bin/sh

TRANSMITTERS=`psql -h pg12-01 -d cov2 -t -c "SELECT t.id, t.callsign, (b.low + (b.high - b.low)) @ 'MHz', (ST_AsLatLonText(t.geom, 'D M S')) from transmitters t, band b where b.id=t.band and t.callsign = '$1' LIMIT 1"`
FILENAME=`echo $TRANSMITTERS  | awk -F\| '{print $2}' | awk '{$1=$1};1'`
FREQUENCY=`echo $TRANSMITTERS | awk -F\| '{print $3}' | awk '{print $1}'`
LOCATION=`echo $TRANSMITTERS  | awk -F\| '{print $4}'`
TXID=`echo $TRANSMITTERS | awk -F\| '{print $1}' | awk '{$1=$1};1'`
LAT=`echo $LOCATION | awk '{print ($1 " " $2 " " $3)}'`
LONG=`echo $LOCATION | awk '{print ($4 " " $5 " " $6)}'`
LONGFIX=`echo ${LONG} | tr -d \-`
ELEVATION="4 Meters"
mkdir processing
rm processing/${TXID}.qth
echo "${FILENAME}" > processing/${TXID}.qth
echo "${LAT}" >> processing/${TXID}.qth
echo "${LONGFIX}" >> processing/${TXID}.qth
echo "${ELEVATION}" >> processing/${TXID}.qth

splat -d /usr/local/data2/mapping/sdf/ -f ${FREQUENCY} -L 1.0  -v 255 -gc -R 50 -hd -tif -ngs -sc -dbm -log -db -112 -erp 30 -t processing/${TXID} -o processing/${TXID}
raster2pgsql -s 4326 -t 256x256 -a -F processing/${TXID}.tif coverages > processing/${TXID}.psql
psql -h pg12-01 -d cov2 -c "DELETE FROM coverages WHERE filename='${TXID}.tif' OR filename='${TXID}';"
psql -h pg12-01 -d cov2 < processing/${TXID}.psql
psql -h pg12-01 -d cov2 -c "UPDATE coverages SET filename='${TXID}' WHERE filename='${TXID}.tif';"
