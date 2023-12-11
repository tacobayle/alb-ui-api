#!/bin/bash
#
rm -f results.json
jsonFile=../../json/data.json
#
results_json=$(jq -c -r '.global.app_type | map(select(any) | .name)' $jsonFile)
echo $results_json | tee results.json | jq .
