git commit the generated dir

MASTER_IPS=("")
WORKER_IPS=("")
ETCD_IPS=("")


# etcd (optional):
kubectl patch -f ./generated/patches/etcd/etcd-ca.patch -p "$(cat ./generated/patches/etcd/etcd-ca.patch)"
# kubectl delete pod -l k8s-app=kube-apiserver -n kube-system
kubectl patch daemonsets -n kube-system kube-apiserver \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"

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
kubectl patch daemonsets -n kube-system kube-apiserver \
    -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"


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

kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

update kubeconfig on nodes by updating s3 bucket

# restart kubelet

for ADDR in $MASTER_IPS; do
    echo "restarting kubelet"
    ssh -A -o StrictHostKeyChecking=no core@$ADDR \
         "sudo systemctl restart kubelet"

    echo "kubelet on $ADDR restarted"
done

kubectl patch -f ./generated/patches/step_2/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_2/kube-apiserver-secret.patch)"

kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

export KUBECONFIG=$PWD/generated/auth/kubeconfig

# wait for api server to be back.

SCHEDULER_NODE_NAME=$(kubectl get pod -l k8s-app=kube-scheduler -n kube-system -ojson | jq -r .items[0].spec.nodeName)
KUBE_SCHEDULER_IMAGE=$(kubectl get deployment kube-scheduler -n kube-system -ojson | jq -r .spec.template.spec.containers[0].image)


cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler-temp
  namespace: kube-system
spec:
  containers:
  - command:
    - ./hyperkube
    - scheduler
    - --leader-elect=true
    image: ${KUBE_SCHEDULER_IMAGE}
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 3
      httpGet:
        path: /healthz
        port: 10251
        scheme: HTTP
      initialDelaySeconds: 15
      periodSeconds: 10
      successThreshold: 1
      timeoutSeconds: 15
    name: kube-scheduler
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
  dnsPolicy: ClusterFirst
  nodeName: ${SCHEDULER_NODE_NAME}
  nodeSelector:
    node-role.kubernetes.io/master: ""
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
EOF

kubectl delete pod -l k8s-app=kube-scheduler -n kube-system

kubectl delete pod kube-scheduler-temp -n kube-system

# optional

kubectl patch -f ./generated/patches/step_3/kube-apiserver-secret.patch -p "$(cat ./generated/patches/step_3/kube-apiserver-secret.patch)"

kubectl patch -f ./generated/patches/step_3/kube-controller-manager-secret.patch -p "$(cat ./generated/patches/step_3/kube-controller-manager-secret.patch)"

kubectl delete pod -l k8s-app=kube-controller-manager -n kube-system
kubectl delete pod -l k8s-app=kube-apiserver -n kube-system

cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Pod
metadata:
  name: kube-scheduler-temp
  namespace: kube-system
spec:
  containers:
  - command:
    - ./hyperkube
    - scheduler
    - --leader-elect=true
    image: ${KUBE_SCHEDULER_IMAGE}
    imagePullPolicy: IfNotPresent
    livenessProbe:
      failureThreshold: 3
      httpGet:
        path: /healthz
        port: 10251
        scheme: HTTP
      initialDelaySeconds: 15
      periodSeconds: 10
      successThreshold: 1
      timeoutSeconds: 15
    name: kube-scheduler
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
  dnsPolicy: ClusterFirst
  nodeName: ${MASTER_NODE}
  nodeSelector:
    node-role.kubernetes.io/master: ""
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
    operator: Exists
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
EOF

kubectl delete pod -l k8s-app=kube-scheduler -n kube-system

kubectl delete pod kube-scheduler-temp -n kube-system

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
