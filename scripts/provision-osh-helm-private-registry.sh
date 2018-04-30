#!/bin/bash -v 

export OSH_CONTRAIL_NODE_01=10.13.82.237
export OSH_CONTRAIL_NODE_02=10.13.82.238
export OSH_CONTRAIL_NODE_03=10.13.82.239

export OSH_CONTROLLER_01=k8s-node01
export OSH_CONTROLLER_02=k8s-node02
export OSH_CONTROLLER_03=k8s-node03

export OSH_COMPUTE_01=k8s-node01
export OSH_COMPUTE_02=k8s-node02
export OSH_COMPUTE_03=k8s-node03

ssh-keygen -t rsa -f /root/.ssh/id_rsa -q -P ""

#sudo ssh-copy-id -i ~/.ssh/id_rsa.pub 10.13.82.237
#sudo ssh-copy-id -i ~/.ssh/id_rsa.pub 10.13.82.238
#sudo ssh-copy-id -i ~/.ssh/id_rsa.pub 10.13.82.239

sshpass -p "Juniper123" ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@${OSH_CONTRAIL_NODE_01}
sshpass -p "Juniper123" ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@${OSH_CONTRAIL_NODE_02}
sshpass -p "Juniper123" ssh-copy-id -i ~/.ssh/id_rsa.pub -o StrictHostKeyChecking=no root@${OSH_CONTRAIL_NODE_03}

# Download openstack-helm code
sudo git clone https://github.com/Juniper/openstack-helm.git /opt/openstack-helm
# Download openstack-helm-infra code
sudo git clone https://github.com/Juniper/openstack-helm-infra.git /opt/openstack-helm-infra
# Download contrail-helm-deployer code
sudo git clone https://github.com/Juniper/contrail-helm-deployer.git /opt/contrail-helm-deployer

sudo ssh ${OSH_CONTRAIL_NODE_02} "git clone https://github.com/Juniper/openstack-helm.git /opt/openstack-helm"
sudo ssh ${OSH_CONTRAIL_NODE_03} "git clone https://github.com/Juniper/openstack-helm.git /opt/openstack-helm"

sudo ssh ${OSH_CONTRAIL_NODE_02} "git clone https://github.com/Juniper/openstack-helm-infra.git /opt/openstack-helm-infra"
sudo ssh ${OSH_CONTRAIL_NODE_03} "git clone https://github.com/Juniper/openstack-helm-infra.git /opt/openstack-helm-infra"

sudo ssh ${OSH_CONTRAIL_NODE_02} "git clone https://github.com/Juniper/contrail-helm-deployer.git /opt/contrail-helm-deployer"
sudo ssh ${OSH_CONTRAIL_NODE_03} "git clone https://github.com/Juniper/contrail-helm-deployer.git /opt/contrail-helm-deployer"

export BASE_DIR=/opt
export OSH_PATH=${BASE_DIR}/openstack-helm
export OSH_INFRA_PATH=${BASE_DIR}/openstack-helm-infra
export CHD_PATH=${BASE_DIR}/contrail-helm-deployer

cd ${OSH_PATH}
./tools/deployment/developer/common/001-install-packages-opencontrail.sh

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
EOF

######## Create Env Variables for K8s Clsuter
cat > /opt/openstack-helm-infra/tools/gate/devel/multinode-vars.yaml <<EOF
# version fields
version:
  kubernetes: v1.8.3
  helm: v2.7.2
  cni: v0.6.0

kubernetes:
  network:
    # enp0s8 is MGMT and enp0s9 is CONTROL/DATA interface, to which kubernetes will bind to
    default_device: enp0s9
  cluster:
    cni: calico
    pod_subnet: 192.168.0.0/16
    domain: cluster.local
docker:
  # list of insecure_registries, from where you will be pulling container images
  insecure_registries:
    - "10.84.5.81:5000"
  # list of private secure docker registry auth info, from where you will be pulling container images
  private_registries:
    - name: registry.net
      username: user@mail.com
      email: user@mail.com
      password: password
      secret_name: contrail-image-secret
      namespace: openstack
