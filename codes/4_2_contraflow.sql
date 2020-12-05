-- script for getting the contraflow trips on oneway OSM streets
CREATE INDEX IF NOT EXISTS latest4_lime_osm_idx on latest4_lime_osm (osm_id);
-- OSM oneway buffer 2

DROP TABLE IF EXISTS latest4_lime_buffer_2_oneway;
create table latest4_lime_buffer_2_oneway as 
	select foo.osm_id, foo.lts as stress_lev, st_buffer(foo.wkb_geometry, 2, 'endcap=flat join=bevel') as geom, foo.name as hname, foo.highway as highway
		from 
	(select * from latest4_lime_osm where cycleable is NULL and oneway='yes') foo;

DROP INDEX IF EXISTS six_geom_osm_stress_buffer_2;
CREATE INDEX six_geom_osm_stress_buffer_2
  ON latest4_lime_stress_buffer_2
  USING GIST (geom);
-------------------------------------------------------------------cr_00_140
begin;

CREATE INDEX cr_00_140_vehtype ON cr_00_140 (vehicle_type);  ---------------------------------

DROP TABLE IF EXISTS osm_bike_oneway_intrsc;
create table osm_bike_oneway_intrsc as
    SELECT
		b.trip_id, b.vehicle_type, b.propulsion_type, o.osm_id,o.hname ,ST_Intersection(b.geom, o.geom) As intersect_bp
	FROM
        (select * from cr_00_140 where vehicle_type='bicycle' and matching_error<70) b ,
	     latest4_lime_buffer_2_oneway o
    where st_intersects(b.geom, o.geom);

DROP INDEX IF EXISTS cr_00_140_vehtype;
commit;

-------------------------------------------------------------------------------------------------------
-- exploding the intersection geometry of trips in QGIS 
-------------------------------------------------------------------------------------------------------
-- QGIS
-- "explode lines" function
-- save the file as osm_bike_oneway_intrsc_exploded_cr_00_140
-- ogr2ogr -progress -t_srs EPSG:26986 -f "PostgreSQL" PG:"host=localhost port=5438 dbname=geospatial user=postgres password=geospatial" osm_bike_oneway_intrsc_exploded
-- _cr_00_140.geojson -nln osm_bike_oneway_intrsc_exploded_cr_00_140 ;


-------------------------------------------------------------------------------------------------------
-- getting the geometry of the original street segment
-------------------------------------------------------------------------------------------------------
begin;
drop index if exists osm_bike_oneway_intrsc_exploded_idx;
CREATE INDEX osm_bike_oneway_intrsc_exploded_idx on osm_bike_oneway_intrsc_exploded_cr_00_140 (osm_id);
drop table if exists osm_oneway_intrsc_geom_cr_00_140;
create table osm_oneway_intrsc_geom_cr_00_140 (
    osm_id varchar,
    name varchar,
    osm_geom geometry(LineString, 26986),
    highway varchar,
    lanes varchar,
    trip_id varchar,
    vehicle_type varchar,
    propulsion_type varchar,
    the_geom geometry(LineString, 26986),

)
WITH (
 FILLFACTOR=70,
 OIDS=FALSE
);

insert into osm_oneway_intrsc_geom_cr_00_140 (osm_id, name, osm_geom, highway, lanes, trip_id, vehicle_type, propulsion_type, the_geom) 
select osm.osm_id as osm_id, osm.name as name, osm.wkb_geometry as osm_geom, osm.highway as highway, osm.lanes as lanes,
o_b.trip_id as trip_id, o_b.vehicle_type as vehicle_type, o_b.propulsion_type as propulsion_type, o_b.wkb_geometry as the_geom
    from osm_bike_oneway_intrsc_exploded_cr_00_140 o_b
left join
    latest4_lime_osm osm 
    on 
    osm.osm_id = o_b.osm_id;


commit;


-------------------------------------------------------------------------------------------------------
-- Getting the angle between trip segment and the street segment
-------------------------------------------------------------------------------------------------------
begin;

