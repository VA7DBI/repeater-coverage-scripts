#!/bin/sh

TRANSMITTERS=`psql -h pg12-01 -d cov2 -t -c "SELECT t.id, t.callsign, (b.low + (b.high - b.low)) @ 'MHz', (ST_AsLatLonText(t.geom, 'D M S')), t.band FROM transmitters t, band b WHERE b.id=t.band AND t.callsign = '$1' LIMIT 1"`
FILENAME=`echo $TRANSMITTERS  | awk -F\| '{print $2}' | awk '{$1=$1};1'`
FREQUENCY=`echo $TRANSMITTERS | awk -F\| '{print $3}' | awk '{print $1}'`
LOCATION=`echo $TRANSMITTERS  | awk -F\| '{print $4}'`
BAND=`echo $TRANSMITTERS  | awk -F\| '{print $5}' | awk '{$1=$1};1'`
TXID=`echo $TRANSMITTERS | awk -F\| '{print $1}' | awk '{$1=$1};1'`
LAT=`echo $LOCATION | awk '{print ($1 " " $2 " " $3)}'`
LONG=`echo $LOCATION | awk '{print ($4 " " $5 " " $6)}'`
LONGFIX=`echo ${LONG} | tr -d \-`
ELEVATION="4 Meters"
mkdir -p processing/${BAND}
rm processing/${BAND}/${TXID}.qth
echo "${FILENAME}" > processing/${BAND}/${TXID}.qth
echo "${LAT}" >> processing/${BAND}/${TXID}.qth
echo "${LONGFIX}" >> processing/${BAND}/${TXID}.qth
echo "${ELEVATION}" >> processing/${BAND}/${TXID}.qth
if [ -f "processing/${BAND}/${TXID}_ploss.tif" ] ; then
  echo "Skipping ${FILENAME}"
else
  splat -d /usr/local/data2/mapping/sdf/ -f ${FREQUENCY} -L 1.0  -v 255 -gc -R 50 -hd -tif -ngs -sc -dbm -log -db -112 -erp 30 -t processing/${BAND}/${TXID} -o processing/${BAND}/${TXID}
  gdal_translate -b 5 -a_nodata None -co TILED=YES -co COMPRESS=DEFLATE -co BIGTIFF=YES -of COG processing/${BAND}/${TXID}.tif processing/${BAND}/${TXID}_ploss.tif
  gdaladdo -r average processing/${BAND}/${TXID}_ploss.tif 2 4 8 16
  rm processing/${BAND}/${TXID}*.psql.gz
  raster2pgsql -s 4326 -t 256x256 -a -F processing/${BAND}/${TXID}_ploss.tif coverages > processing/${BAND}/${TXID}_ploss.psql
  psql -h pg12-01 -d cov2 -c "DELETE FROM coverages WHERE filename='${TXID}.tif' OR filename='${TXID}' OR filename='${TXID}_ploss.tiff';"
  psql -h pg12-01 -d cov2 < processing/${BAND}/${TXID}_ploss.psql
  psql -h pg12-01 -d cov2 -c "UPDATE coverages SET filename='${TXID}' WHERE filename='${TXID}_ploss.tif';"
  gzip processing/${BAND}/${TXID}*.psql
fi
