#!/bin/bash
set -ex

export CONTRAIL_REGISTRY=opencontrailnightly
export CONTAINER_TAG=ocata-master-49

#Get physical_intf and ip address
export PHYSIICAL_INTERFACE="$(sudo ip -4 route list 0/0 | awk '{ print $5; exit }')"
export INTERFACE_IP_ADDRESS="$(ip addr show dev $PHYSIICAL_INTERFACE | grep "inet .*/.* brd " | awk '{print $2}' | cut -d '/' -f 1)"
export DEFAULT_GATEWAY="$(sudo ip -4 route list 0/0 | awk '{ print $3; exit }')"
export CONTROLLER_NODE="$(kubectl get pods -n kube-system -o wide | awk 'FNR ==2 {print $6; exit}')"
export CONTROL_NODE=$INTERFACE_IP_ADDRESS


cat > /tmp/contrail.yaml << EOF
# GLOBAL variables: which can be consumed by all charts
# images, contrail_env, contrail_env_vrouter_dpdk, contrail_env_vrouter_kernel
global:
  # section to configure images for all containers
  images:
    tags:
      kafka: "docker.io/opencontrailnightly/contrail-external-kafka:${CONTAINER_TAG}"
      cassandra: "docker.io/opencontrailnightly/contrail-external-cassandra:${CONTAINER_TAG}"
      redis: "redis:4.0.2"
      zookeeper: "docker.io/opencontrailnightly/contrail-external-zookeeper:${CONTAINER_TAG}"
      contrail_control: "docker.io/opencontrailnightly/contrail-controller-control-control:${CONTAINER_TAG}"
      control_dns: "docker.io/opencontrailnightly/contrail-controller-control-dns:${CONTAINER_TAG}"
      control_named: "docker.io/opencontrailnightly/contrail-controller-control-named:${CONTAINER_TAG}"
      config_api: "docker.io/opencontrailnightly/contrail-controller-config-api:${CONTAINER_TAG}"
      config_devicemgr: "docker.io/opencontrailnightly/contrail-controller-config-devicemgr:${CONTAINER_TAG}"
      config_schema_transformer: "docker.io/opencontrailnightly/contrail-controller-config-schema:${CONTAINER_TAG}"
      config_svcmonitor: "docker.io/opencontrailnightly/contrail-controller-config-svcmonitor:${CONTAINER_TAG}"
      webui_middleware: "docker.io/opencontrailnightly/contrail-controller-webui-job:${CONTAINER_TAG}"
      webui: "docker.io/opencontrailnightly/contrail-controller-webui-web:${CONTAINER_TAG}"
      analytics_api: "docker.io/opencontrailnightly/contrail-analytics-api:${CONTAINER_TAG}"
      contrail_collector: "docker.io/opencontrailnightly/contrail-analytics-collector:${CONTAINER_TAG}"
      analytics_alarm_gen: "docker.io/opencontrailnightly/contrail-analytics-alarm-gen:${CONTAINER_TAG}"
      analytics_query_engine: "docker.io/opencontrailnightly/contrail-analytics-query-engine:${CONTAINER_TAG}"
      analytics_snmp_collector: "docker.io/opencontrailnightly/contrail-analytics-snmp-collector:${CONTAINER_TAG}"
      contrail_topology: "docker.io/opencontrailnightly/contrail-analytics-topology:${CONTAINER_TAG}"
      build_driver_init: "docker.io/opencontrailnightly/contrail-vrouter-kernel-build-init:${CONTAINER_TAG}"
      vrouter_agent: "docker.io/opencontrailnightly/contrail-vrouter-agent:${CONTAINER_TAG}"
      vrouter_init_kernel: "docker.io/opencontrailnightly/contrail-vrouter-kernel-init:${CONTAINER_TAG}"
      vrouter_dpdk: "docker.io/opencontrailnightly/contrail-vrouter-agent-dpdk:${CONTAINER_TAG}"
      vrouter_init_dpdk: "docker.io/opencontrailnightly/contrail-vrouter-kernel-init-dpdk:${CONTAINER_TAG}"
      dpdk_watchdog: "docker.io/opencontrailnightly/contrail-vrouter-net-watchdog:${CONTAINER_TAG}"
      nodemgr: "docker.io/opencontrailnightly/contrail-nodemgr:${CONTAINER_TAG}"
      dep_check: quay.io/stackanetes/kubernetes-entrypoint:v0.2.1
    imagePullPolicy: "IfNotPresent"


# contrail_env section for all containers
  contrail_env:
    CONTROLLER_NODES: ${CONTROLLER_NODE}
    CONTROL_NODES: ${CONTROL_NODE}
    LOG_LEVEL: SYS_NOTICE
    CLOUD_ORCHESTRATOR: openstack
    AAA_MODE: cloud-admin
    PHYSICAL_INTERFACE: $PHYSIICAL_INTERFACE
    VROUTER_GATEWAY: $DEFAULT_GATEWAY
EOF