#!/bin/bash -e

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

KUBECTL=${DIR}/kubectl

ETCD_SANS_LENGTH=$(${KUBECTL} get endpoints etcd -n kube-system -ojson | jq -r '.subsets[0].addresses | length')

export ETCD_SANS=""
for ((i = 0 ; i < ${ETCD_SANS_LENGTH} ; i++ )); do
    let index=i+4
    export ETCD_SANS="${ETCD_SANS}DNS.${index} = \${ENV::CLUSTER_NAME}-etcd-${i}.\${ENV::BASE_DOMAIN}\n"
done

cat <<EOF > ${DIR}/openssl.conf

# environment variable values
BASE_DOMAIN=
CLUSTER_NAME=
CERT_DIR=
APISERVER_CLUSTER_IP=
APISERVER_URL=

[ ca ]
# \`man ca\`
default_ca = CA_default

[ CA_default ]
# Directory and file locations.
dir               = \${ENV::CERT_DIR}
certs             = \$dir
crl_dir           = \$dir/crl
new_certs_dir     = \$dir
database          = \$dir/index.txt
serial            = \$dir/serial
# certificate revocation lists.
crlnumber         = \$dir/crlnumber
crl               = \$dir/crl/intermediate-ca.crl
crl_extensions    = crl_ext
default_crl_days  = 30
default_md        = sha256

name_opt          = ca_default
cert_opt          = ca_default
default_days      = 375
preserve          = no
policy            = policy_loose

[ policy_loose ]
# Allow the CA to sign a range of certificates.
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
# \`man req\`
default_bits        = 4096
distinguished_name  = req_distinguished_name
string_mask         = utf8only
default_md          = sha256

[ req_distinguished_name ]
countryName                    = Country Name (2 letter code)
stateOrProvinceName            = State or Province Name
localityName                   = Locality Name
0.organizationName             = Organization Name
organizationalUnitName         = Organizational Unit Name
commonName                     = Common Name

# Certificate extensions (\`man x509v3_config\`)

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ client_cert ]
basicConstraints = CA:FALSE
nsCertType = client
nsComment = "OpenSSL Generated Client Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer
keyUsage = critical, nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth

[ server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[ identity_server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = DNS.1:tectonic-identity-api.tectonic-system.svc.cluster.local

[ etcd_server_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @etcd_alt_names

[ etcd_peer_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @etcd_alt_names

[ apiserver_cert ]
basicConstraints = CA:FALSE
nsCertType = server
nsComment = "OpenSSL Generated Server Certificate"
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid,issuer:always
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = \${ENV::APISERVER_ENDPOINT}
DNS.2 = kubernetes
DNS.3 = kubernetes.default
DNS.4 = kubernetes.default.svc
DNS.5 = kubernetes.default.svc.cluster.local
IP.1 = \${ENV::APISERVER_CLUSTER_IP}

[etcd_alt_names]
DNS.1 = *.kube-etcd.kube-system.svc.cluster.local
DNS.2 = kube-etcd-client.kube-system.svc.cluster.local
DNS.3 = *.\${ENV::BASE_DOMAIN}
`echo -e ${ETCD_SANS}`
EOF
