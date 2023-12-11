#!/bin/bash
# with waf // active-active
# /bin/bash create-lbaas.sh internal-private demo true active-active gslb.alb.com true true true 100.64.130.203,100.64.130.204 100.100.21.11,100.100.21.12
# with waf // geo-location
# /bin/bash create-lbaas.sh internal-private demo true geo-location gslb.alb.com true true true 100.64.130.203,100.64.130.204 100.100.21.11,100.100.21.12
# without waf // active-active
# /bin/bash create-lbaas.sh internal-private demo true active-active gslb.alb.com false true true 100.64.130.203,100.64.130.204 100.100.21.11,100.100.21.12
# with waf // disaster-recovery
# /bin/bash create-lbaas.sh internal-private demo true disaster-recovery gslb.alb.com true true true 100.64.130.203,100.64.130.204 100.100.21.11,100.100.21.12
# without waf // disaster-recovery
# /bin/bash create-lbaas.sh internal-private demo true disaster-recovery gslb.alb.com false true true 100.64.130.203,100.64.130.204 100.100.21.11,100.100.21.12
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
app_type="${1}"
dns_host="${2}"
gslb_enabled="${3}"
gslb_algorithm="${4}"
gslb_domain="${5}"
waf="${6}"
dc1="${7}"
dc2="${8}"
servers_ips_dc1="${9}"
servers_ips_dc2="${10}"
#
global_prefix=$(jq -c -r .prefixes.global_prefix $jsonFile)
global_prefix_pool=$(jq -c -r .prefixes.prefix_pool $jsonFile)
global_prefix_vsvip=$(jq -c -r .prefixes.prefix_vsvip $jsonFile)
global_prefix_vs=$(jq -c -r .prefixes.prefix_vs $jsonFile)
#
IFS=$'\n'
count=1
gslb_details="[]"
rm -f results.json
results_json="[]"
tenant=$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .tenant' $jsonFile)
#
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
    avi_cookie_file="../../backend/lbaas/avi_cookie.txt"

    echo "++++ retrieve cluster uuid"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/cluster"
    cluster_uuid=$(echo $response_body | jq -c -r --arg tenant "${tenant}" '.uuid')
    echo "  ${cluster_uuid}"

    echo "++++ retrieve tenant url"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/tenant"
    tenant_url=$(echo $response_body | jq -c -r --arg tenant "${tenant}" '.results[] | select( .name == $tenant ) | .url')
    echo "  ${tenant_url}"

    echo "++++ retrieve cloud details"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/cloud"
    cloud_url=$(echo $response_body | jq -c -r --arg cloud_dc "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud')" '.results[] |
                                               select( .name == $cloud_dc ) | .url')
    echo "  ${cloud_url}"

    if [[ $(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud_type') == "nsx" ]] ; then
      echo "  retrieve ter1s url"
      nsx_url=$(echo $response_body | jq -c -r --arg cloud_dc "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud')" \
                                               '.results[] | select( .name == $cloud_dc ) | .nsxt_configuration.nsxt_url')
      nsx_credentials_ref=$(echo $response_body | jq -c -r --arg cloud_dc "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud')" \
                                                           '.results[] | select( .name == $cloud_dc ) | .nsxt_configuration.nsxt_credentials_ref')
      json_data='
      {
        "host": "'${nsx_url}'",
        "credentials_uuid": "'$(basename ${nsx_credentials_ref})'"
      }'

      alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "${json_data}" "${controller_ip}" "api/nsxt/tier1s"
      tier1s_url=$(echo $response_body | jq -c -r --arg tier1_name "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .tier1')" \
                                                  '.resource.nsxt_tier1routers[] | select( .name == $tier1_name ) | .id')
      echo "  ${tier1s_url}"
    fi

    echo "++++ retrieve network url"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/network?page_size=-1"
    network_url=$(echo $response_body | jq -c -r --arg network_name "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .network_name')" \
                                                 --arg cloud "${cloud_url}" \
                                                 '.results[] | select( .name == $network_name and .cloud_ref == $cloud) | .url')

    echo "  ${network_url}"

    echo "++++ retrieve service engine group url"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/serviceenginegroup"
    seg_url=$(echo $response_body | jq -c -r --arg seg "$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .serviceenginegroup')" \
                                             --arg cloud "${cloud_url}" \
                                             '.results[] | select( .name == $seg and .cloud_ref == $cloud) | .url')
    echo "  ${seg_url}"

    echo "++++ retrieve service application profile url"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/applicationprofile"
    applicationprofile_url=$(echo $response_body | jq -c -r --arg applicationprofile "$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .applicationprofile' $jsonFile)" \
                                                            '.results[] | select( .name == $applicationprofile) | .url')
    echo "  ${applicationprofile_url}"

    echo "++++ retrieve application persistence profile url"
    alb_api 2 1 "GET" "${avi_cookie_file}" "${csrftoken}" "admin" "${alb_version}" "" "${controller_ip}" "api/applicationpersistenceprofile"
    persitence_url=$(echo $response_body | jq -c -r --arg applicationpersistenceprofile "$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .applicationpersistenceprofile' $jsonFile)" \
                                                    '.results[] | select( .name == $applicationpersistenceprofile) | .url')
    echo "  ${persitence_url}"

    echo "++++ pool creation"
    servers_dc=servers_ips_dc$count
    servers_dc_json=$(jq -R '(./"," | map({ip: { addr: ., type: "V4"}}))' <<< $(eval "echo \"\$$servers_dc\""))
    json_data='
    {
      "cloud_ref": "'${cloud_url}'",
      "name": "'${global_prefix}-${global_prefix_pool}-${dns_host}'",
      "servers": '$(echo $servers_dc_json | jq -c -r .)',
      "application_persistence_profile_ref": "'${persitence_url}'"
    }'
    if [[ $(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud_type') == "nsx" ]] ; then
      echo "  adding tier1 info"
      json_data=$(echo $json_data | jq '. += {"tier1_lr": "'${tier1s_url}'"}')
    fi
    alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "${json_data}" "${controller_ip}" "api/pool"
    pool_url=$(echo $response_body | jq -c -r .url)
    echo "  ${pool_url}"
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "pool", "url": "'${pool_url}'", "status": "created" }]')
    else
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "pool", "url": "na", "status": "error" }]')
    fi

    echo "++++ vsvip creation"
    json_data='
    {
       "cloud_ref": "'${cloud_url}'",
       "name": "'${global_prefix}'-'${global_prefix_vsvip}'-'${dns_host}'",
       "vip":
       [
         {
           "auto_allocate_ip": true,
           "ipam_network_subnet":
           {
             "network_ref": "'${network_url}'",
             "subnet":
             {
               "mask": "'$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .subnet_cidr' | cut -d"/" -f2)'",
               "ip_addr":
               {
                 "type": "V4",
                 "addr": "'$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .subnet_cidr' | cut -d"/" -f1)'"
               }
             }
           }
         }
       ],
       "dns_info":
       [
         {
           "fqdn": "'${dns_host}'.'$(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .domain')'"
         }
       ]
    }'
    if [[ $(echo $item | jq -c -r --arg app_type ${app_type} '.app_type[] | select( .name == $app_type ) | .cloud_type') == "nsx" ]] ; then
      echo "  adding tier1 info"
      json_data=$(echo $json_data | jq '. += {"tier1_lr": "'${tier1s_url}'"}')
    fi
    alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "${json_data}" "${controller_ip}" "api/vsvip"
    vsvip_url=$(echo $response_body | jq -c -r .url)
    vsvip_ip=$(echo $response_body | jq -c -r .vip[0].ip_address.addr)
    echo "  ${vsvip_url}"
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "vsvip", "url": "'${vsvip_url}'", "status": "created" }]')
    else
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "vsvip", "url": "na", "status": "error" }]')
    fi

    echo "++++ vs creation"
    json_data='
    {
       "cloud_ref": "'${cloud_url}'",
       "name": "'${global_prefix}'-'${global_prefix_vs}'-'${dns_host}'",
       "vsvip_ref": "'${vsvip_url}'",
       "pool_ref": "'${pool_url}'",
       "application_profile_ref": "'${applicationprofile_url}'",
       "application_profile_ref": "'${applicationprofile_url}'",
       "services": [
         {
           "port": 80,
           "enable_ssl": false
         },
         {
           "port": 443,
           "enable_ssl": true
         }
       ],
       "se_group_ref": "'${seg_url}'"
    }'
    if [[ ${waf} == "true" ]] ; then
      json_data=$(echo $json_data | jq '. += {"waf_policy_ref": "/api/wafpolicy/?name='$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .wafpolicy' $jsonFile)'"}')
    fi
    alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "${json_data}" "${controller_ip}" "api/virtualservice"
    vs_url=$(echo $response_body | jq -c -r .url)
    echo "  ${vs_url}"
    if [[ $response_code == 2[0-9][0-9] ]] ; then
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "virtualservice", "url": "'${vs_url}'", "status": "created" }]')
    else
      results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "virtualservice", "url": "na", "status": "error" }]')
    fi

    gslb_details=$(echo $gslb_details | jq '. += [{"cluster_uuid": "'${cluster_uuid}'", "vs_uuid": "'$(basename ${vs_url} | cut -d"#" -f1)'", "vsvip_ip": "'${vsvip_ip}'", "dc": "'$(echo $item | jq -c -r '.dc')'"}]')
  fi
  ((count++))
