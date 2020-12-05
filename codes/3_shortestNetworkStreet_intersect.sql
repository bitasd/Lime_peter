-- shortest network paths

-- shortest network paths
-- cr_00_140
alter table sh_net_cr_00_140 add column sh_net_dist_calc double precision;
update sh_net_cr_00_140 set sh_net_dist_calc = ST_Length(wkb_geometry);

drop table if exists sh_net_cr_00_140_buffer_2;
create table sh_net_cr_00_140_buffer_2 as 
	select trip_id, st_buffer(wkb_geometry, 2, 'endcap=flat join=bevel') as wkb_geometry from sh_net_cr_00_140 ;


begin;
drop index if exists six_geom_sh_net_cr_00_140;
CREATE INDEX six_geom_sh_cr_00_140
  ON sh_net_cr_00_140_buffer_2
  USING GIST (wkb_geometry);

drop table if exists osm_segments_buffer_union;

create table osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM sh_net_cr_00_140_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;

BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table osm_segments_buffer_union add column seg_area double precision;
update osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_sh_net_cr_00_140;
 create table osm_trips_stress_buffer_dissolve_sh_net_cr_00_140 as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM osm_segments_buffer_union
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_sh_net_cr_00_140
  ON osm_trips_stress_buffer_dissolve_sh_net_cr_00_140
  USING GIST (geom);
COMMIT;


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
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_sh_net_cr_00_140  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists sh_net_cr_00_140_trips_by_stress_lev;

select t.trip_id as trip_id, t.wkb_geometry as geom, t.sh_net_dist_calc as sh_net_dist_calc,
 t.dist_ratio as dist_ratio,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into sh_net_cr_00_140_trips_by_stress_lev 
