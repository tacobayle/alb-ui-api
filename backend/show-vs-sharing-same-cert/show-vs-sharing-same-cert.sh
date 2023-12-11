#!/bin/bash
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
cert_name=$1
dc1=$2
dc2=$3
rm -f results.json
IFS=$'\n'
#
count=1
results_json="[]"
for item in $(jq -c -r .datacenters[] $jsonFile)
do
  dc_status=dc$count
  rm -f avi_cookie.txt
  rm -f results.json

  if [[ $(eval "echo \"\$$dc_status\"") == "true" ]] ; then
  echo "------------------ DC$count"

    controller_ip=$(echo $item | jq -c -r .controller_ip)
    alb_version=$(echo $item | jq -c -r .version)

    curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                    -d "{\"username\": \"$(echo $item | jq -c -r .username)\", \"password\": \"$(echo $item | jq -c -r .password)\"}" \
                                    -c avi_cookie.txt https://${controller_ip}/login)

    csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
    avi_cookie_file="../../backend/show-vs-sharing-same-cert/avi_cookie.txt"

    echo "++++ retrieve cert url"
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/sslkeyandcertificate"
    cert_uuid=$(echo $response_body | jq -c -r --arg cert_name "${cert_name}" '.results[] | select(.name == $cert_name) | .uuid')
    cert_url=$(echo $response_body | jq -c -r --arg cert_name "${cert_name}" '.results[] | select(.name == $cert_name) | .url')

    if [ -z "$cert_uuid" ] ; then
      echo "  no cert retrieved"
    else
      echo "  ${cert_url}"
#      alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/virtualservice/?refers_to=sslkeyandcertificate:${cert_uuid}&fields=name"
#      echo ${response_body}
      alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/virtualservice"
      result_json=$(echo $response_body | jq --arg cert_uuid "${cert_url}" '.results | map(select(.ssl_key_and_certificate_refs != null and .ssl_key_and_certificate_refs[] == $cert_uuid) | {name, url, tenant_ref}) ')
      result_json=$(echo $result_json | jq '.[] += {"date": "'$(date)'", "controller_ip": "'${controller_ip}'"}')
      results_json=$(echo $results_json | jq '. += ['$(echo ${result_json} | jq . -c -r)']')
    fi
    ((count++))
  fi
done

echo "------------------ Results"

echo $results_json | tee results.json | jq .


#rm -f avi_cookie.txt
#rm -f results.json
#
#curl_output=$(curl -s -k -X POST -H "Content-Type: application/json" -d "{\"username\": \"$username\", \"password\": \"$password\"}" -c avi_cookie.txt https://$ip/login)
#curl_cert=$(curl -s -k -X GET -H "Content-Type: application/json"  -b avi_cookie.txt https://$ip/api/sslkeyandcertificate)
#cert_short_uuid=$(echo $curl_cert | jq -c -r --arg cert_name "${cert_name}" '.results[] | select(.name == $cert_name) | .uuid')
#if [ -z "$cert_short_uuid" ] ; then
#  echo "[]" | jq -c -r . | tee results.json > /dev/null
#else
#  cert_full_uuid="https://${ip}/api/sslkeyandcertificate/${cert_short_uuid}"
#  curl_virtualservice=$(curl -s -k -X GET -H "Content-Type: application/json" -H "X-Avi-Tenant: *" -b avi_cookie.txt https://$ip/api/virtualservice)
#  echo $curl_virtualservice | jq -s -c -r --arg cert_uuid "${cert_full_uuid}" '.[].results[] |
#                                                            select( .ssl_key_and_certificate_refs != null ) |
#                                                            select (.ssl_key_and_certificate_refs[] == $cert_uuid) |
#                                                            {"name": .name, "uuid": .uuid, url: .url}' \
#                            | jq -s -c -r . | tee results.json > /dev/null
##  jq . results.json
#fi