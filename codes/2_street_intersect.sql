
--osm
DROP TABLE IF EXISTS latest4_lime_stress_buffer_2;
create table latest4_lime_stress_buffer_2 as 
	select foo.osm_id, foo.lts as stress_lev, st_buffer(foo.wkb_geometry, 2, 'endcap=flat join=bevel') as geom, foo.name as hname 
		from 
	(select * from latest4_lime_osm where cycleable is NULL) foo;

DROP INDEX IF EXISTS six_geom_osm_stress_buffer_2;
CREATE INDEX six_geom_osm_stress_buffer_2
  ON latest4_lime_stress_buffer_2
  USING GIST (geom);

------------------------------------------------------
--cr_321_384
--------------------------------------------
--  buffered cr_00_140, ... layers in QGIS
--------------------------------------------


begin;

drop index if exists six_geom_cr_321_384;
CREATE INDEX six_geom_cr_321_384
  ON cr_321_384_buffer_2
  USING GIST (wkb_geometry);

drop table if exists cr_321_384_osm_segments_buffer_union;

create table cr_321_384_osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM cr_321_384_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;


BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON cr_321_384_osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table cr_321_384_osm_segments_buffer_union add column seg_area double precision;
update cr_321_384_osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_cr_321_384 ;
 create table osm_trips_stress_buffer_dissolve_cr_321_384  as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM cr_321_384_osm_segments_buffer_union 
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_cr_321_384 
  ON osm_trips_stress_buffer_dissolve_cr_321_384 
  USING GIST (geom);
COMMIT;



--drop table if exists osm_segments_buffer_union;
commit;



-------------------------------H/L prcnt calc------


begin;


drop table if exists te_1;
drop table if exists te_2;
drop table if exists te_3;
drop table if exists te_4;
drop table if exists te_other;


drop table if exists te_1;
create table te_1 as
	select trip_id, sum(st_area(geom)) as area_1
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_cr_321_384  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists cr_321_384_trips_by_stress_lev ;

select t.trip_id as trip_id, t.geom as geom, t.vehicle_type as vehicle_type, t.propulsion_type as propulsion_type, 
t.dist_calc as dist_calc, t.matching_error as matching_error, t.start_time as start_time,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into cr_321_384_trips_by_stress_lev 
from (((((cr_321_384  t left join te_1 t1 on t.trip_id = t1.trip_id)
    left join
te_2 t2 on t.trip_id = t2.trip_id)
    left join
te_3 t3 on t.trip_id = t3.trip_id)
    left join
te_4 t4 on t.trip_id = t4.trip_id)
    left join
te_11 t11 on t.trip_id = t11.trip_id)
	left join 
te_other on t.trip_id = te_other.trip_id
;


commit;


-- delete from cr_321_384_trips_by_stress_lev where area_1 is NULL and area_2 is NULL
-- and area_3 is NULL and area_4 is NULL and area_11 is NULL and area_other is NULL;


begin;
ALTER TABLE cr_321_384_trips_by_stress_lev
ALTER COLUMN dist_calc TYPE double precision;

alter table cr_321_384_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update cr_321_384_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);



update cr_321_384_trips_by_stress_lev
	set width_avg = area/dist_calc where dist_calc>0;
	
commit;


begin;
alter table cr_321_384_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update cr_321_384_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;



--cr_00_140


begin;

drop index if exists six_geom_cr_00_140;
CREATE INDEX six_geom_cr_00_140
  ON cr_00_140_buffer_2
  USING GIST (wkb_geometry);

drop table if exists cr_00_140_osm_segments_buffer_union;

create table cr_00_140_osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM cr_00_140_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;


BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON cr_00_140_osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table cr_00_140_osm_segments_buffer_union add column seg_area double precision;
update cr_00_140_osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_cr_00_140 ;
 create table osm_trips_stress_buffer_dissolve_cr_00_140  as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM cr_00_140_osm_segments_buffer_union 
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_cr_00_140 
  ON osm_trips_stress_buffer_dissolve_cr_00_140 
  USING GIST (geom);
COMMIT;



--drop table if exists osm_segments_buffer_union;




-------------------------------H/L prcnt calc------


begin;


drop table if exists te_1;
drop table if exists te_2;
drop table if exists te_3;
drop table if exists te_4;
drop table if exists te_other;


drop table if exists te_1;
create table te_1 as
	select trip_id, sum(st_area(geom)) as area_1
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_cr_00_140  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists cr_00_140_trips_by_stress_lev ;

select t.trip_id as trip_id, t.geom as geom, t.vehicle_type as vehicle_type, t.propulsion_type as propulsion_type, 
t.dist_calc as dist_calc, t.matching_error as matching_error, t.start_time as start_time,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into cr_00_140_trips_by_stress_lev 
from (((((cr_00_140  t left join te_1 t1 on t.trip_id = t1.trip_id)
    left join
te_2 t2 on t.trip_id = t2.trip_id)
    left join
te_3 t3 on t.trip_id = t3.trip_id)
    left join
te_4 t4 on t.trip_id = t4.trip_id)
    left join
te_11 t11 on t.trip_id = t11.trip_id)
	left join 
te_other on t.trip_id = te_other.trip_id
;


commit;


-- delete from cr_00_140_trips_by_stress_lev where area_1 is NULL and area_2 is NULL
-- and area_3 is NULL and area_4 is NULL and area_11 is NULL and area_other is NULL;


