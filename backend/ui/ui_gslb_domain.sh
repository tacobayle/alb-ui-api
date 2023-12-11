#!/bin/bash
#
rm -f results.json
jsonFile=../../json/data.json
#
results_json=$(jq -c -r '.gslb.domain_name' $jsonFile)
echo $results_json | tee results.json | jq .
