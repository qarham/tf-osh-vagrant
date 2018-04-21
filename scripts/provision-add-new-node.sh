#!/bin/bash -v 

export OSH_CONTRAIL_NODE_01=10.13.82.43
export OSH_CONTRAIL_NODE_02=10.13.82.44
export OSH_CONTRAIL_NODE_03=10.13.82.45

export OSH_CONTRAIL_NEW_NODE_01=10.13.82.46

export OSH_COMPUTE_NEW_01=aio-node

sshpass -p "Juniper123" ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@${OSH_CONTRAIL_NEW_NODE_01}

sudo ssh ${OSH_CONTRAIL_NEW_NODE_01} "git clone https://github.com/Juniper/openstack-helm.git /opt/openstack-helm"
sudo ssh ${OSH_CONTRAIL_NEW_NODE_01} "git clone https://github.com/Juniper/openstack-helm-infra.git /opt/openstack-helm-infra"
sudo ssh ${OSH_CONTRAIL_NEW_NODE_01} "git clone https://github.com/Juniper/contrail-helm-deployer.git /opt/contrail-helm-deployer"

export BASE_DIR=/opt
export OSH_PATH=${BASE_DIR}/openstack-helm
export OSH_INFRA_PATH=${BASE_DIR}/openstack-helm-infra
export CHD_PATH=${BASE_DIR}/contrail-helm-deployer

## Create Ansible Inventory ###########
cat > /opt/openstack-helm-infra/tools/gate/devel/multinode-inventory.yaml <<EOF
all:
  children:
    primary:
      hosts:
        node_one:
          ansible_port: 22
          ansible_host: ${OSH_CONTRAIL_NODE_01}
          ansible_user: root
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
    nodes:
      hosts:
        node_two:
          ansible_port: 22
          ansible_host: ${OSH_CONTRAIL_NODE_02}
          ansible_user: root
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
        node_three:
          ansible_port: 22
          ansible_host: ${OSH_CONTRAIL_NODE_03}
          ansible_user: root
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
        node_four:
          ansible_port: 22
          ansible_host: ${OSH_CONTRAIL_NEW_NODE_01}
          ansible_user: root
          ansible_ssh_private_key_file: /root/.ssh/id_rsa
          ansible_ssh_extra_args: -o StrictHostKeyChecking=no
EOF

cd ${OSH_INFRA_PATH}
make dev-deploy setup-host multinode 
make dev-deploy k8s multinode 
# sudo -H su -c 'cd /opt/openstack-helm-infra; make all'

### Label new node with OpenStack Compute and Contrail-Kernel-vRouter  #######
kubectl label node ${OSH_COMPUTE_NEW_01} openstack-compute-node=enabled
kubectl label node ${OSH_COMPUTE_NEW_01} opencontrail.org/vrouter-kernel=enabled

echo "**********  OpenStack Controller Nodes  ***************\n"
kubectl get nodes -o wide -l openstack-control-plane=enabled

echo "**********  OpenStack Compute Nodes ***************\n"
kubectl get nodes -o wide -l openstack-compute-node=enabled

echo "**********  Contrail Compute Nodes with vrouter-kernel ***************\n"
kubectl get nodes -o wide -l opencontrail.org/vrouter-kernel=enabled


########## Test Kube-DN ###############
sudo apt-get install dnsutils -y
sudo nslookup kubernetes.default.svc.cluster.local


############# New COmpute Node Added Check status wwith "kubectl get node" & "kubectl get pods" #####################