begin;
ALTER TABLE cr_00_140_trips_by_stress_lev
ALTER COLUMN dist_calc TYPE double precision;

alter table cr_00_140_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update cr_00_140_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0),
	
	
update cr_00_140_trips_by_stress_lev 
	set width_avg = area/dist_calc where dist_calc>0;

commit;


begin;
alter table cr_00_140_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update cr_00_140_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


--cr_141_320


begin;

drop index if exists six_geom_cr_141_320;
CREATE INDEX six_geom_cr_141_320
  ON cr_141_320_buffer_2
  USING GIST (wkb_geometry);

drop table if exists cr_141_320_osm_segments_buffer_union;

create table cr_141_320_osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM cr_141_320_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;


BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON cr_141_320_osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table cr_141_320_osm_segments_buffer_union add column seg_area double precision;
update cr_141_320_osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_cr_141_320 ;
 create table osm_trips_stress_buffer_dissolve_cr_141_320  as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM cr_141_320_osm_segments_buffer_union 
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_cr_141_320 
  ON osm_trips_stress_buffer_dissolve_cr_141_320 
  USING GIST (geom);
COMMIT;



--drop table if exists osm_segments_buffer_union;




-------------------------------H/L prcnt calc------


begin;


drop table if exists te_1;
drop table if exists te_2;
drop table if exists te_3;
drop table if exists te_4;
drop table if exists te_other;


drop table if exists te_1;
create table te_1 as
	select trip_id, sum(st_area(geom)) as area_1
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_cr_141_320  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists cr_141_320_trips_by_stress_lev ;

select t.trip_id as trip_id, t.geom as geom, t.vehicle_type as vehicle_type, t.propulsion_type as propulsion_type, 
t.dist_calc as dist_calc, t.matching_error as matching_error, t.start_time as start_time,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into cr_141_320_trips_by_stress_lev 
from (((((cr_141_320  t left join te_1 t1 on t.trip_id = t1.trip_id)
    left join
te_2 t2 on t.trip_id = t2.trip_id)
    left join
te_3 t3 on t.trip_id = t3.trip_id)
    left join
te_4 t4 on t.trip_id = t4.trip_id)
    left join
te_11 t11 on t.trip_id = t11.trip_id)
	left join 
te_other on t.trip_id = te_other.trip_id
;


commit;


-- delete from cr_141_320_trips_by_stress_lev where area_1 is NULL and area_2 is NULL
-- and area_3 is NULL and area_4 is NULL and area_11 is NULL and area_other is NULL;


begin;
ALTER TABLE cr_141_320_trips_by_stress_lev
ALTER COLUMN dist_calc TYPE double precision;

alter table cr_141_320_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update cr_141_320_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);
commit;


update cr_141_320_trips_by_stress_lev
	set width_avg = area/dist_calc where dist_calc>0;

commit;

begin;
alter table cr_141_320_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update cr_141_320_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


--cr_384_500


begin;

drop index if exists six_geom_cr_384_500;
CREATE INDEX six_geom_cr_384_500
  ON cr_384_500_buffer_2
  USING GIST (wkb_geometry);

drop table if exists cr_384_500_osm_segments_buffer_union;

create table cr_384_500_osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM cr_384_500_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;


BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON cr_384_500_osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table cr_384_500_osm_segments_buffer_union add column seg_area double precision;
update cr_384_500_osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_cr_384_500 ;
 create table osm_trips_stress_buffer_dissolve_cr_384_500  as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM cr_384_500_osm_segments_buffer_union 
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_cr_384_500 
  ON osm_trips_stress_buffer_dissolve_cr_384_500 
  USING GIST (geom);
COMMIT;



--drop table if exists osm_segments_buffer_union;




-------------------------------H/L prcnt calc------


begin;


drop table if exists te_1;
drop table if exists te_2;
drop table if exists te_3;
drop table if exists te_4;
drop table if exists te_other;


drop table if exists te_1;
create table te_1 as
	select trip_id, sum(st_area(geom)) as area_1
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_cr_384_500  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists cr_384_500_trips_by_stress_lev ;

select t.trip_id as trip_id, t.geom as geom, t.vehicle_type as vehicle_type, t.propulsion_type as propulsion_type, 
t.dist_calc as dist_calc, t.matching_error as matching_error, t.start_time as start_time,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into cr_384_500_trips_by_stress_lev 
from (((((cr_384_500  t left join te_1 t1 on t.trip_id = t1.trip_id)
    left join
te_2 t2 on t.trip_id = t2.trip_id)
    left join
te_3 t3 on t.trip_id = t3.trip_id)
    left join
te_4 t4 on t.trip_id = t4.trip_id)
    left join
te_11 t11 on t.trip_id = t11.trip_id)
	left join 
te_other on t.trip_id = te_other.trip_id
;


commit;


-- delete from cr_384_500_trips_by_stress_lev where area_1 is NULL and area_2 is NULL
-- and area_3 is NULL and area_4 is NULL and area_11 is NULL and area_other is NULL;


begin;
ALTER TABLE cr_384_500_trips_by_stress_lev
ALTER COLUMN dist_calc TYPE double precision;

alter table cr_384_500_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update cr_384_500_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);

update cr_384_500_trips_by_stress_lev
	set width_avg = area/dist_calc where dist_calc>0;

commit;


begin;
alter table cr_384_500_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update cr_384_500_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;
