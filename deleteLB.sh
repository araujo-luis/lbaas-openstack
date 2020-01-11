#!/bin/bash
if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Add number of nodes you need to remove"
    exit 1
fi
INSTANCES=$1
NETWORK_NAME="selfservice"
SUBNET_NAME="subred"
SUBNET_RANGE="10.2.0.0/24"
ROUTER_NAME="router"
SECURITY_GROUP_NAME="lab1"
FLAVOR="lab1"
KEYPAIR_NAME="keypair"
VMTOMCAT="vmtomcat1"
VMMYSQL="vmmysql"
EXTERNAL_NETWORK="external-network"
LB_NAME="web-lb"
LISTENER_NAME="web-listener"
POOL_NAME="web-pool"

for (( c=0; c<$INSTANCES; c++ ))
do  
    openstack server delete vmtomcat$c
done
echo "INSTANCES DELETED"
openstack security group delete $SECURITY_GROUP_NAME
FLOATING_IP=$(openstack floating ip list -f value -c "Floating IP Address")
openstack floating ip delete $FLOATING_IP
echo "IP FLOATING DESASSOCIATED"
LB_ID=$(neutron lbaas-loadbalancer-list -f value -c id)
LB_LISTENERS_ID=$(neutron lbaas-listener-list | grep web-listener | cut -d' ' -f2)
LB_POOL_ID=$(neutron lbaas-pool-list | grep web-pool | cut -d' ' -f2)
LB_HEALTH_ID=$(neutron lbaas-healthmonitor-list | grep HTTP | cut -d' ' -f2)
neutron lbaas-listener-delete "${LB_LISTENERS_ID}"
echo "LISTENER DELETED"
neutron lbaas-healthmonitor-delete "${LB_HEALTH_ID}"
echo "MONITOR DELETED"
neutron lbaas-pool-delete "${LB_POOL_ID}"
echo "POOL DELETED"
neutron lbaas-loadbalancer-delete "${LB_ID}"
echo "LOADBALANCER DELETED"

openstack router unset --external-gateway $ROUTER_NAME 
 for PORT in $(openstack port list --router $ROUTER_NAME --format=value -c ID)
  do
    openstack router remove port $ROUTER_NAME $PORT
  done
  openstack router delete $ROUTER_NAME
echo "ROUTER DELETED"

openstack network delete $NETWORK_NAME
echo "NETWORK DELETED"


