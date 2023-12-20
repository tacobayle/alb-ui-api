#!/bin/bash
#
# /bin/bash federated-pki-profile.sh
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
directory=$(jq -c -r '.openssl.directory' $jsonFile)
ca_name=$(jq -c -r '.openssl.ca.name' $jsonFile)
#
rm -f results.json
results_json="[]"
#
rm -f avi_cookie.txt
IFS=$'\n'

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
avi_cookie_file="../../backend/federated-pki-profile/avi_cookie.txt"

json_data='
{
  "ca_certs": [
    {
      "certificate": "'$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.crt)'"
    }
  ],
  "crl_check": false,
  "ignore_peer_chain": false,
  "is_federated": true,
  "name": "gslb_pki",
  "validate_only_leaf_crl": false
}'

echo "++++ create federated PKI"
alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "admin" "${gslb_controller_version}" "${json_data}" "${gslb_controller_ip}" "api/pkiprofile"
if [[ $response_code == 2[0-9][0-9] ]] ; then
  pkiprofile_url=$(echo $response_body | jq -c -r .url)
  results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "pkiprofile", "url": "'${pkiprofile_url}'", "status": "created" }]')
else
  results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${gslb_controller_ip}'", "object_type": "pkiprofile", "url": "na", "status": "error" }]')
fi

echo "------------------ Results"

echo $results_json | tee results.json | jq .