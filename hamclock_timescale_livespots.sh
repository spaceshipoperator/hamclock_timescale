#!/bin/bash
source ./hamtime.env

curl $HAM_REST_URL/get_livespots.txt | sed 's/ \{1,\}/,/g' | sed 's/^,//g' | psql $TS_URL -c "\copy livespots (age_s, txcall, txgrid, rxcall, rxgrid, s_mode, lat, lng, hz, snr) from stdin with (format csv, header);"
