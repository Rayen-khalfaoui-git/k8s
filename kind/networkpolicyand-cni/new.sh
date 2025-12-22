#deleted the cluster
kind delete cluster --name cka-cluster
#recreated the cluster without default cni
kind create cluster --image kindest/node:v1.34.0 --name cka-cluster --config kind.yaml
#applied the cni weavenet
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

#now to check connectivity between pods
kubectl exec -it pod/frontend -- sh
apt-get update && apt-get install telnet
telnet db 3306
#does not work because of network policy as intended
