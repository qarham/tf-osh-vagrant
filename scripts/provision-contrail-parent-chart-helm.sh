#!/bin/bash -v 

### Define Directory Vairable for the OSH and Contrail Repos for Chrats Installation ############
export BASE_DIR=/opt
export OSH_PATH=${BASE_DIR}/openstack-helm
export OSH_INFRA_PATH=${BASE_DIR}/openstack-helm-infra
export CHD_PATH=${BASE_DIR}/contrail-helm-deployer

## This script will use Contrail Internal Repo for per release Contrail Images download
export CONTRAIL_REGISTRY=10.84.5.81:5000
export CONTAINER_TAG=latest


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
export HUGE_PAGES_DIR=/hugepages

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


#### contrail chart Global Env Setting ########
cat > /var/tmp/contrail-controllers << EOF
$CONTROLLER_NODE_01,$CONTROLLER_NODE_02,$CONTROLLER_NODE_03
EOF

cat > /var/tmp/contrail-control << EOF
$CONTROL_NODE_01,$CONTROL_NODE_02,$CONTROL_NODE_03
EOF

cat > /tmp/contrail.yaml << EOF
# GLOBAL variables: which can be consumed by all charts
# images, contrail_env, contrail_env_vrouter_dpdk, contrail_env_vrouter_kernel
global:
  # section to configure images for all containers
  images:
    tags:
      kafka: "${CONTRAIL_REGISTRY}/contrail-external-kafka:${CONTAINER_TAG}"
      cassandra: "${CONTRAIL_REGISTRY}/contrail-external-cassandra:${CONTAINER_TAG}"
      redis: "redis:4.0.2"
      zookeeper: "${CONTRAIL_REGISTRY}/contrail-external-zookeeper:${CONTAINER_TAG}"
      contrail_control: "${CONTRAIL_REGISTRY}/contrail-controller-control-control:${CONTAINER_TAG}"
      control_dns: "${CONTRAIL_REGISTRY}/contrail-controller-control-dns:${CONTAINER_TAG}"
      control_named: "${CONTRAIL_REGISTRY}/contrail-controller-control-named:${CONTAINER_TAG}"
      config_api: "${CONTRAIL_REGISTRY}/contrail-controller-config-api:${CONTAINER_TAG}"
      config_devicemgr: "${CONTRAIL_REGISTRY}/contrail-controller-config-devicemgr:${CONTAINER_TAG}"
      config_schema_transformer: "${CONTRAIL_REGISTRY}/contrail-controller-config-schema:${CONTAINER_TAG}"
      config_svcmonitor: "${CONTRAIL_REGISTRY}/contrail-controller-config-svcmonitor:${CONTAINER_TAG}"
      webui_middleware: "${CONTRAIL_REGISTRY}/contrail-controller-webui-job:${CONTAINER_TAG}"
      webui: "${CONTRAIL_REGISTRY}/contrail-controller-webui-web:${CONTAINER_TAG}"
      analytics_api: "${CONTRAIL_REGISTRY}/contrail-analytics-api:${CONTAINER_TAG}"
      contrail_collector: "${CONTRAIL_REGISTRY}/contrail-analytics-collector:${CONTAINER_TAG}"
      analytics_alarm_gen: "${CONTRAIL_REGISTRY}/contrail-analytics-alarm-gen:${CONTAINER_TAG}"
      analytics_query_engine: "${CONTRAIL_REGISTRY}/contrail-analytics-query-engine:${CONTAINER_TAG}"
      analytics_snmp_collector: "${CONTRAIL_REGISTRY}/contrail-analytics-snmp-collector:${CONTAINER_TAG}"
      contrail_topology: "${CONTRAIL_REGISTRY}/contrail-analytics-topology:${CONTAINER_TAG}"
      build_driver_init: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-build-init:${CONTAINER_TAG}"
      vrouter_agent: "${CONTRAIL_REGISTRY}/contrail-vrouter-agent:${CONTAINER_TAG}"
      vrouter_init_kernel: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-init:${CONTAINER_TAG}"
      vrouter_dpdk: "${CONTRAIL_REGISTRY}/contrail-vrouter-agent-dpdk:${CONTAINER_TAG}"
      vrouter_init_dpdk: "${CONTRAIL_REGISTRY}/contrail-vrouter-kernel-init-dpdk:${CONTAINER_TAG}"
      dpdk_watchdog: "${CONTRAIL_REGISTRY}/contrail-vrouter-net-watchdog:${CONTAINER_TAG}"
      nodemgr: "${CONTRAIL_REGISTRY}/contrail-nodemgr:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"


# contrail_env section for all containers
  contrail_env:
    CONTROLLER_NODES: $(cat /var/tmp/contrail-controllers)
    CONTROL_NODES: $(cat /var/tmp/contrail-control)
    BGP_PORT: 1179
    LOG_LEVEL: SYS_NOTICE
    CLOUD_ORCHESTRATOR: openstack 
    AAA_MODE: cloud-admin 
    BGP_PORT: $BGP_PORT
    VROUTER_GATEWAY: ${VROUTER_GATEWAY}

# section of vrouter template for kernel mode
  contrail_env_vrouter_kernel:
    AGENT_MODE: ${AGENT_MODE_KERNEL}
    CONTROL_DATA_NET_LIST: ${CONTROL_DATA_NET_LIST}

# section of vrouter template for dpdk mode
  contrail_env_vrouter_dpdk:
    CONTROL_DATA_NET_LIST: ${CONTROL_DATA_NET_LIST}
    DPDK_MEM_PER_SOCKET: 1024
    PHYSICAL_INTERFACE: ${DPDK_PHYSICAL_INTERFACE}
    #PHYSICAL_INTERFACE: bond0
    #PHYSICAL_INTERFACE: p3p1
    CPU_CORE_MASK: "$CPU_CORE_MASK"
    DPDK_UIO_DRIVER: ${DPDK_UIO_DRIVER}
    HUGE_PAGES: ${HUGE_PAGES}
    AGENT_MODE: ${AGENT_MODE_DPDK}
    HUGE_PAGES_DIR: /hugepages

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

############## Use this section if you would like to install each Contrail Chart separately using "values.yaml" file #######
#helm install --name contrail-thirdparty ./contrail-thirdparty --namespace=contrail --values /tmp/contrail-thirdparty.yaml
#helm install --name contrail-controller ./contrail-controller --namespace=openstack --values /tmp/contrail-controller.yaml
#helm install --name contrail-analytics ./contrail-analytics --namespace=openstack --values /tmp/contrail-analytics.yaml
#helm install --name contrail-vrouter ./contrail-vrouter --namespace=openstack --values /tmp/contrail-vrouter.yaml

echo ************* Deployment of Contrail Parent Helm Chart ***************************
cd ${CHD_PATH}
helm install --name contrail ${CHD_PATH}/contrail --namespace=contrail --values=/tmp/contrail.yaml
cd ${OSH_PATH}
./tools/deployment/common/wait-for-pods.sh openstack 1200
echo 3 | sudo tee /proc/sys/vm/drop_caches
read -p "Clear cache on other nodes. Press y to continue or n to abort [y/n] : " yn
case $yn in
    [Nn]* ) echo "Aborting...."; exit;;
esac

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
