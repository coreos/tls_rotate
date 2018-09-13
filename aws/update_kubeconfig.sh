#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

function usage() {
    >&2 cat << EOF
Usage: ./update_kubeconfig.sh

Set the following environment variables to run this script:
    AWS_ACCESS_KEY_ID       The accesss key ID to the aws account
    AWS_SECRET_ACCESS_KEY   The access secret to the aws account
    S3_BUCKET               The name of the S3 bucket
EOF
    exit 1
}


if [ -z $(which aws) ]; then
    echo "aws cli tool is required"
    exit 1
fi

if [ -z $AWS_ACCESS_KEY_ID ]; then
    usage
fi

if [ -z $AWS_SECRET_ACCESS_KEY ]; then
    usage
fi


aws s3 cp ${DIR}/../generated/auth/kubeconfig ${S3_BUCKET}
