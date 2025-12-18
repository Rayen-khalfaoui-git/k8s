#!/bin/bash

#applying the namespace
kubectl apply -f namespace.yaml
#veryfying the namespace
k get namespaces 
k describe ns microservices-demo

#creating the secrets
k apply -f secrets.yaml
#verifying the secrets
k get secrets -n microservices-demo
k describe secret api-keys -n microservices-demo
k describe secret db-credentials -n microservices-demo

#creating the service accounts
k apply -f service-accounts.yaml
#verifying the service accounts
k get serviceaccounts -n microservices-demo
k describe sa backend-sa -n microservices-demo
k describe sa backend-sa -n microservices-demo

#creating the roles
k apply -f roles.yaml
#verifying the roles
k get roles -n microservices-demo
k describe role backend-role -n microservices-demo
k describe role frontend-role -n microservices-demo

#creating the role bindings
k apply -f role-bindings.yaml
#verifying the role bindings
k get rolebindings -n microservices-demo
k describe rolebinding backend-binding -n microservices-demo
kubectl describe rolebinding frontend-binding -n microservices-demo

#creating the database
kubectl apply -f database.yaml
#verifying the database objects
k get all -n microservices-demo | grep postgres
k describe pod postgres-db-84689dc646-92mn4 -n microservices-demo
k describe service postgres-service -n microservices-demo
k describe deployment postgres-db -n microservices-demo
k describe rs postgres-db -n microservices-demo

#creating the backend
kubectl apply -f backend.yaml
#verifying the backend objects
k get all -n microservices-demo | grep backend
#got problem pod/backend-api-58d8cb4d64-56qrg   0/1     CreateContainerConfigError   0          68s
k describe pod/backend-api-58d8cb4d64-56qrg -n microservices-demo
#found  error Error: secret "api-secrets" not found
#i was using the wrong secret name in the backend.yaml file
#corrected the secret name from api-secrets to api-keys in backend.yaml file
# now container is crashing
k logs pod/backend-api-84f5585cd5-fvx9k -n microservices-demo
# container is crashing because npm error Tracker "idealTree" already exists
# need to change the dependency commands in backend.yaml file
kubectl delete -f backend.yaml
#corrected the dependency commands in backend.yaml file
kubectl apply -f backend.yaml
#Back-off restarting failed container backend in pod backend-api-559668f7cb-4gbb8_microservices-demo(50a704de-7b86-4d0e-9abd-3c4eacb3d493)
k describe pod/backend-api-559668f7cb-4gbb8 -n microservices-demo
k logs pod/backend-api-559668f7cb-4gbb8 -n microservices-demo
#i stopped trying to fix the backend for now, will deploy a personal full stack app after finishing the concepts course
k delete namespace microservices-demo
#this should delete everything deployed in this namespace
k get namespaces