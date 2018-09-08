# etcd (optional):
kubectl patch -f ./generated/patches/etcd/etcd-ca.patch -p "$(cat ./generated/patches/etcd/etcd-ca.patch)"
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system


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
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

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

# control plane

kubectl patch -f ./generated/patches/step_1/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_1/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_1/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_1/kube-controller-manager-secret.patch)"

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system

update kubeconfig on nodes by updating s3 bucket

restart kubelet

kubectl patch -f ./generated/patches/step_2/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_2/kube-apiserver-secret.patch)"
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

export KUBECONFIG=$PWD/generated/auth/kubeconfig

# optional

kubectl patch -f ./generated/patches/step_3/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_3/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_3/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_3/kube-controller-manager-secret.patch)"

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system
kubectl delete pod -l k8s-app=kube-scheduler -n kube-system

# Restart other components in control plane
kubectl delete pod -l k8s-app=pod-checkpointer -n kube-system
kubectl delete pod -l k8s-app=kube-proxy -n kube-system


update kubeconfig on nodes by updating s3 bucket

restart kubelet

# optional

