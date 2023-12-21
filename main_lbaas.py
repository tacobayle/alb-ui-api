#!/usr/bin/env python3
import subprocess
import json
from flask import Flask
from flask_restful import Api, Resource, reqparse, abort
from flask_cors import CORS
import os
#
# create command:
# curl -X POST http://10.41.135.46:5000/show-vs-sharing-same-ssl-cert -d '{"username":"admin", "password":"34fc591ce14dbd1af74352e2dde497e1a000a6ce", "alb_controller_ip":"10.41.134.130","tls_cert_name":"System-Default-Cert-EC"}' -H "Content-Type: application/json"
# curl -X POST http://10.41.135.46:5000/show-vs-sharing-same-ssl-cert -d '{"username":"admin", "password":"34fc591ce14dbd1af74352e2dde497e1a000a6ce", "alb_controller_ip":"10.41.134.130","tls_cert_name":"System-Default-Cert"}' -H "Content-Type: application/json"
#
app = Flask(__name__)
api = Api(app)
cors = CORS(app)
#
# parser = reqparse.RequestParser()
# parser.add_argument("username", type=str, help="NSX ALB controller username", required=True)
# parser.add_argument("password", type=str, help="NSX ALB controller password or token", required=True)
# parser.add_argument("alb_controller_ip", type=str, help="NSX ALB controller IP", required=True)
# parser.add_argument("tls_cert_name", type=str, help="SSL/TLS Certifiate name", required=True)
#
parser_create_vs_multiple_dcs = reqparse.RequestParser()
parser_create_vs_multiple_dcs.add_argument("app_profile", type=str, help="NSX ALB App type", required=True)
parser_create_vs_multiple_dcs.add_argument("dns_host", type=str, help="DNS host name", required=True)
parser_create_vs_multiple_dcs.add_argument("gslb", type=str, help="GSLB", required=True)
parser_create_vs_multiple_dcs.add_argument("gslb_algorithm", type=str, help="GSLB Algorithm", required=True)
parser_create_vs_multiple_dcs.add_argument("gslb_domain", type=str, help="GSLB Algorithm", required=True)
parser_create_vs_multiple_dcs.add_argument("cert", type=str, help="Certificate Name", required=True)
parser_create_vs_multiple_dcs.add_argument("waf", type=str, help="App Waf", required=True)
parser_create_vs_multiple_dcs.add_argument("dc1", type=str, help="DC1 selected", required=True)
parser_create_vs_multiple_dcs.add_argument("dc2", type=str, help="DC2 selected", required=True)
parser_create_vs_multiple_dcs.add_argument("servers_ips_dc1", type=str, help="Comma Separated DC1 Servers IP", required=True)
parser_create_vs_multiple_dcs.add_argument("servers_ips_dc2", type=str, help="Comma Separated DC2 Servers IP", required=True)
#
# class show_vs_sharing_same_ssl_cert(Resource):
#
#     def post(self):
#         args = parser.parse_args()
#         username = args['username']
#         password = args['password']
#         alb_controller_ip = args['alb_controller_ip']
#         tls_cert_name = args['tls_cert_name']
#         folder='backend/show-vs-sharing-same-ssl-cert'
#         subprocess.call(['/bin/bash', 'show-vs-sharing-same-cert.sh', username, password, alb_controller_ip, tls_cert_name], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
#         with open('backend/show-vs-sharing-same-ssl-cert/results.json', 'r') as results_json:
#           results = json.load(results_json)
#         return results, 201
#         subprocess.call(['rm', 'results.json'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
# #
class create_vs_multiple_dcs(Resource):

    def post(self):
        args_parser_create_vs_multiple_dcs = parser_create_vs_multiple_dcs.parse_args()
        app_profile = args_parser_create_vs_multiple_dcs['app_profile']
        dns_host = args_parser_create_vs_multiple_dcs['dns_host']
        gslb = args_parser_create_vs_multiple_dcs['gslb']
        gslb_algorithm = args_parser_create_vs_multiple_dcs['gslb_algorithm']
        gslb_domain = args_parser_create_vs_multiple_dcs['gslb_domain']
        cert = args_parser_create_vs_multiple_dcs['cert']
        waf = args_parser_create_vs_multiple_dcs['waf']
        dc1 = args_parser_create_vs_multiple_dcs['dc1']
        dc2 = args_parser_create_vs_multiple_dcs['dc2']
        servers_ips_dc1 = args_parser_create_vs_multiple_dcs['servers_ips_dc1']
        servers_ips_dc2 = args_parser_create_vs_multiple_dcs['servers_ips_dc2']
        folder='/home/ubuntu/alb-ui-api/backend/lbaas'
        result=subprocess.call(['/bin/bash', 'create-lbaas.sh', app_profile, dns_host, gslb, gslb_algorithm, gslb_domain, cert, waf, dc1, dc2, servers_ips_dc1, servers_ips_dc2], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
        with open('/home/ubuntu/alb-ui-api/backend/lbaas/results.json', 'r') as results_json:
            results = json.load(results_json)
        return results, 201
        subprocess.call(['rm', '/home/ubuntu/alb-ui-api/backend/lbaas/results.json'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
#


# api.add_resource(show_vs_sharing_same_ssl_cert, "/show-vs-sharing-same-ssl-cert")
api.add_resource(create_vs_multiple_dcs, "/lbaas")

#
# Main Python script
#
if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")