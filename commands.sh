git commit the generated dir

# etcd (optional):
kubectl patch -f ./generated/patches/etcd/etcd-ca.patch -p "$(cat ./generated/patches/etcd/etcd-ca.patch)"
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

wait until new apiserver comes up

# Copy generated to master nodes
# on master nodes:

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

# control plane

kubectl patch -f ./generated/patches/step_1/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_1/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_1/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_1/kube-controller-manager-secret.patch)"

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system



update kubeconfig on nodes by updating s3 bucket

restart kubelet


kubectl patch -f ./generated/patches/step_2/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_2/kube-apiserver-secret.patch)"

kubectl scale deployments -n kube-system kube-scheduler --replicas 2

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

export KUBECONFIG=$PWD/generated/auth/kubeconfig

# optional

kubectl patch -f ./generated/patches/step_3/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_3/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_3/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_3/kube-controller-manager-secret.patch)"

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system
kubectl delete pod -l k8s-app=kube-scheduler -n kube-system

update kubeconfig on nodes by updating s3 bucket

restart kubelet


# Restart other components in control plane
kubectl patch statefulsets -n kube-system prometheus-etcd \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n kube-system heapster \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n kube-system kube-dns \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n kube-system kube-flannel \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n kube-system fluentd-agent \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n kube-system kube-proxy \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n kube-system pod-checkpointer \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"



# tectonic manifests

kubectl patch -f ./generated/patches/step_4/tectonic-ca-cert-secret.patch -p "$(cat ./generated/patches/step_4/tectonic-ca-cert-secret.patch)"

kubectl patch -f ./generated/patches/step_4/ingress-tls.patch -p "$(cat ./generated/patches/step_4/ingress-tls.patch)"

kubectl patch -f ./generated/patches/step_4/identity-grpc-client.patch -p "$(cat ./generated/patches/step_4/identity-grpc-client.patch)"

kubectl patch -f ./generated/patches/step_4/identity-grpc-server.patch -p "$(cat ./generated/patches/step_4/identity-grpc-server.patch)"


# Restart tectonic components

kubectl patch statefulsets -n tectonic-system alertmanager-main \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch statefulsets -n tectonic-system prometheus-k8s \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n tectonic-system node-agent \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n tectonic-system container-linux-update-agent-ds \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system default-http-backend \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system alm-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system catalog-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system container-linux-update-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system grafana \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system kube-state-metrics \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system kube-version-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system prometheus-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-alm-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-channel-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-cluo-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-identity \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-console \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-ingress-controller \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-monitoring-auth-alertmanager \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-monitoring-auth-grafana \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-monitoring-auth-prometheus \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-prometheus-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system tectonic-stats-emitter \
        -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch deployments -n tectonic-system etcd-operator \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
kubectl patch daemonsets -n tectonic-system node-exporter \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
