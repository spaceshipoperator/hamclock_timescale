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
