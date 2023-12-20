#!/bin/bash
#
# /bin/bash cert-ca.sh "internal-private" true true
#
jsonFile=../../json/data.json
source ../../bash/alb/alb_api.sh
#
app_type="${1}"
dc1="${2}"
dc2="${3}"
directory=$(jq -c -r '.openssl.directory' $jsonFile)
ca_name=$(jq -c -r '.openssl.ca.name' $jsonFile)
CN=$(jq -c -r '.openssl.ca.cn' $jsonFile)
C=$(jq -c -r '.openssl.ca.c' $jsonFile)
ST=$(jq -c -r '.openssl.ca.st' $jsonFile)
L=$(jq -c -r '.openssl.ca.l' $jsonFile)
O=$(jq -c -r '.openssl.ca.org' $jsonFile)
key_size=4096
ca_cert_days=1826
#
IFS=$'\n'
count=1
rm -f results.json
results_json="[]"
#
# CA private key and cert creation
#
ca_private_key_passphrase=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12)
rm -fr ${directory}
mkdir ${directory}
echo ${ca_private_key_passphrase} | tee ${directory}/ca_private_key_passphrase.txt
openssl genrsa -aes256 -passout pass:${ca_private_key_passphrase} -out ${directory}/${ca_name}.key ${key_size}
openssl req -x509 -new -nodes -passin pass:${ca_private_key_passphrase} -key ${directory}/${ca_name}.key -sha256 -days ${ca_cert_days} -out ${directory}/${ca_name}.crt -subj '/CN='${CN}'/C='${C}'/ST='${ST}'/L='${L}'/O='${O}''
#
#
#
json_data='
{
  "certificate": {
    "certificate": "'$(awk '{printf "%s\\n", $0}' ${directory}/${ca_name}.crt)'"
  },
  "import_key_to_hsm": false,
  "is_federated": false,
  "type": "SSL_CERTIFICATE_TYPE_CA",
  "name": "'${CN}'"
}'
#
tenant=$(jq -c -r --arg app_type ${app_type} '.global.app_type[] | select( .name == $app_type ) | .tenant' $jsonFile)
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
    avi_cookie_file="../../backend/cert-ca/avi_cookie.txt"

    echo "++++ create cert CA"
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

echo "------------------ Results"

echo $results_json | tee results.json | jq .