from (((((sh_net_cr_00_140  t left join te_1 t1 on t.trip_id = t1.trip_id)
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




begin;
-- ALTER TABLE sh_net_cr_00_140_trips_by_stress_lev
-- ALTER COLUMN dist_calc TYPE double precision;

alter table sh_net_cr_00_140_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update sh_net_cr_00_140_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);

commit;



begin;
update sh_net_cr_00_140_trips_by_stress_lev
	set width_avg = area/sh_net_dist_calc where sh_net_dist_calc>0;
	
alter table sh_net_cr_00_140_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update sh_net_cr_00_140_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


select t.trip_id as trip_id, t.geom as geom, t.propulsion_type as propulsion_type, t.dist_calc as dist_calc, t.start_time as start_time,
t.len_1 as len_1, t.len_2 as len_2, t.len_3 as len_3, t.len_4 as len_4, t.len_11 as len_11,
sh.sh_net_dist_calc as sh_net_dist_calc, sh.dist_ratio as dist_ratio, 
sh.len_1 as sh_len_1, sh.len_2 as sh_len_2, sh.len_3 as sh_len_3, sh.len_4 as sh_len_4, sh.len_11 as sh_len_11
    into lts_len_cr_00_140
from sh_net_cr_00_140_trips_by_stress_lev  sh
    left join cr_00_140_trips_by_stress_lev t
    on sh.trip_id = t.trip_id;





-- cr_141_320
alter table sh_net_cr_141_320 add column sh_net_dist_calc double precision;
update sh_net_cr_141_320 set sh_net_dist_calc = ST_Length(geom);

create table sh_net_cr_141_320_buffer_2 as 
	select trip_id, st_buffer(wkb_geometry, 2, 'endcap=flat join=bevel') as wkb_geometry from sh_net_cr_141_320 ;


begin;
drop index if exists six_geom_sh_net_cr_141_320;
CREATE INDEX six_geom_sh_cr_141_320
  ON sh_net_cr_141_320_buffer_2
  USING GIST (wkb_geometry);

drop table if exists osm_segments_buffer_union;

create table osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM sh_net_cr_141_320_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;

BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table osm_segments_buffer_union add column seg_area double precision;
update osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_sh_net_cr_141_320;
 create table osm_trips_stress_buffer_dissolve_sh_net_cr_141_320 as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM osm_segments_buffer_union
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_sh_net_cr_141_320
  ON osm_trips_stress_buffer_dissolve_sh_net_cr_141_320
  USING GIST (geom);
COMMIT;


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
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_sh_net_cr_141_320  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists sh_net_cr_141_320_trips_by_stress_lev;

select t.trip_id as trip_id, t.wkb_geometry as geom, t.sh_net_dist_calc as sh_net_dist_calc,
 t.dist_ratio as dist_ratio,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into sh_net_cr_141_320_trips_by_stress_lev 
from (((((sh_net_cr_141_320  t left join te_1 t1 on t.trip_id = t1.trip_id)
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




begin;
-- ALTER TABLE sh_net_cr_141_320_trips_by_stress_lev
-- ALTER COLUMN dist_calc TYPE double precision;

alter table sh_net_cr_141_320_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update sh_net_cr_141_320_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);

commit;



begin;
update sh_net_cr_141_320_trips_by_stress_lev
	set width_avg = area/sh_net_dist_calc where sh_net_dist_calc>0;
	
alter table sh_net_cr_141_320_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update sh_net_cr_141_320_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


select t.trip_id as trip_id, t.geom as geom, t.propulsion_type as propulsion_type, t.dist_calc as dist_calc, t.start_time as start_time,
t.len_1 as len_1, t.len_2 as len_2, t.len_3 as len_3, t.len_4 as len_4, t.len_11 as len_11,
sh.sh_net_dist_calc as sh_net_dist_calc, sh.dist_ratio as dist_ratio, 
sh.len_1 as sh_len_1, sh.len_2 as sh_len_2, sh.len_3 as sh_len_3, sh.len_4 as sh_len_4, sh.len_11 as sh_len_11
    into lts_len_cr_141_320
from sh_net_cr_141_320_trips_by_stress_lev  sh
    left join cr_141_320_trips_by_stress_lev t
    on sh.trip_id = t.trip_id;


-- shortest network paths
-- cr_321_384
alter table sh_net_cr_321_384 add column sh_net_dist_calc double precision;
update sh_net_cr_321_384 set sh_net_dist_calc = ST_Length(wkb_geometry);

drop table if exists sh_net_cr_321_384_buffer_2;
create table sh_net_cr_321_384_buffer_2 as 
	select trip_id, st_buffer(wkb_geometry, 2, 'endcap=flat join=bevel') as wkb_geometry from sh_net_cr_321_384 ;


begin;
drop index if exists six_geom_sh_net_cr_321_384;
CREATE INDEX six_geom_sh_cr_321_384
  ON sh_net_cr_321_384_buffer_2
  USING GIST (wkb_geometry);

drop table if exists osm_segments_buffer_union;

create table osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM sh_net_cr_321_384_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;

BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table osm_segments_buffer_union add column seg_area double precision;
update osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_sh_net_cr_321_384;
 create table osm_trips_stress_buffer_dissolve_sh_net_cr_321_384 as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM osm_segments_buffer_union
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_sh_net_cr_321_384
  ON osm_trips_stress_buffer_dissolve_sh_net_cr_321_384
  USING GIST (geom);
COMMIT;


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
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_sh_net_cr_321_384  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists sh_net_cr_321_384_trips_by_stress_lev;

select t.trip_id as trip_id, t.wkb_geometry as geom, t.sh_net_dist_calc as sh_net_dist_calc,
 t.dist_ratio as dist_ratio,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into sh_net_cr_321_384_trips_by_stress_lev 
from (((((sh_net_cr_321_384  t left join te_1 t1 on t.trip_id = t1.trip_id)
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




begin;
-- ALTER TABLE sh_net_cr_321_384_trips_by_stress_lev
-- ALTER COLUMN dist_calc TYPE double precision;

alter table sh_net_cr_321_384_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update sh_net_cr_321_384_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);

commit;



begin;
update sh_net_cr_321_384_trips_by_stress_lev
	set width_avg = area/sh_net_dist_calc where sh_net_dist_calc>0;
	
alter table sh_net_cr_321_384_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update sh_net_cr_321_384_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


select t.trip_id as trip_id, t.geom as geom, t.propulsion_type as propulsion_type, t.dist_calc as dist_calc, t.start_time as start_time,
t.len_1 as len_1, t.len_2 as len_2, t.len_3 as len_3, t.len_4 as len_4, t.len_11 as len_11,
sh.sh_net_dist_calc as sh_net_dist_calc, sh.dist_ratio as dist_ratio, 
sh.len_1 as sh_len_1, sh.len_2 as sh_len_2, sh.len_3 as sh_len_3, sh.len_4 as sh_len_4, sh.len_11 as sh_len_11
    into lts_len_cr_321_384
from sh_net_cr_321_384_trips_by_stress_lev  sh
    left join cr_321_384_trips_by_stress_lev t
    on sh.trip_id = t.trip_id;


-- shortest network paths
-- cr_384_500
alter table sh_net_cr_384_500 add column sh_net_dist_calc double precision;
update sh_net_cr_384_500 set sh_net_dist_calc = ST_Length(wkb_geometry);

drop table if exists sh_net_cr_384_500_buffer_2;
create table sh_net_cr_384_500_buffer_2 as 
	select trip_id, st_buffer(wkb_geometry, 2, 'endcap=flat join=bevel') as wkb_geometry from sh_net_cr_384_500 ;


begin;
drop index if exists six_geom_sh_net_cr_384_500;
CREATE INDEX six_geom_sh_cr_384_500
  ON sh_net_cr_384_500_buffer_2
  USING GIST (wkb_geometry);

drop table if exists osm_segments_buffer_union;

create table osm_segments_buffer_union 
as
SELECT layer1.trip_id, layer2.osm_id, max(layer2.hname) as hname, min(layer2.stress_lev), 
      st_union(ST_INTERSECTION(layer1.wkb_geometry, layer2.geom))
FROM sh_net_cr_384_500_buffer_2 layer1, latest4_lime_stress_buffer_2 layer2
WHERE ST_Intersects(layer1.wkb_geometry, layer2.geom)
GROUP BY layer1.trip_id, layer2.osm_id;
commit;

BEGIN;
DROP INDEX IF EXISTS six_osm_segments_buffer_union;
CREATE INDEX six_osm_segments_buffer_union 
  ON osm_segments_buffer_union 
  USING GIST (st_union);
COMMIT;


BEGIN;
alter table osm_segments_buffer_union add column seg_area double precision;
update osm_segments_buffer_union set seg_area = st_area(st_union);
COMMIT;


---

BEGIN;
drop table if exists osm_trips_stress_buffer_dissolve_sh_net_cr_384_500;
 create table osm_trips_stress_buffer_dissolve_sh_net_cr_384_500 as
 SELECT trip_id, (ST_dump( ST_Union( st_union ) )).geom as geom, min as stress_lev, sum(seg_area) as sum_seg_area
 FROM osm_segments_buffer_union
 GROUP BY trip_id, st_union, min;
COMMIT;


begin;
CREATE INDEX six_geom_osm_trips_stress_buffer_dissolve_sh_net_cr_384_500
  ON osm_trips_stress_buffer_dissolve_sh_net_cr_384_500
  USING GIST (geom);
COMMIT;


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
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev = '1' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_2;
create table te_2 as
	select trip_id, sum(st_area(geom)) as area_2
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev = '2' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_3;
create table te_3 as
	select trip_id, sum(st_area(geom)) as area_3
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev = '3' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_4;
create table te_4 as
	select trip_id, sum(st_area(geom)) as area_4
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev = '4' AND "sum_seg_area" > 50
	group by trip_id;

-- --added---
drop table if exists te_11;
create table te_11 as
	select trip_id, sum(st_area(geom)) as area_11
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev = '11' AND "sum_seg_area" > 50
	group by trip_id;


drop table if exists te_other;
create table te_other as
	select trip_id, sum(st_area(geom)) as area_other
	from osm_trips_stress_buffer_dissolve_sh_net_cr_384_500  where stress_lev is NULL AND "sum_seg_area" > 50
	group by trip_id;

commit;



begin;
drop table if exists sh_net_cr_384_500_trips_by_stress_lev;

select t.trip_id as trip_id, t.wkb_geometry as geom, t.sh_net_dist_calc as sh_net_dist_calc,
 t.dist_ratio as dist_ratio,
t1.area_1 as area_1, t2.area_2 as area_2, t3.area_3 as area_3, t4.area_4 as area_4, t11.area_11 as area_11, te_other.area_other as area_other
    into sh_net_cr_384_500_trips_by_stress_lev 
from (((((sh_net_cr_384_500  t left join te_1 t1 on t.trip_id = t1.trip_id)
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




begin;
-- ALTER TABLE sh_net_cr_384_500_trips_by_stress_lev
-- ALTER COLUMN dist_calc TYPE double precision;

alter table sh_net_cr_384_500_trips_by_stress_lev 
	add column area double precision,
	add column width_avg double precision;

update sh_net_cr_384_500_trips_by_stress_lev
	set area =
    	COALESCE(area_1, 0) +COALESCE(area_2, 0) +COALESCE(area_3, 0) +COALESCE(area_4, 0) +COALESCE(area_11, 0) + COALESCE(area_other, 0);

commit;



begin;
update sh_net_cr_384_500_trips_by_stress_lev
	set width_avg = area/sh_net_dist_calc where sh_net_dist_calc>0;
	
alter table sh_net_cr_384_500_trips_by_stress_lev
	add column len_1 double precision,
	add column len_2 double precision,
	add column len_3 double precision,
	add column len_4 double precision,
	add column len_11 double precision;

update sh_net_cr_384_500_trips_by_stress_lev
	set
	len_1 = area_1/width_avg,
	len_2 = area_2/width_avg,
	len_3 = area_3/width_avg,
	len_4 = area_4/width_avg,
	len_11 = area_11/width_avg;

commit;


select t.trip_id as trip_id, t.geom as geom, t.propulsion_type as propulsion_type, t.dist_calc as dist_calc, t.start_time as start_time,
t.len_1 as len_1, t.len_2 as len_2, t.len_3 as len_3, t.len_4 as len_4, t.len_11 as len_11,
sh.sh_net_dist_calc as sh_net_dist_calc, sh.dist_ratio as dist_ratio, 
sh.len_1 as sh_len_1, sh.len_2 as sh_len_2, sh.len_3 as sh_len_3, sh.len_4 as sh_len_4, sh.len_11 as sh_len_11
    into lts_len_cr_384_500
from sh_net_cr_384_500_trips_by_stress_lev  sh
    left join cr_384_500_trips_by_stress_lev t
    on sh.trip_id = t.trip_id;