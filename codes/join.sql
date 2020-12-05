



pg_dump -t sameosm_stress_lines geospatial -h localhost -p 5438 -U postgres| psql limedb -h localhost -U postgres -p 5435

Alter table segments_byquarters_bydow_v2 add column lts integer;

UPDATE 
    segments_byquarters_bydow_v2 t1
SET 
    lts = osm.lts
FROM 
    sameosm_stress_lines osm
WHERE 
    t1.osm_id = osm.osm_id;


