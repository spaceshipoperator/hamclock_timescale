drop table if exists satellite_metrics cascade;

create table satellite_metrics (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	m_sat_name text,
	m_name text,
	m_value text);

select create_hypertable('satellite_metrics', 'at_time');

alter table satellite_metrics set (timescaledb.compress,
	timescaledb.compress_orderby = 'at_time DESC',
	timescaledb.compress_segmentby = 'm_sat_name');

select remove_compression_policy('satellite_metrics');
select add_compression_policy('satellite_metrics', interval '1 week');

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

alter table satellite_pass_predictions set (timescaledb.compress,
	timescaledb.compress_orderby = 'at_time DESC',
	timescaledb.compress_segmentby = 'p_sat_name');

select remove_compression_policy('satellite_pass_predictions');
select add_compression_policy('satellite_pass_predictions', interval '1 week');

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

select add_continuous_aggregate_policy('satellite_min_range_per_hour'
    , start_offset => interval '1 week'
    , end_offset => interval '1 day'
    , schedule_interval => interval '1 hour');

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

create table major_world_cities_lat_long (city text, lat_1 text, lat_2 text, lon_1 text, lon_2 text, time text);

create table major_na_cities_lat_long (city text, lat_1 text, lat_2 text, lon_1 text, lon_2 text, time text);
/**
-- get data from and save to csv: https://www.infoplease.com/geography/major-cities-latitude-longitude-and-corresponding-time-zones
-- fix header, then
\copy major_world_cities_lat_long from ./major_world_cities_lat_long.csv with (format csv, delimiter E'\t', header);

\copy major_na_cities_lat_long from ./major_na_cities_lat_long.csv with (format csv, delimiter E'\t', header);
**/

create or replace view v_major_cities_lat_long as (
with c as (
select floor(10000*random()) ord, city
    , lat_1 lat, '-' || lon_1 lon
from major_na_cities_lat_long
union all
select floor(10000*random()) ord, city
    , case when lat_2 like '%S%' then '-' else '' end || lat_1 lat
    , case when lon_2 like '%W%' then '-' else '' end || lon_1 lon
from major_world_cities_lat_long
order by ord )
select city, lat, lon from c);

create table dx_metrics (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	d_city text,
	d_name text,
	d_value text);

select create_hypertable('dx_metrics', 'at_time');

alter table dx_metrics set (timescaledb.compress,
	timescaledb.compress_orderby = 'at_time DESC',
	timescaledb.compress_segmentby = 'd_city');

select remove_compression_policy('dx_metrics');
select add_compression_policy('dx_metrics', interval '1 week');

create or replace function ins_dx_metric (
	in_d_city text,
	in_d_name text,
	in_d_value text )
returns setof dx_metrics
language plpgsql
as $_$
begin
	return query
	insert into dx_metrics (d_city, d_name, d_value)
	values (trim(in_d_city), trim(in_d_name), trim(in_d_value))
	returning * ;
end;
$_$;

create table livespots (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	age_s integer,
	txcall text,
	txgrid text,
	rxcall text,
	rxgrid text,
	s_mode text,
	lat decimal,
	lng decimal,
	hz integer,
	snr integer );

select create_hypertable('livespots', 'at_time');

alter table livespots set (timescaledb.compress,
	timescaledb.compress_orderby = 'at_time DESC',
	timescaledb.compress_segmentby = 'txcall');

select remove_compression_policy('livespots');
select add_compression_policy('livespots', interval '1 week');

create table ontheair (
	client_addr inet not null default inet_client_addr(),
	server_addr inet not null default inet_server_addr(),
	at_time timestamptz not null default now(),
	khz real,
	call text,
	utc text,
	mode text,
	grid text,
	lat decimal,
	lng decimal,
	dedist text,
	debearing text,
	ext text);

select create_hypertable('ontheair', 'at_time');

alter table ontheair set (timescaledb.compress,
	timescaledb.compress_orderby = 'at_time DESC',
	timescaledb.compress_segmentby = 'call');

select remove_compression_policy('ontheair');
select add_compression_policy('ontheair', interval '1 week');

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