done

#
# gslb config.
#

if [[ ${gslb_enabled} == 'true' && ${dc1} == 'true' && ${dc2} == 'true' ]] ; then
  echo "------------------ GSLB"
  rm -f avi_cookie.txt
  rm -f results.json
  gslb_controller_ip=$(jq -c -r .gslb.gslb_leader $jsonFile)
  gslb_controller_username=$(jq --arg gslb_controller_ip ${gslb_controller_ip} -c -r \
                                '.datacenters[] | select( .controller_ip == $gslb_controller_ip ) | .username' $jsonFile)
  gslb_controller_password=$(jq --arg gslb_controller_ip ${gslb_controller_ip} -c -r \
                                '.datacenters[] | select( .controller_ip == $gslb_controller_ip ) | .password' $jsonFile)
  gslb_controller_version=$(jq --arg gslb_controller_ip ${gslb_controller_ip} -c -r \
                                '.datacenters[] | select( .controller_ip == $gslb_controller_ip ) | .version' $jsonFile)

  curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                  -d "{\"username\": \"${gslb_controller_username}\", \"password\": \"${gslb_controller_password}\"}" \
                                  -c avi_cookie.txt https://${gslb_controller_ip}/login)
  csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
  avi_cookie_file="../../backend/lbaas/avi_cookie.txt"
  #
  # disaster-recovery use case
  #
  groups_json="[]"
  if [[ ${gslb_algorithm} == 'disaster-recovery' ]] ; then
    echo "++++ disaster-recovery use case"
    pool_count=1
    for item in $(echo $gslb_details | jq -c -r .[])
    do
      if [[ $(echo $item | jq -c -r .dc) == $(jq -c -r .gslb.gslb_primary_dc $jsonFile) ]] ; then
        groups_json=$(echo $groups_json | jq '. += [{"name": "pool-'${pool_count}'-'$(echo $item | jq -c -r .dc)'", "priority": 20, "members": [{"cluster_uuid": "'$(echo $item | jq -c -r .cluster_uuid)'", "vs_uuid": "'$(echo $item | jq -c -r .vs_uuid)'", "ip": {"addr": "'$(echo $item | jq -c -r .vsvip_ip)'", "type": "V4"}}]}]')
      else
        groups_json=$(echo $groups_json | jq '. += [{"name": "pool-'${pool_count}'-'$(echo $item | jq -c -r .dc)'", "priority": 10, "members": [{"cluster_uuid": "'$(echo $item | jq -c -r .cluster_uuid)'", "vs_uuid": "'$(echo $item | jq -c -r .vs_uuid)'", "ip": {"addr": "'$(echo $item | jq -c -r .vsvip_ip)'", "type": "V4"}}]}]')
      fi
      ((pool_count++))
    done
    json_data='
    {
      "name": "'${dns_host}'",
      "ttl": 0,
      "domain_names": ["'${dns_host}'.'${gslb_domain}'"],
      "pool_algorithm": "GSLB_SERVICE_ALGORITHM_PRIORITY",
      "groups": '${groups_json}'
    }'

  fi
  #
  # active-active use case or geo-location
  #
  members_json="[]"
  if [[ ${gslb_algorithm} == 'active-active' || ${gslb_algorithm} == 'geo-location' ]] ; then
    echo "++++ active-active or geo-location use case"
    for item in $(echo $gslb_details | jq -c -r .[])
    do
      members_json=$(echo $members_json | jq '. += [{"cluster_uuid": "'$(echo $item | jq -c -r .cluster_uuid)'", "vs_uuid": "'$(echo $item | jq -c -r .vs_uuid)'", "ip": {"addr": "'$(echo $item | jq -c -r .vsvip_ip)'", "type": "V4"}}]')
    done
    json_data='
    {
      "name": "'${dns_host}'",
      "ttl": 0,
      "domain_names": ["'${dns_host}'.'${gslb_domain}'"],
      "groups": [
        {
          "name": "pool1",
          "priority": 10,
          "members": '${members_json}'
        }
      ]
    }'
    if [[ ${gslb_algorithm} == 'geo-location' ]] ; then
      json_data=$(echo $json_data | jq '.groups[0] += {"algorithm": "GSLB_ALGORITHM_GEO"}')
    fi
  fi
  echo ${alb_version}
  alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${gslb_controller_version}" "${json_data}" "${gslb_controller_ip}" "api/gslbservice"
  gslbservice_url=$(echo $response_body | jq -c -r .url)
  echo "${gslbservice_url}"
  if [[ $response_code == 2[0-9][0-9] ]] ; then
    results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "gslbservice", "url": "'${gslbservice_url}'", "status": "created" }]')
  else
    results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "gslbservice", "url": "na", "status": "error" }]')
  fi

fi

echo "------------------ Results"

echo $results_json | tee results.json | jq .
