#!/bin/bash
#
source ../../bash/alb/alb_api.sh
#
controller_ip="10.41.134.178"
controller_username="admin"
curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${controller_username}\", \"password\": \"mjT_WchT=T0x_25\"}" \
                                -c avi_cookie.txt https://${controller_ip}/login)
#
csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
avi_cookie_file="../../backend/monitor_vs/avi_cookie.txt"
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/vimgrsevmruntime?page_size=-1"
json_se_runtime_list=$(echo $response_body | jq '.results | map(select(any) | {name,uuid,host})')
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "*" "${alb_version}" "" "${controller_ip}" "api/virtualservice?page_size=-1"
json_vs_list=$(echo $response_body | jq '.results | map(select(.vip_runtime[0].se_list | length > 1 ) | {name,uuid,vip_runtime})')
IFS=$'\n'
for item in $(echo $json_vs_list | jq -c -r .[])
do
  list_host_per_vs="[]"
  for se in $(echo $item | jq -c -r .vip_runtime[0].se_list[])
  do
    vs_name=$(echo $item | jq -c -r .name)
    se_vm_name=$(basename $(echo $se | jq -c -r .se_ref) | sed -e 's/se-/sevm-/g')
    esx_host=$(echo ${json_se_runtime_list} | jq -c -r --arg arg ${se_vm_name} '.[] | select(.uuid == $arg) | .host')
    list_host_per_vs=$(echo ${list_host_per_vs} | jq '. += [{"host": "'${esx_host}'"}]')
  done
  if [[ $(echo $list_host_per_vs | jq --arg arg ${esx_host} '. | map(select(.host == $arg)) | length') -eq $(echo ${list_host_per_vs} | jq '. | length') ]] ; then
    echo "-----------------------------------"
    echo "vs called ${vs_name} has been placed on multiple SEs which are all on the top of ${esx_host}"
  fi
done