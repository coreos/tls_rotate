# TLS Rotation
Instructions on how to rotate TLS CA and certs for a Tectonic cluster.

## Generate new certs and patches

#### Prepare

**CAUTION**: Before rotation, it's preferrable to back up your cluster:
1. On an etcd node, take a backup of the current state.
2. [Run bootkube recover](https://coreos.com/tectonic/docs/latest/troubleshooting/bootkube_recovery_tool.html) to extract the existing state from etcd. Copy this back to your working machine as a precaution, in case the control plane goes down.
3. Download the current kubeconfig and assets.zip.

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

./gencerts.sh generated
```

**CAUTION**: PLEASE save the generated assets somewhere, it's IMPORTANT for future reference!

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

A simple program (`aws/update_kubeconfig`) is also provided for the task:
```shell
./aws/update_kubeconfig --tfstate=PATH_TO_TFSTATE_FILE --kubeconfig=./generated/auth/kubeconfig
```

**PLEASE MAKE SURE THE KUBECONFIG IS UPDATED CORRECTLY, OTHERWISE THE ROTATION WILL FAIL!**

You can run the following command to verify:
```shell
aws s3 cp s3://S3_BUCKET_NAME/kubeconfig /tmp/kubeconfig
diff /tmp/kubeconfig generated/auth/kubeconfig
```

## Reboot Cluster

After updating the CA and certs of the API server, we need to restart all the pods
to ensure they refresh their service account.

This can be done by reboot all the nodes in the cluster.

A script (`./reboot_helper.sh`) is provided to make the step easier.
Once the reboot is done, the pods will come back eventually.
At this point, the CA rotation is fully completed.