DROP INDEX IF EXISTS osm_oneway_intrsc_geom_cr_00_140_mulidx;
CREATE INDEX osm_oneway_intrsc_geom_cr_00_140_mulidx ON osm_oneway_intrsc_geom_cr_00_140 USING GiST (osm_geom, the_geom);
DROP TABLE IF EXISTS cr_00_140_angle; 
create table cr_00_140_angle
as
select trip_id, osm_id, name, osm_geom, the_geom, vehicle_type, propulsion_type,
round(degrees(ST_angle( ST_ClosestPoint(t.osm_geom, ST_StartPoint(t.the_geom)), ST_ClosestPoint(t.osm_geom, ST_EndPoint(t.the_geom)), ST_StartPoint(t.the_geom), ST_EndPoint(t.the_geom))))
as angle
from osm_oneway_intrsc_geom_cr_00_140 t;

DROP TABLE osm_oneway_intrsc_geom_cr_00_140;
DROP TABLE osm_bike_oneway_intrsc_exploded_cr_00_140; 
commit;



begin;
alter table cr_00_140_angle

    add column f1 decimal,
    add column f2 decimal;

update cr_00_140_angle
    set
        f1 = ST_LineLocatePoint(osm_geom, ST_StartPoint(the_geom)),
        f2 = ST_LineLocatePoint(osm_geom, ST_EndPoint(the_geom));
commit;



begin;
alter table cr_00_140_angle add column angle_mod decimal;
UPDATE cr_00_140_angle
SET angle_mod = CASE WHEN f1>f2 THEN angle+180 ELSE angle END;
commit;


begin;
ALTER TABLE cr_00_140_angle ADD COLUMN angle_mod_1 decimal;
UPDATE cr_00_140_angle
SET angle_mod_1 = CASE WHEN angle_mod>360 THEN angle_mod-360 ELSE angle_mod END;
commit;


begin;
ALTER TABLE cr_00_140_angle ADD COLUMN seg_len double precision;
UPDATE cr_00_140_angle
SET seg_len = ST_Length(the_geom);
commit;
-------------------------------------------------------------------------------------------------------
-- Getting the count of contraflow & same direction
-------------------------------------------------------------------------------------------------------

-------00_140-------------------------------------------
-- contraflow
begin;
DROP TABLE IF EXISTS cr_00_140_angle_cnt_contraflow;
CREATE TABLE cr_00_140_angle_cnt_contraflow as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_00_140_angle
    where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;

-- same direction
DROP TABLE IF EXISTS cr_00_140_angle_cnt_samedirect;
CREATE TABLE cr_00_140_angle_cnt_samedirect as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_00_140_angle
    where seg_len>10 AND (angle_mod_1 BETWEEN 0 AND 10) OR (angle_mod_1 BETWEEN 350 AND 360)
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;




-------------------------------------------------------------------cr_141_320
begin;

CREATE INDEX IF NOT EXISTS cr_141_320_vehtype ON cr_141_320 (vehicle_type);  ---------------------------------

DROP TABLE IF EXISTS osm_bike_oneway_intrsc;
create table osm_bike_oneway_intrsc as
    SELECT
		b.trip_id, b.vehicle_type, b.propulsion_type, o.osm_id,o.hname ,ST_Intersection(b.geom, o.geom) As intersect_bp
	FROM
        (select * from cr_141_320 where vehicle_type='bicycle' and matching_error<70) b ,
	     latest4_lime_buffer_2_oneway o
    where st_intersects(b.geom, o.geom);

DROP INDEX IF EXISTS cr_141_320_vehtype;
commit;

-------------------------------------------------------------------------------------------------------
-- exploding the intersection geometry of trips in QGIS 
-------------------------------------------------------------------------------------------------------
-- QGIS
-- "explode lines" function
-- save the file as osm_bike_oneway_intrsc_exploded_cr_141_320
-- ogr2ogr -progress -t_srs EPSG:26986 -f "PostgreSQL" PG:"host=localhost port=5438 dbname=geospatial user=postgres password=geospatial" osm_bike_oneway_intrsc_exploded
-- _cr_141_320.geojson -nln osm_bike_oneway_intrsc_exploded_cr_141_320 ;


