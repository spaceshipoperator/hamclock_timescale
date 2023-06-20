drop table if exists satellite_metrics cascade;

create table satellite_metrics (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	m_sat_name text,
	m_name text,
	m_value text);

select create_hypertable('satellite_metrics', 'at_time');

drop table if exists satellite_pass_predictions;

create table satellite_pass_predictions (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	p_sat_name text,
	p_day text,
	p_rise_time text,
	p_rise_az text,
	p_set_time text,
	p_set_az text,
	p_up_duration text);

select create_hypertable('satellite_pass_predictions', 'at_time');

create or replace function ins_sat_metric (
	in_m_sat_name text,
	in_m_name text,
	in_m_value text ) 
returns setof satellite_metrics
language plpgsql
as $_$
begin
	return query 
	insert into satellite_metrics (m_sat_name, m_name, m_value)
	values (trim(in_m_sat_name), trim(in_m_name), trim(in_m_value))
	returning * ;
end;
$_$;

create or replace function ins_sat_pass_prediction (
	in_p_sat_name text,
	in_p_day text,
	in_p_rise_time text,
	in_p_rise_az text,
	in_p_set_time text,
	in_p_set_az text,
	in_p_up_duration text )
returns setof satellite_pass_predictions
language plpgsql
as $_$
begin 
	return query
	insert into satellite_pass_predictions (
		p_sat_name, p_day, p_rise_time, p_rise_az,
		p_set_time, p_set_az, p_up_duration )
	values (
		trim(in_p_sat_name), trim(in_p_day), trim(in_p_rise_time), trim(in_p_rise_az),
		trim(in_p_set_time), trim(in_p_set_az), trim(in_p_up_duration) )
	returning * ;
end;
$_$;

drop materialized view if exists satellite_min_range_per_hour;

create materialized view satellite_min_range_per_hour
with (timescaledb.continuous) as
select time_bucket('1 hour', s.at_time) time_bucket_1h
    , s.m_sat_name sat_name
    , min(replace(s.m_value, ' km', '')::numeric) min_range
from satellite_metrics s
where s.m_name = 'Range'
and replace(s.m_value, ' km', '') ~ '^[0-9\.]+$'
group by 1, 2
with no data;

create or replace view v_satellite_min_range_per_hour as
with c as (
	    select time_bucket_1h, min(min_range) c_range
	    from satellite_min_range_per_hour
	    group by time_bucket_1h order by 1 desc)
select s.*
from satellite_min_range_per_hour s
join c on c.time_bucket_1h = s.time_bucket_1h
and c.c_range = s.min_range
order by s.time_bucket_1h desc, s.sat_name;

create or replace function str_day_dow(in_str text)
returns int
language plpgsql
as $_$
declare out_int int;
begin
        select case in_str
        when 'Sun' then 0
        when 'Mon' then 1
        when 'Tue' then 2
        when 'Wed' then 3
        when 'Thu' then 4
        when 'Fri' then 5
        when 'Sat' then 6
        else -1 end
        into out_int;

        return out_int;
end;
$_$;

/***
with c1 as (
select make_interval(hours => coalesce(nullif(trim(split_part(p_rise_time, 'h', 1)), ''), '0')::int
        , mins => coalesce(nullif(trim(split_part(p_rise_time, 'h', 2)), ''), '0')::int) c_rise_time
    , make_interval(hours => coalesce(nullif(trim(split_part(p_set_time, 'h', 1)), ''), '0')::int
        , mins => coalesce(nullif(trim(split_part(p_set_time, 'h', 2)), ''), '0')::int) c_set_time
    , extract(dow from at_time) dow_at_time, str_day_dow(p_day) dow_p_day, 0 dow_mod, *
from satellite_pass_predictions where p_sat_name = 'RS-30' and to_char(at_time, 'yyyy-mm-dd hh:mi') = '2023-02-08 10:13' order by at_time)
    , c2 as (
select coalesce(lag(c1.dow_p_day, 1) over (order by c1.at_time), c1.dow_p_day) lag_dow_p_day, c1.* from c1)
select c2.* from c2;
***/
