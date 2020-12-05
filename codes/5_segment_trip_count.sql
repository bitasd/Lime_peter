
begin;
drop table if exists cr_00_500_osm_segments_buffer_union;

create table cr_00_500_osm_segments_buffer_union as
    select * from cr_00_140_osm_segments_buffer_union
union 
    select * from cr_141_320_osm_segments_buffer_union
union 
    select * from cr_321_384_osm_segments_buffer_union
union 
    select * from cr_384_500_osm_segments_buffer_union;
commit;



begin;
DROP INDEX IF EXISTS six_osm_segments_buffer_trips_union;
CREATE INDEX six_osm_segments_buffer_trips_union
  ON cr_00_500_osm_segments_buffer_union
  USING GIST (st_union);

commit;



-- begin;
-- alter table osm_segments_buffer_trips_union add column area_segment double precision;
-- update osm_segments_buffer_trips_union set area_segment = st_area(st_union);
-- commit;

drop table if exists cr_00_500_segment_trip_cnt;
create table cr_00_500_segment_trip_cnt as
select 
	osm_id, max(hname) as hname, sum(COALESCE(seg_area, 0)) as sumarea_ovlp_trps, max(min) as stress_lev, count(distinct trip_id)
from
	cr_00_500_osm_segments_buffer_union
where
	 "seg_area" > 50
group by osm_id;