-------------------------------------------------------------------------------------------------------
-- getting the geometry of the original street segment
-------------------------------------------------------------------------------------------------------
begin;
drop index if exists osm_bike_oneway_intrsc_exploded_idx;
CREATE INDEX osm_bike_oneway_intrsc_exploded_idx on osm_bike_oneway_intrsc_exploded_cr_141_320 (osm_id);
drop table if exists osm_oneway_intrsc_geom_cr_141_320;
create table osm_oneway_intrsc_geom_cr_141_320 (
    osm_id varchar,
    name varchar,
    osm_geom geometry(LineString, 26986),
    trip_id varchar,
    vehicle_type varchar,
    propulsion_type varchar,
    the_geom geometry(LineString, 26986)

)
WITH (
 FILLFACTOR=70,
 OIDS=FALSE
);

insert into osm_oneway_intrsc_geom_cr_141_320 (osm_id, name, osm_geom, trip_id, vehicle_type, propulsion_type, the_geom) 
select osm.osm_id as osm_id, osm.name as name, osm.wkb_geometry as osm_geom,
o_b.trip_id as trip_id, o_b.vehicle_type as vehicle_type, o_b.propulsion_type as propulsion_type, o_b.wkb_geometry as the_geom
    from osm_bike_oneway_intrsc_exploded_cr_141_320 o_b
left join
    latest4_lime_osm osm 
    on 
    osm.osm_id = o_b.osm_id;


commit;


-------------------------------------------------------------------------------------------------------
-- Getting the angle between trip segment and the street segment
-------------------------------------------------------------------------------------------------------
begin;

DROP INDEX IF EXISTS osm_oneway_intrsc_geom_cr_141_320_mulidx;
CREATE INDEX osm_oneway_intrsc_geom_cr_141_320_mulidx ON osm_oneway_intrsc_geom_cr_141_320 USING GiST (osm_geom, the_geom);
DROP TABLE IF EXISTS cr_141_320_angle; 
create table cr_141_320_angle
as
select trip_id, osm_id, name, osm_geom, the_geom, vehicle_type, propulsion_type,
round(degrees(ST_angle( ST_ClosestPoint(t.osm_geom, ST_StartPoint(t.the_geom)), ST_ClosestPoint(t.osm_geom, ST_EndPoint(t.the_geom)), ST_StartPoint(t.the_geom), ST_EndPoint(t.the_geom))))
as angle
from osm_oneway_intrsc_geom_cr_141_320 t;

DROP TABLE osm_oneway_intrsc_geom_cr_141_320;
DROP TABLE osm_bike_oneway_intrsc_exploded_cr_141_320; 
commit;



begin;
alter table cr_141_320_angle

    add column f1 decimal,
    add column f2 decimal;

update cr_141_320_angle
    set
        f1 = ST_LineLocatePoint(osm_geom, ST_StartPoint(the_geom)),
        f2 = ST_LineLocatePoint(osm_geom, ST_EndPoint(the_geom));
commit;



begin;
alter table cr_141_320_angle add column angle_mod decimal;
UPDATE cr_141_320_angle
SET angle_mod = CASE WHEN f1>f2 THEN angle+180 ELSE angle END;
commit;


begin;
ALTER TABLE cr_141_320_angle ADD COLUMN angle_mod_1 decimal;
UPDATE cr_141_320_angle
SET angle_mod_1 = CASE WHEN angle_mod>360 THEN angle_mod-360 ELSE angle_mod END;
commit;

begin;
ALTER TABLE cr_141_320_angle ADD COLUMN seg_len double precision;
UPDATE cr_141_320_angle
SET seg_len = ST_Length(the_geom);
commit;
-------------------------------------------------------------------------------------------------------
-- Getting the count of contraflow & same direction
-------------------------------------------------------------------------------------------------------

-------141_320-------------------------------------------
-- contraflow
begin;
DROP TABLE IF EXISTS cr_141_320_angle_cnt_contraflow;
CREATE TABLE cr_141_320_angle_cnt_contraflow as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_141_320_angle
    where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;

-- same direction
DROP TABLE IF EXISTS cr_141_320_angle_cnt_samedirect;
CREATE TABLE cr_141_320_angle_cnt_samedirect as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_141_320_angle
    where seg_len>10 AND (angle_mod_1 BETWEEN 0 AND 10) OR (angle_mod_1 BETWEEN 350 AND 360)
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;


