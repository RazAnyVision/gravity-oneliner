#!/bin/bash

/sbin/ip link add dummy0 type dummy
/sbin/ip addr add 5.5.5.5/32 dev dummy0
/sbin/ip link set dummy0 up
