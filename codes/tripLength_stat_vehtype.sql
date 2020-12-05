

begin; 
alter table cr_00_140 add column _month integer;
update cr_00_140 set _month = extract(month from start_time);

alter table cr_141_320 add column _month integer;
update cr_141_320 set _month = extract(month from start_time);

alter table cr_321_384 add column _month integer;
update cr_321_384 set _month = extract(month from start_time);

alter table cr_384_500 add column _month integer;
update cr_384_500 set _month = extract(month from start_time);

commit;


create view cr_00_500 as
    select trip_id, vehicle_type, propulsion_type, dist_calc,_month, quart_year from cr_00_140
        UNION
    select trip_id, vehicle_type, propulsion_type, dist_calc,_month, quart_year from cr_141_320
        UNION
    select trip_id, vehicle_type, propulsion_type, dist_calc,_month, quart_year from cr_321_384
        UNION
    select trip_id, vehicle_type, propulsion_type, dist_calc,_month, quart_year from cr_384_500;


--by month
select
    vehicle_type, propulsion_type, _month,
    AVG(dist_calc) as dist_avg,
    percentile_cont(0.25) within group (order by things.dist_calc) as p25,
    percentile_cont(0.5) within group (order by things.dist_calc) as p50,
    percentile_cont(0.75) within group (order by things.dist_calc) as p75
from (select * from cr_00_500 where quart_year in ('q2_2018','q3_2018','q4_2018','q1_2019','q2_2019','q3_2019')) things
group by vehicle_type, propulsion_type, _month;

-- by month, quarter-year
select
    vehicle_type, propulsion_type, _month, quart_year,
    AVG(dist_calc) as dist_avg,
    percentile_cont(0.25) within group (order by things.dist_calc) as p25,
    percentile_cont(0.5) within group (order by things.dist_calc) as p50,
    percentile_cont(0.75) within group (order by things.dist_calc) as p75
from (select * from cr_00_500 where quart_year in ('q2_2018','q3_2018','q4_2018','q1_2019','q2_2019','q3_2019')) things
group by vehicle_type, propulsion_type, _month, quart_year;

-- by vehicle_type
select
    vehicle_type, propulsion_type,
    AVG(dist_calc) as dist_avg,
    percentile_cont(0.25) within group (order by things.dist_calc) as p25,
    percentile_cont(0.5) within group (order by things.dist_calc) as p50,
    percentile_cont(0.75) within group (order by things.dist_calc) as p75
from (select * from cr_00_500 where quart_year in ('q2_2018','q3_2018','q4_2018','q1_2019','q2_2019','q3_2019')) things
group by vehicle_type, propulsion_type;