-------------------------------------------------------------------cr_321_384
begin;

CREATE INDEX IF NOT EXISTS cr_321_384_vehtype ON cr_321_384 (vehicle_type);  ---------------------------------

DROP TABLE IF EXISTS osm_bike_oneway_intrsc;
create table osm_bike_oneway_intrsc as
    SELECT
		b.trip_id, b.vehicle_type, b.propulsion_type, o.osm_id,o.hname ,ST_Intersection(b.geom, o.geom) As intersect_bp
	FROM
        (select * from cr_321_384 where vehicle_type='bicycle' and matching_error<70) b ,
	     latest4_lime_buffer_2_oneway o
    where st_intersects(b.geom, o.geom);

DROP INDEX IF EXISTS cr_321_384_vehtype;
commit;

-------------------------------------------------------------------------------------------------------
-- exploding the intersection geometry of trips in QGIS 
-------------------------------------------------------------------------------------------------------
-- QGIS
-- "explode lines" function
-- save the file as osm_bike_oneway_intrsc_exploded_cr_321_384
-- ogr2ogr -progress -t_srs EPSG:26986 -f "PostgreSQL" PG:"host=localhost port=5438 dbname=geospatial user=postgres password=geospatial" osm_bike_oneway_intrsc_exploded
-- _cr_321_384.geojson -nln osm_bike_oneway_intrsc_exploded_cr_321_384 ;


-------------------------------------------------------------------------------------------------------
-- getting the geometry of the original street segment
-------------------------------------------------------------------------------------------------------
begin;
drop index if exists osm_bike_oneway_intrsc_exploded_idx;
CREATE INDEX osm_bike_oneway_intrsc_exploded_idx on osm_bike_oneway_intrsc_exploded_cr_321_384 (osm_id);
drop table if exists osm_oneway_intrsc_geom_cr_321_384;
create table osm_oneway_intrsc_geom_cr_321_384 (
    osm_id varchar,
    name varchar,
    osm_geom geometry(LineString, 26986),
    trip_id varchar,
    vehicle_type varchar,
    propulsion_type varchar,
    the_geom geometry(LineString, 26986)

)
WITH (
 FILLFACTOR=70,
 OIDS=FALSE
);

insert into osm_oneway_intrsc_geom_cr_321_384 (osm_id, name, osm_geom, trip_id, vehicle_type, propulsion_type, the_geom) 
select osm.osm_id as osm_id, osm.name as name, osm.wkb_geometry as osm_geom,
o_b.trip_id as trip_id, o_b.vehicle_type as vehicle_type, o_b.propulsion_type as propulsion_type, o_b.wkb_geometry as the_geom
    from osm_bike_oneway_intrsc_exploded_cr_321_384 o_b
left join
    latest4_lime_osm osm 
    on 
    osm.osm_id = o_b.osm_id;


commit;


-------------------------------------------------------------------------------------------------------
-- Getting the angle between trip segment and the street segment
-------------------------------------------------------------------------------------------------------
begin;

DROP INDEX IF EXISTS osm_oneway_intrsc_geom_cr_321_384_mulidx;
CREATE INDEX osm_oneway_intrsc_geom_cr_321_384_mulidx ON osm_oneway_intrsc_geom_cr_321_384 USING GiST (osm_geom, the_geom);
DROP TABLE IF EXISTS cr_321_384_angle; 
create table cr_321_384_angle
as
select trip_id, osm_id, name, osm_geom, the_geom, vehicle_type, propulsion_type,
round(degrees(ST_angle( ST_ClosestPoint(t.osm_geom, ST_StartPoint(t.the_geom)), ST_ClosestPoint(t.osm_geom, ST_EndPoint(t.the_geom)), ST_StartPoint(t.the_geom), ST_EndPoint(t.the_geom))))
as angle
from osm_oneway_intrsc_geom_cr_321_384 t;

DROP TABLE osm_oneway_intrsc_geom_cr_321_384;
DROP TABLE osm_bike_oneway_intrsc_exploded_cr_321_384; 
commit;



begin;
alter table cr_321_384_angle

    add column f1 decimal,
    add column f2 decimal;

