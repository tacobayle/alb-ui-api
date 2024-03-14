#!/bin/bash
#
source ../../bash/alb/alb_api.sh
#
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"admin\", \"password\": \"${TF_VAR_avi_password}\"}" \
                                -c avi_cookie.txt https://10.41.134.130/login)
#
csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
avi_cookie_file="../../backend/monitor_pool/avi_cookie.txt"
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/virtualservice"
echo $response_body | jq .