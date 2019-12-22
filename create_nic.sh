#!/bin/bash

DUMMY_IP=$1

/sbin/ip link add dummy0 type dummy
/sbin/ip addr add $DUMMY_IP/32 dev dummy0
/sbin/ip link set dummy0 up
