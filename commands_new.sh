run `./gencert generated`

git commit the generated dir
require master ips
MASTER_IPS=("")
WORKER_IPS=("")
ETCD_IPS=("")

# etcd (optional):
kubectl patch -f ./generated/patches/etcd/etcd-ca.patch -p "$(cat ./generated/patches/etcd/etcd-ca.patch)"

sleep 10s

# kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

wait until new apiserver comes up

# Copy generated to master nodes
# on master nodes:

for ADDR in $MASTER_IPS; do
    echo "copy assets into master nodes"
    scp -r StrictHostKeyChecking=no generated core@$ADDR:
    echo "done"
done

# Update certs on etcd nodes.
for ADDR in $ETCD_IPS; do
    echo "etcd on $ADDR restarting"
    scp -o StrictHostKeyChecking=no generated/tls/etcd/old_new_ca.crt core@$ADDR:/home/core/ca.crt

    ssh -A -o StrictHostKeyChecking=no \
        core@$ADDR "sudo chown etcd:etcd /home/core/ca.crt; \
          sudo cp -r /etc/ssl/etcd /etc/ssl/etcd.bak; \
          sudo mv /home/core/ca.crt /etc/ssl/etcd/ca.crt; \
          sudo systemctl restart etcd-member"

    echo "etcd on $ADDR restarted"
    sleep 10
done

kubectl patch -f ./generated/patches/etcd/etcd-client-cert.patch -p "$(cat ./generated/patches/etcd/etcd-client-cert.patch)"

sleep 10s

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

wait until new apiserver comes up

# on master nodes:

for ADDR in $ETCD_IPS; do
    echo "etcd on $ADDR restarting"
    scp -o StrictHostKeyChecking=no \
        generated/tls/etcd/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key} \
        core@$ADDR:/home/core

    ssh -A -o StrictHostKeyChecking=no core@$ADDR \
        "sudo chown etcd:etcd /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key}; \
         sudo chmod 0400 /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key}; \
         sudo mv /home/core/{peer.crt,peer.key,server.crt,server.key,client.crt,client.key} /etc/ssl/etcd/; \
         sudo systemctl restart etcd-member"

    echo "etcd on $ADDR restarted"
    sleep 10
done

# verify everthing is still working

# control plane

kubectl patch -f ./generated/patches/step_1/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_1/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_1/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_1/kube-controller-manager-secret.patch)"

kubectl patch -f ./generated/patches/step_1/tectonic-ca-cert-secret.patch -p "$(cat ./generated/patches/step_1/tectonic-ca-cert-secret.patch)"

kubectl patch -f ./generated/patches/step_1/ingress-tls.patch -p "$(cat ./generated/patches/step_1/ingress-tls.patch)"

kubectl patch -f ./generated/patches/step_1/identity-grpc-client.patch -p "$(cat ./generated/patches/step_1/identity-grpc-client.patch)"

kubectl patch -f ./generated/patches/step_1/identity-grpc-server.patch -p "$(cat ./generated/patches/step_1/identity-grpc-server.patch)"

sleep 10s

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

wait until new apiserver comes up

update kubeconfig on nodes by updating s3 bucket patches/step_1/kubeconfig

get the s3 bucket name

# restart kubelets

for ADDR in $MASTER_IPS; do
    echo "restarting kubelet"
    ssh -A -o StrictHostKeyChecking=no core@$ADDR \
         "sudo systemctl restart kubelet"

    # Sleep one by one
done

kubectl patch -f ./generated/patches/step_2/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_2/kube-apiserver-secret.patch)"

sleep 10s

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

export KUBECONFIG=$PWD/generated/auth/kubeconfig

# restart nodes

for ADDR in $MASTER_IPS; do
    echo "rebooting $ADDR"
    ssh -A -o StrictHostKeyChecking=no core@$ADDR \
         "sudo systemctl reboot"

    # Sleep one by one
done
