SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA public;
COMMENT ON EXTENSION http IS 'HTTP client for PostgreSQL, allows web page retrieval inside the database.';

CREATE EXTENSION IF NOT EXISTS unit WITH SCHEMA public;
COMMENT ON EXTENSION unit IS 'SI units extension';

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;
COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


CREATE FUNCTION public.rand() RETURNS double precision
    LANGUAGE sql
    AS $$SELECT random();$$;

CREATE FUNCTION public.substring_index(text, text, integer) RETURNS text
    LANGUAGE sql
    AS $_$SELECT array_to_string((string_to_array($1, $2)) [1:$3], $2);$_$;


SET default_tablespace = '';
SET default_table_access_method = heap;


CREATE TABLE public.band (
    id INTEGER NOT NULL,
    notes TEXT,
    low public.unit,
    high public.unit
);

CREATE SEQUENCE public.band_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.band_id_seq OWNED BY public.band.id;


CREATE MATERIALIZED VIEW public.ocarc AS
  SELECT json_populate_recordset.field_callsign,
    json_populate_recordset.field_base_frequency,
    json_populate_recordset.field_lat_long,
    json_populate_recordset.field_elevation,
    json_populate_recordset.field_coordinated_by,
    json_populate_recordset.field_mode,
    json_populate_recordset.field_band,
    json_populate_recordset.field_location,
    json_populate_recordset.title,
    json_populate_recordset.changed
  FROM json_populate_recordset(NULL::record, (( SELECT http_get.content
    FROM public.http_get('https://www.ocarc.ca/frequencies.json'::character varying)
      http_get(status, content_type, headers, content)))::json)
      json_populate_recordset(field_callsign text, field_base_frequency double precision, 
        field_lat_long point, field_elevation text, field_coordinated_by text, 
        field_mode text, field_band text, field_location text, title text, 
        changed timestamp with time zone)
  WITH NO DATA;


CREATE TABLE public.transmitters (
    id INTEGER NOT NULL,
    callsign TEXT,
    geom public.geometry(GeometryZ,4326),
    band INTEGER
);

CREATE SEQUENCE public.transmitters_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;

ALTER SEQUENCE public.transmitters_id_seq OWNED BY public.transmitters.id;

ALTER TABLE ONLY public.band ALTER COLUMN id SET DEFAULT nextval('public.band_id_seq'::regclass);
ALTER TABLE ONLY public.band ADD CONSTRAINT band_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.transmitters ALTER COLUMN id SET DEFAULT nextval('public.transmitters_id_seq'::regclass);
ALTER TABLE ONLY public.transmitters ADD CONSTRAINT fk_transmiters_band FOREIGN KEY (band) REFERENCES public.band(id);

COPY public.band (notes, low, high) FROM stdin;
2200 Meters	135.699999999999989 kHz	137.800000000000011 kHz
160 Meters	1.79999999999999982 MHz	2 MHz
80 Meters	3.5 MHz	4 MHz
60 Meters	5.29999999999999982 MHz	5.39999999999999947 MHz
40 Meters	7 MHz	7.29999999999999982 MHz
30 Meters	10.0999999999999996 MHz	10.1500000000000004 MHz
20 Meters	14 MHz	14.3499999999999996 MHz
17 Meters	18.0679999999999978 MHz	18.1679999999999993 MHz
15 Meters	21 MHz	21.4499999999999993 MHz
12 Meters	24.8900000000000006 MHz	24.9899999999999984 MHz
10 Meters	28 MHz	29.6999999999999993 MHz
6 Meters	50 MHz	54 MHz
2 Meters	144 MHz	147.989999999999981 MHz
135 Centimeters	222 MHz	225 MHz
70 Centimeters	430 MHz	450 MHz
33 Centimeters	902 MHz	928 MHz
23 Centimeters	1.23999999999999999 GHz	1.30000000000000004 GHz
13 Centimeters	2.30000000000000027 GHz	2.45000000000000018 GHz
MW 1	3.30000000000000027 GHz	3.55000000000000027 GHz
MW 2	5.65000000000000036 GHz	5.92500000000000071 GHz
MW 3	10 GHz	10.5 GHz
MW 4	24 GHz	24.25 GHz
MW 5	47 GHz	47.2000000000000028 GHz
MW 6	75.5 GHz	81 GHz
MW 7	119.980000000000004 GHz	120.02000000000001 GHz
MW 8	142 GHz	149 GHz
MW 9	241.000000000000028 GHz	250.000000000000028 GHz
\.

ALTER TABLE ONLY public.band
    ADD CONSTRAINT band_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.transmitters
    ADD CONSTRAINT fk_transmiters_band FOREIGN KEY (band) REFERENCES public.band(id);

REFRESH MATERIALIZED VIEW public.ocarc;

INSERT INTO transmitters(callsign,geom,band)
  SELECT
    o.field_callsign,
    ST_SetSRID(ST_MakePoint(o.field_lat_long[0],o.field_lat_long[1],
      COALESCE(CASE WHEN o.field_elevation <> '' THEN o.field_elevation ELSE NULL END,'0')::float),4326),
    b.id
  FROM ocarc o, band b
  WHERE (o.field_base_frequency || 'MHz')::unit BETWEEN b.low AND b.high 
    AND o.field_lat_long[1] <> 0 AND o.field_lat_long[0] <> 0 
   AND o.field_callsign NOT IN (SELECT callsign FROM transmitters);

CREATE TABLE public.coverages (
    rid integer NOT NULL,
    rast public.raster,
    filename text
);

CREATE SEQUENCE public.coverages_rid_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE public.coverages_rid_seq OWNED BY public.coverages.rid;

ALTER TABLE ONLY public.coverages
    ADD CONSTRAINT coverages_pkey PRIMARY KEY (rid);

CREATE INDEX coverages_st_convexhull_idx ON public.coverages USING gist (public.st_convexhull(rast));
