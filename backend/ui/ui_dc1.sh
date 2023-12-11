#!/bin/bash
#
rm -f results.json
jsonFile=../../json/data.json
#
results_json=$(jq -c -r '.ui.dc1' $jsonFile)
echo $results_json | tee results.json | jq .
