# TLS Rotation
Instructions on how to rotate TLS CA and certs for a Tectonic cluster.

### Prerequisite

`jq`
`kubectl`
`kubeconfig`

## Generate new certs and patches

#### Prerequisite

- `jq`
- `kubectl`
- `kubeconfig`
- `KUBECONFIG BASE_DOMAIN CLUSTER_NAME`

```shell
export KUBECONFIG=PATH_TO_KUBECONFIG
export BASE_DOMAIN=example.com
export CLUSTER_NAME=my-cluster
./gencert.sh generated
...
Certs and patches generated!
```

## Rotate the CA and certs

#### Prerequisite

- MUST be able to ssh into the master, worker and etcd nodes
- `kubectl`
- `MASTER_IPS WORKER_IPS ETCD_IPS`

#### Update Etcd CA and certs




kubectl get secret kube-apiserver -n kube-system -ojson | jq -r '.data["ca.crt"]' | base64 -d > ${CERT_DIR}/old_new_ca.crt

kubectl get secret kube-apiserver -n kube-system -ojson | jq -r '.data["etcd-client-ca.crt"]' | base64 -d > ${ETCD_TLS}/old_new_ca.crt${CERT_DIR}/old_new_ca.crt

```shell
export APISERVER_CLUSTER_IP=10.3.0.1
export BASE_DOMAIN=example.coreos.com
export CLUSTER_NAME=my-cluster
./gencerts.sh generated
```
