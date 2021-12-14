-- find the best repeter for a given point.

WITH pt AS (
  SELECT ST_SetSRID(ST_MakePoint(-119.3934169, 49.9024461), 4326) AS pt
)
SELECT 
  t.callsign, 
  b.notes AS Band,
  (ST_DistanceSphere(pt,t.geom) || ' m')::unit @ 'km' AS Distance,
  ST_Azimuth(pt.pt,t.geom)/(2*pi())*360  AS Heading,
  255-ST_Value(rast, 5, pt.pt) AS pathloss
FROM
  band b, 
  transmitters t, 
  coverages c
CROSS JOIN pt
WHERE ST_Intersects(pt.pt, st_convexhull(c.rast)) 
 AND b.id=t.band
 AND t.id=c.filename::int
 AND (255-ST_Value(rast, 5, pt.pt)) < 200
ORDER BY 5 ASC;

