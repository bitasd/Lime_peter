select distinct(stress_lev) from sameosm_stress_lines where other_tags ilike '%interstate%'
--all interstate roadways belong to stress_lev='prohibited'



-- source : https://wiki.openstreetmap.org/wiki/Bicycle_tags_map
--yielded in 214,808 links, network was too sparse so I made it looser and changed it to only:
ALTER TABLE sameosm_stress_lines ADD COLUMN cycle varchar;
UPDATE sameosm_stress_lines SET cycle = 'noncycleable'
WHERE
    (highway in ('proposed', 'construction', 'footway', 'path', 'pedestrian', 'steps', 'bridleway', 'platform') AND
 NOT lower(other_tags)  similar to '(%bicycle"=>"yes%|%bicycle"=>"designated%|%bicycle"=>"official%|%bicycle"=>"permissive%|%bicycle"=>"destination%)')

 ;

UPDATE sameosm_stress_lines SET cycle = 'noncycleable' 
WHERE
    (other_tags ilike '%bicycle"=>"no"%' OR other_tags ilike '%cycleway:both%no%');

 

-- 234,517 links
alter table sameosm_stress_lines add column cycle_1 varchar;
UPDATE sameosm_stress_lines SET cycle_1 = 'noncycleable'
WHERE
    (other_tags ilike '%bicycle"=>"no"%' ); 


select * from sameosm_stress_lines where 'stress_lev'!= 'prohibited' OR cycle_1 is NULL;


------------------------------------------------------
-- ANOTHER ROUND WITH THE RIGHT OSM POSTGRES TABLE  --351,742 links
------------------------------------------------------
Begin;
alter table samelimeosm_lines add column cycle varchar;
update samelimeosm_lines set cycle = 'noncycleable'
where 
     "highway" in ('motorway', 'motorway_link','trunk', 'unclassified') OR "bicycle" ='no';
select * from samelimeosm_lines where cycle IS NULL;
commit;


--- @@ 219,881 links
-- ********************* this is the query to make the table ************************
drop table if exists samecycleway_osm;
create table samecycleway_osm as (
    select * from samelimeosm_lines where
not highway is null and 
(not bicycle ilike 'no' or bicycle is null) and 
not other_tags ilike '%boundary"=>"administrative%' and not other_tags ilike '%railway"=>%' and 
not highway ilike 'motor%' and not highway ilike 'trunk');




-- ************************************
alter table latest4_lime_osm drop column cycleable;
alter table latest4_lime_osm add column cycleable varchar;
update latest4_lime_osm
set cycleable = 'not'
where lts='4' AND (other_tags ilike '%power%'
OR other_tags ilike '%cable%'
OR other_tags ilike '%ownership%'
OR other_tags ilike '%boundary%'
OR other_tags ilike '%water%'  --- it might get confused with watertown so either remove it or be careful with it
OR other_tags ilike '%railway%'
OR other_tags ilike '%barrier%'
OR other_tags ilike '%fence%'
OR other_tags ilike '%underground%'
OR other_tags ilike '%pipeline%'
OR highway is NULL);



1.   --372 rows
update latest4_lime_osm
set cycleable = NULL
where lts!='4';