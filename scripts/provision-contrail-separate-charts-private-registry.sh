#!/bin/bash -v 

### Define Directory Vairable for the OSH and Contrail Repos for Chrats Installation ############
export BASE_DIR=/opt
export OSH_PATH=${BASE_DIR}/openstack-helm
export OSH_INFRA_PATH=${BASE_DIR}/openstack-helm-infra
export CHD_PATH=${BASE_DIR}/contrail-helm-deployer

## This script will use Contrail Internal Repo for per release Contrail Images download
export CONTRAIL_REGISTRY="hub.juniper.net/contrail"
export CONTRAIL_REG_USERNAME="user@abc.com"
export CONTRAIL_REG_PASSWORD="password"
export CONTAINER_TAG="5.0.0-0.40-ocata"


### Define Nodes names for K8s Labeling "opencontrail.org/controller", "opencontrail.org/vrouter-kernel" & "opencontrail.org/vrouter-dpdk"  #######
export CONTRAIL_CONTROLLER_NODE_01=k8s-node01
export CONTRAIL_CONTROLLER_NODE_02=k8s-node02
export CONTRAIL_CONTROLLER_NODE_03=k8s-node03

export CONTRAIL_COMPUTE_KERNEL_01=k8s-node01
export CONTRAIL_COMPUTE_KERNEL_02=k8s-node02

#export CONTRAIL_COMPUTE_DPDK_01=k8s-node03
#export CONTRAIL_COMPUTE_DPDK_02=k8s-node04

##### Controller IP Addresses MGMT Network ###########
export CONTROLLER_NODE_01=10.13.82.237
export CONTROLLER_NODE_02=10.13.82.238
export CONTROLLER_NODE_03=10.13.82.239

######### Contrail Control and Data Plane ##################
export CONTROL_NODE_01=192.168.1.237
export CONTROL_NODE_02=192.168.1.238
export CONTROL_NODE_03=192.168.1.239

export CONTROL_DATA_NET_LIST=192.168.1.0/24
export VROUTER_GATEWAY=192.168.1.1

##### Only used for Calico as CNI to change Contrail Controller port to 1179 ########
export BGP_PORT=1179

### vRouter Kernel Config Values #######
export AGENT_MODE_KERNEL=nic

### vRouter DPDK Config Values #######
export DPDK_PHYSICAL_INTERFACE=enp0s9
export CPU_CORE_MASK="0xff"
export DPDK_UIO_DRIVER=uio_pci_generic
export HUGE_PAGES=49000
export AGENT_MODE_DPDK=dpdk

################## Installastion of Contrail Helm Charts ##############################
cd ${CHD_PATH}
make

kubectl replace -f ${CHD_PATH}/rbac/cluster-admin.yaml

############## Label Contrail Nodes ###################################
kubectl label node ${CONTRAIL_COMPUTE_KERNEL_01} ${CONTRAIL_COMPUTE_KERNEL_02} opencontrail.org/vrouter-kernel=enabled
#kubectl label node ${CONTRAIL_COMPUTE_DPDK_01} opencontrail.org/vrouter-dpdk=enabled
kubectl label nodes ${CONTRAIL_CONTROLLER_NODE_01} ${CONTRAIL_CONTROLLER_NODE_02} ${CONTRAIL_CONTROLLER_NODE_03} opencontrail.org/controller=enabled

echo "**********  Contrail Controller Nodes  ***************\n"
kubectl get nodes -o wide -l opencontrail.org/controller=enabled

echo "**********  Contrail Compute Nodes with vrouter-kernel ***************\n"
kubectl get nodes -o wide -l opencontrail.org/vrouter-kernel=enabled

echo "**********  Contrail Compute Nodes with vrouter-dpdk ***************\n"
kubectl get nodes -o wide -l opencontrail.org/vrouter-dpdk=enabled


#### Contrail charts Global Env Parameters ########
cat > /var/tmp/contrail-controllers << EOF
$CONTROLLER_NODE_01,$CONTROLLER_NODE_02,$CONTROLLER_NODE_03
EOF

cat > /var/tmp/contrail-control << EOF
$CONTROL_NODE_01,$CONTROL_NODE_02,$CONTROL_NODE_03
EOF

#### contrail-thirdparty contrail env parameters ########
cat > /tmp/contrail-thirdparty.yaml << EOF
global:
  # section to configure images for all containers
  images:
    tags:
      kafka: "${CONTRAIL_REGISTRY}/contrail-external-kafka:${CONTAINER_TAG}"
      cassandra: "${CONTRAIL_REGISTRY}/contrail-external-cassandra:${CONTAINER_TAG}"
      redis: "redis:4.0.2"
      zookeeper: "${CONTRAIL_REGISTRY}/contrail-external-zookeeper:${CONTAINER_TAG}"
      nodemgr: "${CONTRAIL_REGISTRY}/contrail-nodemgr:${CONTAINER_TAG}"
      contrail_status: "${CONTRAIL_REGISTRY}/contrail-status:${CONTAINER_TAG}"
      node_init: "${CONTRAIL_REGISTRY}/contrail-node-init:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"

