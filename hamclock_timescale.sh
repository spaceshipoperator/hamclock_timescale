#!/bin/bash
source ./hamtime.env

EXCL_SAT_LIST="NO-104"

for cur_sat in $(curl $HAM_REST_URL/get_satellites.txt | grep -vE "^1|^2" | shuf) ; do
	sat_name=$(echo $cur_sat | tr -d '\r\n') ;
	if ! [[ "$EXCL_SAT_LIST" =~ (^|[[:space:]])"$sat_name"($|[[:space:]]) ]] ; then 
		echo "curl $HAM_REST_URL/set_satname?$sat_name" ; 
		printf -v cmd "psql $TS_URL <<EOF\n"
		while IFS= read -r n ; do 
			c=""
			if [[ $n =~ (^(Sat|Sun|Mon|Tue|Wed|Thu|Fri)) ]] ; then
				printf -v c "select ins_sat_pass_prediction('${sat_name}', '${n:0:3}', '${n:5:5}', '${n:12:3}', '${n:17:5}', '${n:24:3}', '${n:29:5}'); \n" ;
			elif [[ $n =~ (^(Alt|Az|Range|Rate|144MHzDoppler|440MHzDoppler|1.3GHzDoppler|10GHzDoppler|NextRiseIn|NextSetIn)) ]] ; then
				printf -v c "select ins_sat_metric('${sat_name}', '${n%% *}', '${n#* }'); \n" ;
			fi
			cmd+=$c
		done < <(curl $HAM_REST_URL/set_satname?$sat_name) ;
		cmd+="EOF"
		eval "$cmd"
		date && sleep 60 ;
	fi
done ;
