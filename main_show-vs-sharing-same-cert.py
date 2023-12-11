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
cors = CORS(app, resources={r"/*": {"origins": "*", "allow_headers": "*", "expose_headers": "*"}})
#
parser = reqparse.RequestParser()
parser.add_argument("tls_cert_name", type=str, help="SSL/TLS Certifiate name", required=True)
parser.add_argument("dc1", type=str, help="Is DC1 selected", required=True)
parser.add_argument("dc2", type=str, help="Is DC2 selected", required=True)


#
class show_vs_sharing_same_cert(Resource):

    def post(self):
        args = parser.parse_args()
        tls_cert_name = args['tls_cert_name']
        dc1 = args['dc1']
        dc2 = args['dc2']
        folder='backend/show-vs-sharing-same-cert'
        subprocess.call(['/bin/bash', 'show-vs-sharing-same-cert.sh', tls_cert_name, dc1, dc2], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)
        with open('backend/show-vs-sharing-same-cert/results.json', 'r') as results_json:
          results = json.load(results_json)
        return results, 201
        subprocess.call(['rm', 'results.json'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, cwd=folder)

api.add_resource(show_vs_sharing_same_cert, "/show-vs-sharing-same-cert")

#
# Main Python script
#
if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0")