-- find the best repeter for a given point.

WITH pt AS (
  SELECT ST_SetSRID(ST_MakePoint(-119.3934, 49.9024), 4326)
  AS pt )
SELECT 255-ST_Value(rast, 5, pt.pt) as pathloss, t.callsign
FROM transmitters t, coverages c
CROSS JOIN pt
WHERE ST_Intersects(pt.pt, st_convexhull(c.rast)) 
 AND t.id=c.filename::int
 ORDER BY 1 ASC;

