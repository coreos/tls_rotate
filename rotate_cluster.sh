#!/bin/bash

set -eo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function usage() {
    >&2 cat << EOF
Usage: ./rotate_cluster.sh

Set the following environment variables to run this script:
    KUBECONFIG          The path to the kubeconfig file of the cluster.
                        
    MASTER_IPS          The list of public IPs of the master nodes, separated by space
                        
    WORKER_IPS          The list of private IPs of the worker nodes, separated by space

    SSH_KEY             The path to the ssh private key that allows to login the master nodes

EOF
    exit 1
}

function wait_apiserver() {
    running_pods=0
    terminating_pods=0
    until [[ $running_pods > 0 && $terminating_pods == 0 ]]; do
        running_pods=$(${KUBECTL} get pods -l k8s-app=kube-apiserver -n kube-system --field-selector=status.phase=Running 2>/dev/null | wc -l || true)
        terminating_pods=$(${KUBECTL} get pods -l k8s-app=kube-apiserver -n kube-system --field-selector=status.phase=Terminating 2>/dev/null | wc -l || true)
        echo "running pods: $running_pods, terminating pods: $terminating_pods"
        sleep 5
    done

    echo "API Server restarted"   
}

function restart_apiserver() {
    echo "restart API Server"
    ${KUBECTL} delete pod -l k8s-app=kube-apiserver -n kube-system || true
    wait_apiserver
}

function restart_kubelet() {
    for ADDR in $MASTER_IPS; do
        echo "restart kubelet on master $ADDR"
        ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@$ADDR "sudo systemctl restart kubelet"
        echo "kubelet on master $ADDR restarted"
        sleep 10
    done

    master_ip_list=($MASTER_IPS)
    master_ip=${master_ip_list[0]}

    for ADDR in $WORKER_IPS; do
        echo "restart kubelet on worker $ADDR"
        ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@$master_ip "ssh -o StrictHostKeyChecking=no core@$ADDR sudo systemctl restart kubelet"
        echo "kubelet on worker $ADDR restarted"
        sleep 10
    done
}


KUBECTL=${DIR}/kubectl

if [ -z "$KUBECONFIG" ]; then
    usage
fi

if [ -z "$MASTER_IPS" ]; then
    usage
fi

if [ -z "$WORKER_IPS" ]; then
    usage
fi

if [ -z "$SSH_KEY" ]; then
    usage
fi

set -u

echo "update CA"
${KUBECTL} patch -f ./generated/patches/step_1/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_1/kube-apiserver-secret.patch)"
${KUBECTL} patch -f ./generated/patches/step_1/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_1/kube-controller-manager-secret.patch)"
${KUBECTL} patch -f ./generated/patches/step_1/tectonic-ca-cert-secret.patch -p "$(cat ./generated/patches/step_1/tectonic-ca-cert-secret.patch)"
${KUBECTL} patch -f ./generated/patches/step_1/ingress-tls.patch -p "$(cat ./generated/patches/step_1/ingress-tls.patch)"
${KUBECTL} patch -f ./generated/patches/step_1/identity-grpc-client.patch -p "$(cat ./generated/patches/step_1/identity-grpc-client.patch)"
${KUBECTL} patch -f ./generated/patches/step_1/identity-grpc-server.patch -p "$(cat ./generated/patches/step_1/identity-grpc-server.patch)"

sleep 10

restart_apiserver

echo
echo "Please replace the kubeconfig on each node before proceeding"
echo "If you are on AWS, you can run ./aws/update_kubeconfig"
echo "If you are on other platform, please contact support for instructions"
echo "Press 'y' when finished"
echo

REPLY=0
until [[ $REPLY == y ]]; do
    read -p "" -n 1 -r
done

restart_kubelet

echo "update api server cert."
${KUBECTL} patch -f ./generated/patches/step_2/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_2/kube-apiserver-secret.patch)"

sleep 10

echo "restart API server"
${KUBECTL} delete pod -l k8s-app=kube-apiserver -n kube-system || true

# Use the new kubeconfig for listing pods because we just rotated the API server certs above.
export KUBECONFIG=./generated/auth/kubeconfig

wait_apiserver

echo
echo "Cluster CA and certs are successfully rotated"
echo "Please reboot all nodes one by one to ensure all pods update their service account"
echo "This can be done by running ./utils/reboot_helper.sh"
