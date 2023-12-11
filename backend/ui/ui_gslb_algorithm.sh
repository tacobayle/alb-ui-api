#!/bin/bash
#
rm -f results.json
jsonFile=../../json/data.json
#
results_json=$(jq -c -r '.ui.gslb_algotithm' $jsonFile)
echo $results_json | tee results.json | jq .
