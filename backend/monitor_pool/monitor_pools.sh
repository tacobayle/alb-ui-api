#!/bin/bash
#
source ../../bash/alb/alb_api.sh
#
controller_ip="10.41.134.130"
controller_username="admin"
tolerance=0.8
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${controller_username}\", \"password\": \"${TF_VAR_avi_password}\"}" \
                                -c avi_cookie.txt https://${controller_ip}/login)
#
csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
avi_cookie_file="../../backend/monitor_pool/avi_cookie.txt"
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/virtualservice?page_size=-1"
json_vs_list=$(echo $response_body | jq '.results | map(select(.pool_ref != null) | {name,uuid,pool_ref})')
IFS=$'\n'
for item in $(echo $json_vs_list | jq -c -r .[])
do
  echo "-----------------------------------"
  echo "vs called $(echo $item | jq .name)"
  pool_uuid=$(basename $(echo $item | jq .pool_ref) | tr -d '"')
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
    echo ""
    echo ""
    echo "  ++++++++++++++++ pool is getting $pool_avg_total_requests requests per second over the last 5 minutes"
    min_server_expected=$(echo "scale=2; ${pool_avg_total_requests} / ${server_count} * ${tolerance}" | bc)
    for server in $(echo $json_pool_ip_list | jq -c -r .[])
    do
      alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/analytics/metrics/pool/${pool_uuid}/?metric_id=l7_server.avg_total_requests&server=${server}:${default_server_port}&step=500&limit=1&start=${date_minus_5_minutes}"
      pool_avg_total_requests_per_server=$(echo $response_body | jq '.series[0].data[0].value')
      percentage_per_server=$(echo "scale=2; ${pool_avg_total_requests_per_server} / ${pool_avg_total_requests} * 100" | bc)
      echo "  ++++++++++++++++ request ratio for this server ${server} is: ${percentage_per_server} %"
      echo ""
    done
    exit
  fi
done