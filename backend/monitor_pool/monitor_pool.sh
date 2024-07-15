#!/bin/bash
#
source ../../bash/alb/alb_api.sh
#
controller_ip="10.41.134.130"
controller_username="admin"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${controller_username}\", \"password\": \"${TF_VAR_avi_password}\"}" \
                                -c avi_cookie.txt https://${controller_ip}/login)
#
csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
avi_cookie_file="../../backend/monitor_pool/avi_cookie.txt"
pool_uuid="pool-4059cb28-963d-4d9e-b091-bbf454dad552"
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/pool/${pool_uuid}"
json_pool_ip_list=$(echo $response_body | jq '.servers | map(select(any) | .ip.addr)')
server_count=$(echo $json_pool_ip_list | jq '. | length')
if [[ ${server_count} -gt 1 ]] ; then
  echo "pool ip is: $(echo $json_pool_ip_list | jq . -c -r)"
  echo "server count is $server_count"
  default_server_port=$(echo $response_body | jq '.default_server_port')
  echo "default server port is $default_server_port"
  date_minus_5_minutes=$(date -d "-5 min" "+%Y-%m-%dT%H:%M:%S.000Z")
  alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/analytics/metrics/pool/${pool_uuid}/?metric_id=l7_server.avg_total_requests&step=500&limit=1&start=${date_minus_5_minutes}"
  pool_avg_total_requests=$(echo $response_body | jq '.series[0].data[0].value')
  echo "  ++++++++++++++++ pool is getting $pool_avg_total_requests requests per second over the last 5 minutes"
  for server in $(echo $json_pool_ip_list | jq -c -r .[])
  do
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/analytics/metrics/pool/${pool_uuid}/?metric_id=l7_server.avg_total_requests&server=${server}:${default_server_port}&step=500&limit=1&start=${date_minus_5_minutes}"
    pool_avg_total_requests_per_server=$(echo $response_body | jq '.series[0].data[0].value')
    echo "  ++++++++++++++++++++++++++++++++ server ${server} is getting ${pool_avg_total_requests_per_server} requests per second over the last 5 minutes"
    percentage_per_server=$(echo "scale=2; ${pool_avg_total_requests_per_server} / ${pool_avg_total_requests} * 100" | bc)
        echo "  ++++++++++++++++++++++++++++++++ request ratio for this server ${server} is: ${percentage_per_server} %"
  done
fi