update cr_321_384_angle
    set
        f1 = ST_LineLocatePoint(osm_geom, ST_StartPoint(the_geom)),
        f2 = ST_LineLocatePoint(osm_geom, ST_EndPoint(the_geom));
commit;



begin;
alter table cr_321_384_angle add column angle_mod decimal;
UPDATE cr_321_384_angle
SET angle_mod = CASE WHEN f1>f2 THEN angle+180 ELSE angle END;
commit;


begin;
ALTER TABLE cr_321_384_angle ADD COLUMN angle_mod_1 decimal;
UPDATE cr_321_384_angle
SET angle_mod_1 = CASE WHEN angle_mod>360 THEN angle_mod-360 ELSE angle_mod END;
commit;

begin;
ALTER TABLE cr_321_384_angle ADD COLUMN seg_len double precision;
UPDATE cr_321_384_angle
SET seg_len = ST_Length(the_geom);
commit;
-------------------------------------------------------------------------------------------------------
-- Getting the count of contraflow & same direction
-------------------------------------------------------------------------------------------------------

-------321_384-------------------------------------------
-- contraflow
begin;
DROP TABLE IF EXISTS cr_321_384_angle_cnt_contraflow;
CREATE TABLE cr_321_384_angle_cnt_contraflow as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_321_384_angle
    where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;

-- same direction
DROP TABLE IF EXISTS cr_321_384_angle_cnt_samedirect;
CREATE TABLE cr_321_384_angle_cnt_samedirect as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_321_384_angle
    where seg_len>10 AND (angle_mod_1 BETWEEN 0 AND 10) OR (angle_mod_1 BETWEEN 350 AND 360)
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;


-------------------------------------------------------------------cr_384_500
begin;

CREATE INDEX IF NOT EXISTS cr_384_500_vehtype ON cr_384_500 (vehicle_type);  ---------------------------------

DROP TABLE IF EXISTS osm_bike_oneway_intrsc;
create table osm_bike_oneway_intrsc as
    SELECT
		b.trip_id, b.vehicle_type, b.propulsion_type, o.osm_id,o.hname ,ST_Intersection(b.geom, o.geom) As intersect_bp
	FROM
        (select * from cr_384_500 where vehicle_type='bicycle' and matching_error<70) b ,
	     latest4_lime_buffer_2_oneway o
    where st_intersects(b.geom, o.geom);

DROP INDEX IF EXISTS cr_384_500_vehtype;
commit;

-------------------------------------------------------------------------------------------------------
-- exploding the intersection geometry of trips in QGIS 
-------------------------------------------------------------------------------------------------------
-- QGIS
-- "explode lines" function
-- save the file as osm_bike_oneway_intrsc_exploded_cr_384_500
-- ogr2ogr -progress -t_srs EPSG:26986 -f "PostgreSQL" PG:"host=localhost port=5438 dbname=geospatial user=postgres password=geospatial" osm_bike_oneway_intrsc_exploded
-- _cr_384_500.geojson -nln osm_bike_oneway_intrsc_exploded_cr_384_500 ;


-------------------------------------------------------------------------------------------------------
-- getting the geometry of the original street segment
-------------------------------------------------------------------------------------------------------
begin;
drop index if exists osm_bike_oneway_intrsc_exploded_idx;
CREATE INDEX osm_bike_oneway_intrsc_exploded_idx on osm_bike_oneway_intrsc_exploded_cr_384_500 (osm_id);
drop table if exists osm_oneway_intrsc_geom_cr_384_500;
create table osm_oneway_intrsc_geom_cr_384_500 (
    osm_id varchar,
    name varchar,
    osm_geom geometry(LineString, 26986),
    trip_id varchar,
    vehicle_type varchar,
    propulsion_type varchar,
    the_geom geometry(LineString, 26986)

)
WITH (
 FILLFACTOR=70,
 OIDS=FALSE
);

insert into osm_oneway_intrsc_geom_cr_384_500 (osm_id, name, osm_geom, trip_id, vehicle_type, propulsion_type, the_geom) 
select osm.osm_id as osm_id, osm.name as name, osm.wkb_geometry as osm_geom,
o_b.trip_id as trip_id, o_b.vehicle_type as vehicle_type, o_b.propulsion_type as propulsion_type, o_b.wkb_geometry as the_geom
    from osm_bike_oneway_intrsc_exploded_cr_384_500 o_b
