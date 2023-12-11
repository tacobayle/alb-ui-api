#!/bin/bash
#
# /bin/bash delete-lbaas.sh internal-private demo true true
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
rm -f results.json
results_json="[]"
#
app_type="${1}"
dns_host="${2}"
dc1="${3}"
dc2="${4}"
#
global_prefix=$(jq -c -r .prefixes.global_prefix $jsonFile)
global_prefix_pool=$(jq -c -r .prefixes.prefix_pool $jsonFile)
global_prefix_vsvip=$(jq -c -r .prefixes.prefix_vsvip $jsonFile)
global_prefix_vs=$(jq -c -r .prefixes.prefix_vs $jsonFile)
tenant=$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .tenant' $jsonFile)
#
IFS=$'\n'
count=1
#
# gslb config.
#
echo "------------------ GSLB"
rm -f avi_cookie.txt
rm -f results.json
gslb_controller_ip=$(jq -c -r .gslb.gslb_leader $jsonFile)
gslb_controller_username=$(jq --arg gslb_controller_ip ${gslb_controller_ip} -c -r \
                              '.datacenters[] | select( .controller_ip == $gslb_controller_ip ) | .username' $jsonFile)
gslb_controller_password=$(jq --arg gslb_controller_ip ${gslb_controller_ip} -c -r \
                              '.datacenters[] | select( .controller_ip == $gslb_controller_ip ) | .password' $jsonFile)

curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                -d "{\"username\": \"${gslb_controller_username}\", \"password\": \"${gslb_controller_password}\"}" \
                                -c avi_cookie.txt https://${gslb_controller_ip}/login)

csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
avi_cookie_file="../../backend/lbaas/avi_cookie.txt"

echo "++++ retrieve gslbservice url"
alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${gslb_controller_ip}" "api/gslbservice"
gslbservice_url=$(echo $response_body | jq -c -r --arg gslbservice "${dns_host}" \
                                                 '.results[] | select( .name == $gslbservice ) | .url')
if [[ -z $gslbservice_url ]] ; then
  echo "no GSLB service to delete"
else
  echo "  ${gslbservice_url}"
  echo "++++ delete GSLB service"
  alb_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${gslb_controller_ip}" "$(echo ${gslbservice_url} | grep / | cut -d/ -f4-)"
  if [[ $response_code == 2[0-9][0-9] ]] ; then
    results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "gslbservice", "url": "'${gslbservice_url}'", "status": "deleted" }]')
  else
    results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "gslbservice", "url": "'${gslbservice_url}'", "status": "error" }]')
  fi
fi

rm -f avi_cookie.txt
rm -f results.json
for item in $(jq -c -r .datacenters[] $jsonFile)
do
  echo "------------------ DC$count"
  dc_status=dc$count
  if [[ $(eval "echo \"\$$dc_status\"") == "true" ]] ; then

    controller_ip=$(echo $item | jq -c -r .controller_ip)
    alb_version=$(echo $item | jq -c -r .version)

    curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                    -d "{\"username\": \"$(echo $item | jq -c -r .username)\", \"password\": \"$(echo $item | jq -c -r .password)\"}" \
                                    -c avi_cookie.txt https://${controller_ip}/login)

    csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
    avi_cookie_file="../../backend/lbaas/avi_cookie.txt"

    echo "++++ retrieve pool url"
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "api/pool?page_size=-1"
    pool_url=$(echo $response_body | jq -c -r --arg pool "${global_prefix}-${global_prefix_pool}-${dns_host}" \
                                              '.results[] | select( .name == $pool ) | .url')

    echo "++++ retrieve vsvip url"
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "api/vsvip?page_size=-1"
    vsvip_url=$(echo $response_body | jq -c -r --arg vsvip "${global_prefix}-${global_prefix_vsvip}-${dns_host}" \
                                              '.results[] | select( .name == $vsvip ) | .url')

    echo "++++ retrieve vs url"
    alb_api 3 5 "GET" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "api/virtualservice?page_size=-1"
    vs_url=$(echo $response_body | jq -c -r --arg vs "${global_prefix}-${global_prefix_vs}-${dns_host}" \
                                              '.results[] | select( .name == $vs ) | .url')

    if [[ -z $vs_url ]] ; then
      echo "no VS to delete"
    else
      echo "++++ delete VS"
      echo "  ${vs_url}"
      alb_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "$(echo ${vs_url} | grep / | cut -d/ -f4-)"
      if [[ $response_code == 2[0-9][0-9] ]] ; then
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "virtualservice", "url": "'${vs_url}'", "status": "deleted" }]')
      else
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "virtualservice", "url": "'${vs_url}'", "status": "error" }]')
      fi
    fi

    if [[ -z $pool_url ]] ; then
      echo "no pool to delete"
    else
      echo "++++ delete pool"
      echo "  ${pool_url}"
      alb_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "$(echo ${pool_url} | grep / | cut -d/ -f4-)"
      if [[ $response_code == 2[0-9][0-9] ]] ; then
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "pool", "url": "'${pool_url}'", "status": "deleted" }]')
      else
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "pool", "url": "'${pool_url}'", "status": "error" }]')
      fi
    fi

    if [[ -z $vsvip_url ]] ; then
      echo "no vsvip to delete"
    else
      echo "++++ delete vsvip"
      echo "  ${vsvip_url}"
      alb_api 3 5 "DELETE" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "" "${controller_ip}" "$(echo ${vsvip_url} | grep / | cut -d/ -f4-)"
      if [[ $response_code == 2[0-9][0-9] ]] ; then
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "vsvip", "url": "'${vsvip_url}'", "status": "deleted" }]')
      else
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "vsvip", "url": "'${vsvip_url}'", "status": "error" }]')
      fi
    fi

  fi
  ((count++))
done

echo $results_json | tee results.json | jq .
