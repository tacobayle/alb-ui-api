#!/bin/bash
#
# /bin/bash cert-app.sh "internal-private" true true
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
IFS=$'\n'
#
app_type="${1}"
dc1="${2}"
dc2="${3}"
directory=$(jq -c -r '.openssl.directory' $jsonFile)
ca_name=$(jq -c -r '.openssl.ca.name' $jsonFile)
ca_private_key_passphrase=$(cat ${directory}/ca_private_key_passphrase.txt)
rm -f results.json
results_json="[]"
#
# App certificates creation
#
for item in $(jq -c -r .openssl.app_certificates[] $jsonFile)
do
  name=$(echo ${item} | jq -c -r .name)
  cn=$(echo ${item} | jq -c -r .cn)
  c=$(echo ${item} | jq -c -r .c)
  st=$(echo ${item} | jq -c -r .st)
  l=$(echo ${item} | jq -c -r .l)
  org=$(echo ${item} | jq -c -r .org)
  days=$(echo ${item} | jq -c -r .days)
  openssl req -new -nodes -out ${directory}/${name}.csr -newkey rsa:4096 -keyout ${directory}/${name}.key -subj '/CN='${cn}'/C='${c}'/ST='${st}'/L='${l}'/O='${org}''
  echo 'authorityKeyIdentifier=keyid,issuer
  basicConstraints=CA:FALSE
  keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
  subjectAltName = @alt_names
  [alt_names]
  ' | tee ${directory}/${name}.v3.ext
  count_dns=1
  for dns in $(echo ${item} | jq -c -r .san.dns[])
  do
    echo "DNS.${count_dns} = ${dns}" | tee -a ${directory}/${name}.v3.ext
    ((count_dns++))
  done
  count_ips=1
  for ip in $(echo ${item} | jq -c -r .san.ips[])
  do
    echo "IP.${count_ips} = ${ip}" | tee -a ${directory}/${name}.v3.ext
    ((count_ips++))
  done
  openssl x509 -req -in ${directory}/${name}.csr -CA ${directory}/${ca_name}.crt -passin pass:${ca_private_key_passphrase} -CAkey ${directory}/${ca_name}.key -CAcreateserial -out ${directory}/${name}.crt -days 730 -sha256 -extfile ${directory}/${name}.v3.ext
  #
  #
  #
  json_data='
  {
    "certificate": {
      "certificate": "'$(awk '{printf "%s\\n", $0}' ${directory}/${name}.crt)'"
    },
    "enable_ocsp_stapling": false,
    "format": "SSL_PEM",
    "import_key_to_hsm": false,
    "is_federated": false,
    "key": "'$(awk '{printf "%s\\n", $0}' ${directory}/${name}.key)'",
    "key_passphrase": "'${ca_private_key_passphrase}'",
    "name": "'${name}'",
    "type": "SSL_CERTIFICATE_TYPE_VIRTUALSERVICE"
  }'

  tenant=$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .tenant' $jsonFile)
  count=1
  for dc in $(jq -c -r .datacenters[] $jsonFile)
  do
    dc_status=dc$count
    rm -f avi_cookie.txt
    rm -f results.json

    if [[ $(eval "echo \"\$$dc_status\"") == "true" ]] ; then


      echo "------------------ DC$count"
      controller_ip=$(echo ${dc} | jq -c -r .controller_ip)
      alb_version=$(echo ${dc} | jq -c -r .version)

      curl_login=$(curl -s -k -X POST -H "Content-Type: application/json" \
                                      -d "{\"username\": \"$(echo ${dc} | jq -c -r .username)\", \"password\": \"$(echo ${dc} | jq -c -r .password)\"}" \
                                      -c avi_cookie.txt https://${controller_ip}/login)

      csrftoken=$(cat avi_cookie.txt | grep csrftoken | awk '{print $7}')
      avi_cookie_file="../../backend/cert-app/avi_cookie.txt"

      echo "++++ create cert App"
      alb_api 2 1 "POST" "${avi_cookie_file}" "${csrftoken}" "${tenant}" "${alb_version}" "${json_data}" "${controller_ip}" "api/sslkeyandcertificate"
      if [[ $response_code == 2[0-9][0-9] ]] ; then
        sslkeyandcertificate_url=$(echo $response_body | jq -c -r .url)
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "sslkeyandcertificate", "url": "'${sslkeyandcertificate_url}'", "status": "created" }]')
      else
        results_json=$(echo $results_json | jq '. += [{"date": "'$(date)'", "controller_ip": "'${controller_ip}'", "object_type": "sslkeyandcertificate", "url": "na", "status": "error" }]')
      fi
    fi

    ((count++))
  done

done
#
#
#
echo "------------------ Results"

echo $results_json | tee results.json | jq .