left join
    latest4_lime_osm osm 
    on 
    osm.osm_id = o_b.osm_id;


commit;


-------------------------------------------------------------------------------------------------------
-- Getting the angle between trip segment and the street segment
-------------------------------------------------------------------------------------------------------
begin;

DROP INDEX IF EXISTS osm_oneway_intrsc_geom_cr_384_500_mulidx;
CREATE INDEX osm_oneway_intrsc_geom_cr_384_500_mulidx ON osm_oneway_intrsc_geom_cr_384_500 USING GiST (osm_geom, the_geom);
DROP TABLE IF EXISTS cr_384_500_angle; 
create table cr_384_500_angle
as
select trip_id, osm_id, name, osm_geom, the_geom, vehicle_type, propulsion_type,
round(degrees(ST_angle( ST_ClosestPoint(t.osm_geom, ST_StartPoint(t.the_geom)), ST_ClosestPoint(t.osm_geom, ST_EndPoint(t.the_geom)), ST_StartPoint(t.the_geom), ST_EndPoint(t.the_geom))))
as angle
from osm_oneway_intrsc_geom_cr_384_500 t;

DROP TABLE osm_oneway_intrsc_geom_cr_384_500;
DROP TABLE osm_bike_oneway_intrsc_exploded_cr_384_500; 
commit;



begin;
alter table cr_384_500_angle

    add column f1 decimal,
    add column f2 decimal;

update cr_384_500_angle
    set
        f1 = ST_LineLocatePoint(osm_geom, ST_StartPoint(the_geom)),
        f2 = ST_LineLocatePoint(osm_geom, ST_EndPoint(the_geom));
commit;



begin;
alter table cr_384_500_angle add column angle_mod decimal;
UPDATE cr_384_500_angle
SET angle_mod = CASE WHEN f1>f2 THEN angle+180 ELSE angle END;
commit;


begin;
ALTER TABLE cr_384_500_angle ADD COLUMN angle_mod_1 decimal;
UPDATE cr_384_500_angle
SET angle_mod_1 = CASE WHEN angle_mod>360 THEN angle_mod-360 ELSE angle_mod END;
commit;

begin;
ALTER TABLE cr_384_500_angle ADD COLUMN seg_len double precision;
UPDATE cr_384_500_angle
SET seg_len = ST_Length(the_geom);
commit;
-------------------------------------------------------------------------------------------------------
-- Getting the count of contraflow & same direction
-------------------------------------------------------------------------------------------------------

-------384_500-------------------------------------------
-- contraflow
begin;
DROP TABLE IF EXISTS cr_384_500_angle_cnt_contraflow;
CREATE TABLE cr_384_500_angle_cnt_contraflow as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_384_500_angle
    where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;

-- same direction
DROP TABLE IF EXISTS cr_384_500_angle_cnt_samedirect;
CREATE TABLE cr_384_500_angle_cnt_samedirect as
	select osm_id, min(name) as name, osm_geom, count(distinct trip_id) as cnt, sum(seg_len) as tot_m
from cr_384_500_angle
    where seg_len>10 AND (angle_mod_1 BETWEEN 0 AND 10) OR (angle_mod_1 BETWEEN 350 AND 360)
group by osm_id, osm_geom
HAVING count(trip_id)>0
order by cnt;

-------------------------------------------------------------------------------------------


begin;
DROP TABLE IF EXISTS cr_00_500_angle_cnt;
CREATE TABLE cr_00_500_angle_cnt
(
 osm_id varchar,
 name varchar,
 osm_geom geometry(LineString, 26986),
 contra_tot_m_00_140 double precision,
 same_tot_m_00_140 double precision,
 contra_tot_m_141_320 double precision,
 same_tot_m_141_320 double precision,
 contra_tot_m_321_384 double precision,
 same_tot_m_321_384 double precision,
 contra_tot_m_384_500 double precision,
 same_tot_m_384_500 double precision

)
WITH (
 FILLFACTOR=70,
 OIDS=FALSE
);



