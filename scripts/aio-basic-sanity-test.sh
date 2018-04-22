#!/bin/bash -v

export OS_CLOUD=openstack_helm

openstack network create MGMT-VN
openstack subnet create --subnet-range 172.16.1.0/24 --network MGMT-VN MGMT-VN-subnet

openstack network create Left-VN
openstack subnet create --subnet-range 10.1.1.0/24 --network Left-VN Left-VN-subnet

openstack network create Right-VN
openstack subnet create --subnet-range 20.1.1.0/24 --network Right-VN Right-VN-subnet

openstack network list

echo ######### Create Two VMs VM-01 & VM-02 on two separet compute ###########
openstack server create --flavor m1.tiny --image 'Cirros 0.3.5 64-bit' \
    --nic net-id=MGMT-VN \
VM-01

openstack server create --flavor m1.tiny --image 'Cirros 0.3.5 64-bit' \
    --nic net-id=MGMT-VN \
VM-02

sleep 30

echo ********** List Created Virtual Network
openstack network list

echo ********* List created VMs ***********
openstack server list


