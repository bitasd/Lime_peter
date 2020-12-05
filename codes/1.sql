begin;
alter table cr_00_140 add column matched_start geometry (Point, 4326);
update cr_00_140 set matched_start = ST_Transform(ST_SetSRID( ST_StartPoint(geom), 26986), 4326);

alter table cr_00_140 add column matched_end geometry (Point, 4326);
update cr_00_140 set matched_end = ST_Transform(ST_SetSRID( ST_EndPoint(geom), 26986), 4326);

commit;
select ss.trip_id, ss.dist_calc, ss.od_line_dist, ss.geom as geom, ss.matching_error, ss.propulsion_type, ST_AsText(ss.matched_start) as matched_start, ST_AsText(ss.matched_end) as matched_end
from (select * from cr_00_140
where vehicle_type='bicycle' AND matching_error<70) ss;




begin;
alter table cr_141_320 add column matched_start geometry (Point, 4326);
update cr_141_320 set matched_start = ST_Transform(ST_SetSRID( ST_StartPoint(geom), 26986), 4326);

alter table cr_141_320 add column matched_end geometry (Point, 4326);
update cr_141_320 set matched_end = ST_Transform(ST_SetSRID( ST_EndPoint(geom), 26986), 4326);

commit;
select ss.trip_id, ss.dist_calc, ss.od_line_dist, ss.geom as geom, ss.matching_error, ss.propulsion_type, ST_AsText(ss.matched_start) as matched_start, ST_AsText(ss.matched_end) as matched_end
from (select * from cr_141_320
where vehicle_type='bicycle' AND matching_error<70) ss;



begin;
alter table cr_384_500 add column matched_start geometry (Point, 4326);
update cr_384_500 set matched_start = ST_Transform(ST_SetSRID( ST_StartPoint(geom), 26986), 4326);

alter table cr_384_500 add column matched_end geometry (Point, 4326);
update cr_384_500 set matched_end = ST_Transform(ST_SetSRID( ST_EndPoint(geom), 26986), 4326);

commit;

alter table cr_384_500 add column od_line_dist double precision;
update cr_384_500 
    set od_line_dist = ST_Distance(
			ST_Transform(ST_SetSRID(ST_MakePoint(lon_o, lat_o),4326), 26986),
			ST_Transform(ST_SetSRID(ST_MakePoint(lon_d, lat_d),4326), 26986)
    );

select ss.trip_id, ss.dist_calc, ss.od_line_dist, ss.geom as geom, ss.matching_error, ss.propulsion_type, ST_AsText(ss.matched_start) as matched_start, ST_AsText(ss.matched_end) as matched_end
from (select * from cr_384_500
where vehicle_type='bicycle' AND matching_error<70) ss;



 ogr2ogr -progress -t_srs EPSG:26986 -f "PostgreSQL" PG:"host=localhost port=5438 dbname=geospatial user=postgres password=geospatial" cr_384_500_buffered_2_error70.geojson -nln cr_384_500_buffered_2_error70
