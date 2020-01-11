#!/bin/bash
if [ $# -eq 0 ]
  then
    echo "No arguments supplied. Add number of nodes you need to create"
    exit 1
fi
INSTANCES=$1
NETWORK_NAME="selfservice"
SUBNET_NAME="subred"
ROUTER_NAME="router"
SUBNET_RANGE="10.2.0.0/24"
SECURITY_GROUP_NAME="lab1"
FLAVOR="lab1"
KEYPAIR_NAME="keypair"
VMTOMCAT="vmtomcat1"
VMMYSQL="vmmysql"
EXTERNAL_NETWORK="external-network"
LB_NAME="web-lb"
LISTENER_NAME="web-listener"
POOL_NAME="web-pool"
openstack network create $NETWORK_NAME
echo "NETWORK CREATED"
openstack subnet create --subnet-range $SUBNET_RANGE --network $NETWORK_NAME --dns-nameserver 8.8.4.4 $SUBNET_NAME
echo "SUBNET CREATED"
openstack router create $ROUTER_NAME
echo "ROUTER CREATED"
openstack router add subnet $ROUTER_NAME $SUBNET_NAME
echo "SUBNET ADDED TO THE ROUTER"
openstack router set $ROUTER_NAME --external-gateway $EXTERNAL_NETWORK
echo "EXTERNAL GATEWAY"
openstack security group create $SECURITY_GROUP_NAME
echo "SECURITY GROUP CREATED"

openstack security group rule create $SECURITY_GROUP_NAME --proto tcp --dst-port 80:80 --src-ip 0.0.0.0/0
echo "RULE CREATED"
NETWORK_ID=$(openstack network list -f value | grep $NETWORK_NAME | cut -d' ' -f1)
for (( c=0; c<$INSTANCES; c++ ))
do  
    openstack server create --image ubuntu-xenial --flavor $FLAVOR --security-group $SECURITY_GROUP_NAME --key-name $KEYPAIR_NAME --nic net-id=$NETWORK_ID --user-data lb$c.yml vmtomcat$c 
    echo "INSTANCE CREATED"
done


neutron lbaas-loadbalancer-create --name $LB_NAME $SUBNET_NAME 
echo "LOADBALANCER CREATED"

neutron lbaas-listener-create --name $LISTENER_NAME --loadbalancer $LB_NAME --protocol HTTP --protocol-port 80
while true; do
    STATUS=$(neutron lbaas-loadbalancer-list -f value -c 'provisioning_status')
    echo $STATUS
    sleep 0.5
    if [ $STATUS = "ACTIVE" ]; then
        break
    fi
done
echo "CONTINUE"
echo "LISTENER CREATED"
neutron lbaas-pool-create --name $POOL_NAME --lb-algorithm ROUND_ROBIN --listener $LISTENER_NAME --protocol HTTP
echo "POOL CREATED"
for (( c=0; c<$INSTANCES; c++ ))
do  
    IP=$(openstack server show vmtomcat$c -f value -c addresses | cut -d= -f2)
    neutron lbaas-member-create --subnet $SUBNET_NAME --address $IP --protocol-port 80 $POOL_NAME
    echo "INSTANCE ASSOCIATED"
done

neutron lbaas-healthmonitor-create --delay 5 --type HTTP --max-retries 3 --timeout 2 --pool $POOL_NAME
echo "HEALTHMONITOR CREATED"
openstack floating ip create $EXTERNAL_NETWORK
echo "FLOATING IP CREATER"
FLOATING_IP=$(openstack floating ip list -f value -c "ID")


PORT_NUM=$(openstack port list | grep loadbalancer | cut -d' ' -f2)
neutron floatingip-associate $FLOATING_IP $PORT_NUM
echo "FLOATING IP ASOCIEATED"