contrail_env: 
  CONTROLLER_NODES: $(cat /var/tmp/contrail-controllers)
  CONTROL_NODES: $(cat /var/tmp/contrail-control)
  LOG_LEVEL: SYS_NOTICE 
  CLOUD_ORCHESTRATOR: openstack 
  AAA_MODE: cloud-admin 
EOF

#### contrail-controller contrail env parameters ########
cat > /tmp/contrail-controller.yaml << EOF
global:
  images:
    tags:
      nodemgr: "${CONTRAIL_REGISTRY}/contrail-nodemgr:${CONTAINER_TAG}"
      contrail_status: "${CONTRAIL_REGISTRY}/contrail-status:${CONTAINER_TAG}"
      node_init: "${CONTRAIL_REGISTRY}/contrail-node-init:${CONTAINER_TAG}"
      contrail_control: "${CONTRAIL_REGISTRY}/contrail-controller-control-control:${CONTAINER_TAG}"
      control_dns: "${CONTRAIL_REGISTRY}/contrail-controller-control-dns:${CONTAINER_TAG}"
      control_named: "${CONTRAIL_REGISTRY}/contrail-controller-control-named:${CONTAINER_TAG}"
      config_api: "${CONTRAIL_REGISTRY}/contrail-controller-config-api:${CONTAINER_TAG}"
      config_devicemgr: "${CONTRAIL_REGISTRY}/contrail-controller-config-devicemgr:${CONTAINER_TAG}"
      config_schema_transformer: "${CONTRAIL_REGISTRY}/contrail-controller-config-schema:${CONTAINER_TAG}"
      config_svcmonitor: "${CONTRAIL_REGISTRY}/contrail-controller-config-svcmonitor:${CONTAINER_TAG}"
      webui_middleware: "${CONTRAIL_REGISTRY}/contrail-controller-webui-job:${CONTAINER_TAG}"
      webui: "${CONTRAIL_REGISTRY}/contrail-controller-webui-web:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"

contrail_env: 
  CONTROLLER_NODES: $(cat /var/tmp/contrail-controllers)
  CONTROL_NODES:  $(cat /var/tmp/contrail-control)
  LOG_LEVEL: SYS_NOTICE 
  CLOUD_ORCHESTRATOR: openstack 
  AAA_MODE: cloud-admin 
  BGP_PORT: $BGP_PORT
EOF

#### contrail-analytics contrail env parameters ########
cat > /tmp/contrail-analytics.yaml << EOF
global:
  images:
    tags:
      nodemgr: "${CONTRAIL_REGISTRY}/contrail-nodemgr:${CONTAINER_TAG}"
      contrail_status: "${CONTRAIL_REGISTRY}/contrail-status:${CONTAINER_TAG}"
      node_init: "${CONTRAIL_REGISTRY}/contrail-node-init:${CONTAINER_TAG}"
      analytics_api: "${CONTRAIL_REGISTRY}/contrail-analytics-api:${CONTAINER_TAG}"
      contrail_collector: "${CONTRAIL_REGISTRY}/contrail-analytics-collector:${CONTAINER_TAG}"
      analytics_alarm_gen: "${CONTRAIL_REGISTRY}/contrail-analytics-alarm-gen:${CONTAINER_TAG}"
      analytics_query_engine: "${CONTRAIL_REGISTRY}/contrail-analytics-query-engine:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"

contrail_env: 
  CONTROLLER_NODES: $(cat /var/tmp/contrail-controllers) 
  CONTROL_NODES: $(cat /var/tmp/contrail-control)
  LOG_LEVEL: SYS_NOTICE 
  CLOUD_ORCHESTRATOR: openstack 
  AAA_MODE: cloud-admin 
EOF

#### contrail-vrouter-kernel contrail env parameters ########
cat > /tmp/contrail-vrouter.yaml << EOF
global:
  images:
    tags:
      nodemgr: "${CONTRAIL_REGISTRY}/contrail-nodemgr:${CONTAINER_TAG}"
      contrail_status: "${CONTRAIL_REGISTRY}/contrail-status:${CONTAINER_TAG}"
      node_init: "${CONTRAIL_REGISTRY}/contrail-node-init:${CONTAINER_TAG}"
      build_driver_init: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-build-init:${CONTAINER_TAG}"
      vrouter_agent: "${CONTRAIL_REGISTRY}/contrail-vrouter-agent:${CONTAINER_TAG}"
      vrouter_init_kernel: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-init:${CONTAINER_TAG}"
      vrouter_dpdk: "${CONTRAIL_REGISTRY}/contrail-vrouter-agent-dpdk:${CONTAINER_TAG}"
      vrouter_init_dpdk: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-init-dpdk:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"

 # common section for all vrouter variants
  # this section is commonized with other Contrails' services
  contrail_env:
    CONTROLLER_NODES: $(cat /var/tmp/contrail-controllers)
    CONTROL_NODES: $(cat /var/tmp/contrail-control)
    LOG_LEVEL: SYS_NOTICE
    CLOUD_ORCHESTRATOR: openstack
    AAA_MODE: cloud-admin
    # this value should be the same as nova/conf.nova.neutron.metadata_proxy_shared_secret
    METADATA_PROXY_SECRET: password
    CONTROL_DATA_NET_LIST: ${CONTROL_DATA_NET_LIST}
    VROUTER_GATEWAY: ${VROUTER_GATEWAY}

