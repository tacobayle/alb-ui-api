#!/bin/bash
#
# /bin/bash ui_certs.sh > /dev/null
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
IFS=$'\n'
results_json="[]"
rm -f results.json
#
count=1
for item in $(jq -c -r .datacenters[] $jsonFile)
do
  echo "------------------ DC$count"
  rm -f avi_cookie.txt
  controller_ip=$(echo $item | jq -c -r .controller_ip)
  alb_version=$(echo $item | jq -c -r .version)

  curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                  -d "{\"username\": \"$(echo $item | jq -c -r .username)\", \"password\": \"$(echo $item | jq -c -r .password)\"}" \
                                  -c avi_cookie.txt https://${controller_ip}/login)

  csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
  avi_cookie_file="../../backend/ui/avi_cookie.txt"

  echo "++++ retrieve cert names"
  alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/sslkeyandcertificate"
  cert_names=$(echo $response_body | jq -c -r '.results | map(select(any) | .name)')
  results_json=$(echo $results_json | jq '. += '${cert_names}'')
  ((count++))
done
echo ${results_json} | jq '. | unique' | tee results.json
