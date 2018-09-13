# TLS Rotation
Instructions on how to rotate TLS CA and certs for a Tectonic cluster.

## Generate new certs and patches

#### Prerequisite

- `jq`
- `kubectl`
- `KUBECONFIG` kubeconfig of the cluster.
- `BASE_DOMAIN` base domain of the cluster, you might be able to retrieve it from the server addres in the kubeconfig, e.g. `https://${CLUSTER_NAME}-api.${BASE_DOMAIN}:443`
- `CLUSTER_NAME` name of the cluster, you might be able to retrieve it from the server addres in the kubeconfig, e.g. `https://${CLUSTER_NAME}-api.${BASE_DOMAIN}:443`

#### Run

```shell
export KUBECONFIG=PATH_TO_KUBECONFIG
export BASE_DOMAIN=example.com
export CLUSTER_NAME=my-cluster

./gencert.sh generated
```

## Rotate Etcd CA and certs

#### Prerequisite

- `kubectl`
- `KUBECONFIG` kubeconfig of the cluster.
- `MASTER_IPS` List of public IPs of the master nodes, separated by space.
- `ETCD_IPS` List of private IPs of the etcd nodes, seperated by space.
- `SSH_KEY` The ssh key for login in the master nodes.

#### Run

```shell
export KUBECONFIG=PATH_TO_KUBECONFIG
export MASTER_IPS="IP1 IP2 ..."
export ETCD_IPS="IP1 IP2 ..."
export SSH_KEY="/home/.ssh/id_rsa"

./rotate_etcd.sh
```

## Rotate CA and certs in the cluster

#### Prerequisite

- `kubectl`
- `KUBECONFIG` kubeconfig of the cluster.
- `MASTER_IPS` List of public IPs of the master nodes, separated by space.
- `WORKER_IPS` List of private IPs of the worker nodes, separated by space.
- `SSH_KEY` The ssh key for login in the master nodes.

#### Run

```shell
export KUBECONFIG=PATH_TO_KUBECONFIG
export MASTER_IPS="IP1 IP2 ..."
export WORKER_IPS="IP1 IP2 ..."
export SSH_KEY="/home/.ssh/id_rsa"

./rotate_cluster.sh
```

#### NOTE
In order to rotate the kubelet certs, the kubeconfig on host needs to be updated.
On AWS platform, this will be achieved by replacing the kubeconfig file
hosted on the S3 bucket with the generated kubeconfig at `./generated/auth/kubeconfig`

A simple script (`aws/update_kubeconfig.sh`) is also provided for the task.

## Reboot Cluster

After updating the CA and certs of the API server, we need to restart all the pods
to ensure they refresh their service account.

This can be done by reboot all the nodes in the cluster.

A script (`./reboot_helper.sh`) is provided to make the step easier.
Once the reboot is done, the pods will come back eventually.
At this point, the CA rotation is fully completed.