# section of vrouter template for kernel mode
  contrail_env_vrouter_kernel:
    AGENT_MODE: ${AGENT_MODE_KERNEL}

# section of vrouter template for dpdk mode
  contrail_env_vrouter_dpdk:
    DPDK_MEM_PER_SOCKET: 1024
    PHYSICAL_INTERFACE: ${DPDK_PHYSICAL_INTERFACE}
    #PHYSICAL_INTERFACE: bond0
    #PHYSICAL_INTERFACE: p3p1
    CPU_CORE_MASK: "$CPU_CORE_MASK"
    DPDK_UIO_DRIVER: ${DPDK_UIO_DRIVER}
    HUGE_PAGES: ${HUGE_PAGES}
    AGENT_MODE: ${AGENT_MODE_DPDK}

  node:
    host_os: ubuntu

# Chart level variables like manifests, labels which are local to subchart
# Can be updated from the parent chart like below
# Example of overriding values of subchart, where contrail-vrouter is name of the subchart
contrail-vrouter:
  manifests:
    configmap_vrouter_dpdk: true
    daemonset_dpdk: true
EOF

######### Contrail Private Registry parameters
tee /tmp/contrail-registry-auth.yaml << EOF
images:
  imageCredentials:
    registry: ${CONTRAIL_REGISTRY}
    username: ${CONTRAIL_REG_USERNAME}
    password: ${CONTRAIL_REG_PASSWORD}
EOF
export CONTRAIL_REGISTRY_ARG="--values=/tmp/contrail-registry-auth.yaml"

echo ************* Deployment of Contrail Parent Helm Chart ***************************

helm install --name contrail-thirdparty ${CHD_PATH}/contrail-thirdparty \
  --namespace=contrail \
  --values=/tmp/contrail-thirdparty.yaml \
  ${CONTRAIL_REGISTRY_ARG}

helm install --name contrail-controller ${CHD_PATH}/contrail-controller \
  --namespace=contrail \
  --values=/tmp/contrail-controller.yaml \
  ${CONTRAIL_REGISTRY_ARG}

helm install --name contrail-analytics ${CHD_PATH}/contrail-analytics \
  --namespace=contrail \
  --values=/tmp/contrail-analytics.yaml \
  ${CONTRAIL_REGISTRY_ARG}

# Edit contrail-vrouter/values.yaml and make sure that global.images.tags.vrouter_init_kernel is right. Image tag name will be different depending upon your linux. Also set the global.node.host_os to ubuntu or centos depending on your system
helm install --name contrail-vrouter ${CHD_PATH}/contrail-vrouter \
  --namespace=contrail \
  --values=/tmp/contrail-vrouter.yaml \
  ${CONTRAIL_REGISTRY_ARG}

#cd ${OSH_PATH}
#./tools/deployment/common/wait-for-pods.sh openstack 1200
#echo 3 | sudo tee /proc/sys/vm/drop_caches
#read -p "Clear cache on other nodes. Press y to continue or n to abort [y/n] : " yn
#case $yn in
#    [Nn]* ) echo "Aborting...."; exit;;
#esac

echo ************** Installing OpenStack Heat with Contrail Heat Resoruces and Test Compute Kit ****************
cd ${OSH_PATH}
./tools/deployment/multinode/151-heat-opencontrail.sh
./tools/deployment/multinode/143-compute-kit-opencontrail-test.sh


echo ****************** Monitoring Software Installation ********
# Weavescope will create a separate Namespace called "weave" and use NodePort use "kubectl get svc -n weave" for NodePort number
#kubectl apply -f "https://cloud.weave.works/k8s/scope.yaml?k8s-service-type=NodePort&k8s-version=$(kubectl version | base64 | tr -d '\n')"

# Promethus and Grafana will create a new Namespace "monitoring" and for GUI access NodePort is used. Please use following command to get NodePort info "kubectl get svnc -n monitoring"

#kubectl apply \
#  --filename https://raw.githubusercontent.com/giantswarm/kubernetes-prometheus/master/manifests-all.yaml

echo ****************** Contrail Helm Installation is sucessful *************************
