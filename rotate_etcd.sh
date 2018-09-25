#!/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function usage() {
    >&2 cat << EOF
Usage: ./rotate_etcd.sh

Set the following environment variables to run this script:
    KUBECONFIG          The path to the kubeconfig file of the cluster.
                        
    MASTER_IPS          The list of public IPs of the master nodes, separated by space
                        
    ETCD_IPS            The list of private IPs of the etcd nodes, separated by space

    SSH_KEY             The path to the ssh private key that allows to login the master nodes

EOF
    exit 1
}

function restart_apiserver() {
    echo "restart API Server"
    kubectl delete pod -l k8s-app=kube-apiserver -n kube-system || true
    running_pods=0
    terminating_pods=0
    until [[ $running_pods > 0 && $terminating_pods == 0 ]]; do
        running_pods=$(kubectl get pods -l k8s-app=kube-apiserver -n kube-system --field-selector=status.phase=Running 2>/dev/null | wc -l || true)
        terminating_pods=$(kubectl get pods -l k8s-app=kube-apiserver -n kube-system --field-selector=status.phase=Terminating 2>/dev/null | wc -l || true)
        echo "running pods: $running_pods, terminating pods: $terminating_pods"
        sleep 5
    done

    echo "API Server restarted"
}


kubectl=${DIR}/kubectl

if [ -z "$KUBECONFIG" ]; then
    usage
fi

if [ -z "$MASTER_IPS" ]; then
    usage
fi

if [ -z "$ETCD_IPS" ]; then
    usage
fi

if [ -z "$SSH_KEY" ]; then
    usage
fi

set -u

echo "update etcd CA"
kubectl patch -f ./generated/patches/etcd/etcd-ca.patch -p "$(cat ./generated/patches/etcd/etcd-ca.patch)"

sleep 10

restart_apiserver

master_ip_list=($MASTER_IPS)
master_ip=${master_ip_list[0]}

# Copy ./generated dir to one of the master node
echo "copy assets into master nodes"
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -r generated core@${master_ip}:


# Update certs on etcd nodes.
for ADDR in $ETCD_IPS; do
    echo "update etcd CA on node $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "scp -o StrictHostKeyChecking=no generated/tls/etcd/old_new_ca.crt core@$ADDR:/home/core/ca.crt"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR sudo chown etcd:etcd /home/core/ca.crt"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR sudo cp -r /etc/ssl/etcd /etc/ssl/etcd.bak"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR sudo mv /home/core/ca.crt /etc/ssl/etcd/ca.crt"
    echo "restart etcd on node $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR sudo systemctl restart etcd-member"
    echo "etcd on node $ADDR restarted"
    sleep 10
done

echo "update etcd client certs"
kubectl patch -f ./generated/patches/etcd/etcd-client-cert.patch -p "$(cat ./generated/patches/etcd/etcd-client-cert.patch)"

sleep 10

restart_apiserver

# Update peer certs on etcd nodes.
for ADDR in $ETCD_IPS; do
    echo "update etcd peer certs on node $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "scp -o StrictHostKeyChecking=no \
        generated/tls/etcd/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key} core@$ADDR:/home/core"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR \
        sudo chown etcd:etcd /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key}"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR \
        sudo chmod 0400 /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key}"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR \
        sudo mv /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key} /etc/ssl/etcd/"
    echo "restart etcd on node $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@${master_ip} "ssh -o StrictHostKeyChecking=no core@$ADDR sudo systemctl restart etcd-member"
    echo "etcd on node $ADDR restarted"
    sleep 10
done

echo
echo "etcd CA and certs are succesfully rotated!"
