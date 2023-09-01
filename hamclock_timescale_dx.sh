#!/bin/bash
source ./hamtime.env

while IFS=$'\t' read -r -a r_array ; do
	echo "city: ${r_array[0]}"
	echo "lat: ${r_array[1]}"
	echo "lng: ${r_array[2]}"

	printf -v cmd "psql $TS_URL <<EOF\n"
	while IFS= read -r n ; do
		c=""
		if [[ $n =~ (^(DX_prefix|DX_path_SP|DX_path_LP|DX_time|DX_tz|DX_lat|DX_lng|DX_grid|DX_MoonAz|DX_MoonEl|DX_MoonRise|DX_MoonSet|DX_MoonVel|DX_SunAz|DX_SunEl|DX_SunRise|DX_SunSet|DX_WxTemp|DX_WxPressure|DX_WxHumidity|DX_WxWindSpd|DX_WxWindDir|DX_WxClouds|DX_WxCondx|DX_WxFrom)) ]] ; then
			printf -v c "select ins_dx_metric('$(echo ${r_array[0]} | xargs echo -n)', '$(echo ${n%% *} | xargs echo -n)', '$(echo ${n#* } | sed 's/%//' | xargs echo -n)'); \n" ;
		fi
		cmd+=$c
	done < <(curl "$HAM_REST_URL/set_newdx?lat=$(echo ${r_array[1]} | xargs echo -n)&lng=$(echo ${r_array[2]} | xargs echo -n)") ; 
	cmd+="EOF"
	eval "$cmd"
	date && sleep 20 ;
done < <(tail -n +2 ./v_major_cities_lat_long.csv | shuf) ;
