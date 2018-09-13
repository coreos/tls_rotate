#!/bin/bash

set -eo pipefail

function usage() {
    >&2 cat << EOF
Usage: ./reboot_helper.sh

Set the following environment variables to run this script:
    MASTER_IPS          The list of public IPs of the master nodes, separated by space
                        
    WORKER_IPS          The list of private IPs of the worker nodes, separated by space

    SSH_KEY             The path to the ssh private key that allows to login the master nodes

EOF
    exit 1
}


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

master_ip_list=($MASTER_IPS)
master_ip=${master_ip_list[0]}

for ADDR in $WORKER_IPS; do
    echo "reboot worker $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@$master_ip "ssh -o StrictHostKeyChecking=no core@$ADDR sudo systemctl reboot"
    echo "worker $ADDR rebooted"
    sleep 10
done


for ADDR in $MASTER_IPS; do
    echo "reboot master $ADDR"
    ssh -A -o StrictHostKeyChecking=no -i ${SSH_KEY} core@$ADDR "sudo systemctl reboot"
    echo "master $ADDR rebooted"
    sleep 10
done