insert into cr_00_500_angle_cnt (osm_id, name, osm_geom, contra_tot_m_00_140, same_tot_m_00_140, contra_tot_m_141_320, same_tot_m_141_320, contra_tot_m_321_384, same_tot_m_321_384,
contra_tot_m_384_500, same_tot_m_384_500)
select osm.osm_id as osm_id, osm.name as name, osm.wkb_geometry as osm_geom, contra_00_140.tot_m as contra_tot_m_00_140, same_00_140.tot_m as same_tot_m_00_140, 
    contra_141_320.tot_m as contra_tot_m_141_320, same_141_320.tot_m as same_tot_m_141_320, contra_321_384.tot_m as contra_tot_m_321_384, same_321_384.tot_m as same_tot_m_321_384, 
    contra_384_500.tot_m as contra_tot_m_384_500, same_384_500.tot_m as same_tot_m_384_500
from latest4_lime_osm osm
    left join cr_00_140_angle_cnt_contraflow contra_00_140
        on osm.osm_id = contra_00_140.osm_id
    left join cr_00_140_angle_cnt_samedirect same_00_140
        on osm.osm_id = same_00_140.osm_id
    left join cr_141_320_angle_cnt_contraflow contra_141_320
        on osm.osm_id = contra_141_320.osm_id
    left join cr_141_320_angle_cnt_samedirect same_141_320
        on osm.osm_id = same_141_320.osm_id
    left join cr_321_384_angle_cnt_contraflow contra_321_384
        on osm.osm_id = contra_321_384.osm_id
    left join cr_321_384_angle_cnt_samedirect same_321_384
        on osm.osm_id = same_321_384.osm_id
    left join cr_384_500_angle_cnt_contraflow contra_384_500
        on osm.osm_id = contra_384_500.osm_id
    left join cr_384_500_angle_cnt_samedirect same_384_500
        on osm.osm_id = same_384_500.osm_id;

commit;


-- total 

DROP TABLE IF EXISTS cr_00_500_tot_m;
create table cr_00_500_tot_m as
    select * from cr_00_500_angle_cnt where osm_id in
(select osm_id from latest4_lime_osm where cycleable is NULL and oneway='yes')

begin;

ALTER TABLE cr_00_500_tot_m 
    ADD COLUMN tot_m_contra double precision,
    ADD COLUMN tot_m_same double precision,
    ADD COLUMN tot_cnt_contra bigint,
    ADD COLUMN tot_cnt_same bigint;

UPDATE cr_00_500_tot_m 
    set 
        tot_m_contra = COALESCE(contra_tot_m_00_140,0) + COALESCE(contra_tot_m_141_320,0) + COALESCE(contra_tot_m_321_384,0) + COALESCE(contra_tot_m_384_500,0),
        tot_m_same = COALESCE(same_tot_m_00_140,0) + COALESCE(same_tot_m_141_320,0) + COALESCE(same_tot_m_321_384,0) + COALESCE(same_tot_m_384_500,0),
        tot_cnt_contra = COALESCE(contra_cnt_00_140,0) + COALESCE(contra_cnt_141_320,0) + COALESCE(contra_cnt_321_384,0) + COALESCE(contra_cnt_384_500,0),
        tot_cnt_same = COALESCE(same_cnt_00_140,0) + COALESCE(same_cnt_141_320,0) + COALESCE(same_cnt_321_384,0) + COALESCE(same_cnt_384_500,0);


commit;


BEGIN;
DROP TABLE cr_00_140_angle_cnt_contraflow, cr_00_140_angle_cnt_samedirect, cr_141_320_angle_cnt_contraflow, cr_141_320_angle_cnt_samedirect, 
cr_321_384_angle_cnt_contraflow, cr_321_384_angle_cnt_samedirect, cr_384_500_angle_cnt_contraflow, cr_384_500_angle_cnt_samedirect;
COMMIT;

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---- Divided vs true oneway @@