EOF

cd ${OSH_INFRA_PATH}
make dev-deploy setup-host multinode 
make dev-deploy k8s multinode 

################ OpenStack Control and Compute Labeling ##############
#kubectl label node ${OSH_CONTROLLER_01} openstack-control-plane=enabled
#kubectl label node ${OSH_CONTROLLER_02} openstack-control-plane=enabled
#kubectl label node ${OSH_CONTROLLER_03} openstack-control-plane=enabled

#kubectl label node ${OSH_COMPUTE_01} openstack-compute-node=enabled
#kubectl label node ${OSH_COMPUTE_02} openstack-compute-node=enabled
#kubectl label node ${OSH_COMPUTE_03} openstack-compute-node=enabled

############ Disable OpenStack Controller label  ###########
#kubectl label node ${OSH_CONTROLLER_02} --overwrite openstack-control-plane=disabled
#kubectl label node ${OSH_CONTROLLER_03} --overwrite openstack-control-plane=disabled
#kubectl label node ${OSH_CONTROLLER_02} --overwrite openstack-control-plane=enabled
#kubectl label node ${OSH_CONTROLLER_03} --overwrite openstack-control-plane=enabled

############ Disable OpenStack Compute label  ####################
#kubectl label node ${OSH_COMPUTE_01} --overwrite openstack-compute-node=disabled
#kubectl label node ${OSH_COMPUTE_02} --overwrite openstack-compute-node=disabled
#kubectl label node ${OSH_COMPUTE_01} --overwrite openstack-compute-node=enabled
#kubectl label node ${OSH_COMPUTE_02} --overwrite openstack-compute-node=enabled

echo "**********  OpenStack Controller Nodes  ***************\n"
kubectl get nodes -o wide -l openstack-control-plane=enabled

echo "**********  OpenStack Compute Nodes ***************\n"
kubectl get nodes -o wide -l openstack-compute-node=enabled


########## Test Kube-DN ###############
sudo apt-get install dnsutils -y
sudo nslookup kubernetes.default.svc.cluster.local

############# OpenStack Helm Deployment
set -xe
cd ${OSH_PATH}

./tools/deployment/multinode/010-setup-client.sh
./tools/deployment/multinode/021-ingress-opencontrail.sh
./tools/deployment/multinode/030-ceph.sh
./tools/deployment/multinode/040-ceph-ns-activate.sh
./tools/deployment/multinode/050-mariadb.sh
./tools/deployment/multinode/060-rabbitmq.sh
./tools/deployment/multinode/070-memcached.sh
./tools/deployment/multinode/080-keystone.sh
./tools/deployment/multinode/090-ceph-radosgateway.sh
./tools/deployment/multinode/100-glance.sh
./tools/deployment/multinode/110-cinder.sh
./tools/deployment/developer/common/100-horizon.sh
./tools/deployment/multinode/131-libvirt-opencontrail.sh
./tools/deployment/multinode/141-compute-kit-opencontrail.sh

############# OpenStack Helm Charts Provisioning Completed #####################

######## Contrail Images Changes in Neutron, Nova and Heat Charts "values.yam" #################

#  1. Heat image change "tools/overrides/backends/opencontrail/heat.yaml"
#     docker.io/opencontrailnightly/contrail-openstack-heat-init:ocata-master-46
#     will change to 
#     ccregdev.sndbx.junipercloud.net/contrail-openstack-heat-init:5.0.0-0.36-ocata


# 2. Nova change "tools/overrides/backends/opencontrail/nova.yaml"
#    docker.io/opencontrailnightly/contrail-openstack-compute-init:ocata-master-46
#    will change to
#    ccregdev.sndbx.junipercloud.net/contrail-openstack-compute-init:5.0.0-0.36-ocata

# 3. Neutron Change "tools/overrides/backends/opencontrail/neutron.yaml"
#    docker.io/opencontrailnightly/contrail-openstack-neutron-init:ocata-master-46
#    will change to
#    ccregdev.sndbx.junipercloud.net/contrail-openstack-neutron-init:5.0.0-0.36-ocata


