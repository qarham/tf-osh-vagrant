#!/bin/bash -v

### Delete Contrail Chart  ############
helm delete --purge contrail

helm delete --purge ingress-contrail

kubectl get pods -n contrail -o wide

echo "Waiting for the Contrail Networking to clean up"
sleep 120

kubectl get pods -n contrail -o wide

sudo rm -rf /var/lib/contrail*
sudo rm -rf /var/lib/configdb*
sudo rm -rf /var/lib/analyticsdb*
sudo rm -rf /var/lib/config*