-- simple oneway:
select sum(st_length(l.wkb_geometry)) as network_meters
from
(select * from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%') l,
(select * from lime_muni where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_within(l.wkb_geometry, st_transform(m.wkb_geometry,26986)))

-- divided oneway:
select sum(st_length(l.wkb_geometry)) as network_meters
from (select * from latest4_lime_osm where lime_dvd_oneway = 'yes') l,
(select * from lime_muni where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_within(l.wkb_geometry, st_transform(m.wkb_geometry,26986)))

-- rest:
select sum(st_length(l.wkb_geometry)) as network_meters
from (select * from latest4_lime_osm where ( oneway is null or oneway != 'yes')and lime_dvd_oneway is null and cycleable is null and not highway ilike 'motorway%' and not other_tags ilike '%railway"=>%' and not other_tags ilike '%boundary"=>%'and not other_tags ilike '%barrier%') l,
(select * from lime_muni where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_within(l.wkb_geometry, st_transform(m.wkb_geometry,26986)))



--- bs
-- simple oneway
select t.osm_id as osmid, t.osm_geom, t.name, t.tot_m_contra, t.tot_cnt_contra, t.tot_m_same, t.tot_cnt_same, s.highway
 from cr_00_500_tot_m t,

(select highway, osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%') s
where t.osm_id = s.osm_id


-- xxx% of bikeshare trips included at least one segment in which the cyclist rode the wrong way on a simple one-way street
-------------------------------------------------------------------------------------------------------
-- --- for the whole region and all the trips
-------------------------------------------------------------------------------------------------------
create view trip_at_least_on_oneway as
select distinct trip_id from cr_384_500_angle where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10 AND osm_id in

(select osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%')

    UNION

select distinct trip_id from cr_00_140_angle where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10 AND osm_id in

(select osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%')

    UNION

select distinct trip_id from cr_141_320_angle where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10 AND osm_id in

(select osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%')

    UNION

select distinct trip_id from cr_321_384_angle where (angle_mod_1 BETWEEN 170 AND 190) AND seg_len>10 AND osm_id in

(select osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%')


select count(*) from trip_at_least_on_oneway   --- for the whole region and all the trips
-- 39,531


-- total meters traveled on simple oneway
select sum(tot_m_contra) from cr_00_500_tot_m where 
osm_id in
(select osm_id from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%')

-- 8,317,171.945207283

------------ total meters travled by trips 

-- 132,553,155


-------------------------------------------------------------------------------------------------------
-- --- for the five municipalities 
-------------------------------------------------------------------------------------------------------

-- get a list of trips that intersect with those 5 communities

create view cr_00_500_bike_error70_5muni  -- 65,229
    as
select distinct(trip_id), dist_calc
from 
(select * from cr_00_140 where vehicle_type='bicycle' and matching_error<70) trips,
(select * from lime_muni_2 where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_intersects(trips.geom, m.wkb_geometry))
    UNION

select distinct(trip_id), dist_calc
from 
(select * from cr_141_320 where vehicle_type='bicycle' and matching_error<70) trips,
(select * from lime_muni_2 where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_intersects(trips.geom, m.wkb_geometry))
    UNION

select distinct(trip_id), dist_calc
from 
(select * from cr_321_384 where vehicle_type='bicycle' and matching_error<70) trips,
(select * from lime_muni_2 where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_intersects(trips.geom, m.wkb_geometry))

    UNION
select distinct(trip_id), dist_calc
from 
(select * from cr_384_500 where vehicle_type='bicycle' and matching_error<70) trips,
(select * from lime_muni_2 where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_intersects(trips.geom, m.wkb_geometry))

-- count
select count(distinct trip_id) from cr_00_500_bike_error70_5muni where trip_id in (select trip_id from trip_at_least_on_oneway)
-- 28,451


------------- total meters traveled on simple oneway for 5 municipalities


select sum(tot_m_contra) from cr_00_500_tot_m where osm_id in 
(select osm_id from 
(select * from latest4_lime_osm where oneway = 'yes' and lime_dvd_oneway is null and not highway ilike 'motorway%' and not highway ilike 'trunk%' and not highway ilike 'service' and not highway ilike 'cycleway' and not name is null and not name ilike '%circle%') l,
(select * from lime_muni_2 where municipal in ('Malden','Everett', 'Revere', 'Chelsea' ,'Winthrop')) m
where (st_intersects(l.wkb_geometry, m.wkb_geometry)));

-- 6,352,087.021678947

------------ total meters travled by trips in 5 municipalities

select sum(dist_calc) from cr_00_500_bike_error70_5muni;
-- 125,270,662
