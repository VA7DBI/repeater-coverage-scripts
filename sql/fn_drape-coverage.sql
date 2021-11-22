CREATE OR REPLACE FUNCTION drape_coverage(my_wkt text) RETURNS geometry AS $$
  DECLARE
    geom3d geometry;
  BEGIN
    WITH line AS
    (SELECT my_wkt::geometry as geom),
    linemesure AS
      -- Add a mesure dimension to extract steps
      (SELECT ST_AddMeasure(line.geom, 0, ST_Length(line.geom)) as linem,
      generate_series(0, ST_Length(line.geom)::int, 50) as i
      FROM line),
    points2d AS
      (SELECT ST_GeometryN(ST_LocateAlong(linem, i), 1) AS geom FROM linemesure),
    cells AS
      -- Get DEM elevation for each
      (SELECT p.geom AS geom, ST_Value(mnt2.rast, 1, p.geom) AS val
        FROM mnt2, points2d p
        WHERE ST_Intersects(mnt2.rast, p.geom)),
    -- Instantiate 3D points
    points3d AS
      (SELECT ST_SetSRID(ST_MakePoint(ST_X(geom), ST_Y(geom), val), 2154) AS geom FROM cells)
       -- Build 3D line from 3D points
       SELECT ST_MakeLine(geom) INTO geom3d FROM points3d;
    RETURN geom3d;
  END;
$$ LANGUAGE plpgsql;
