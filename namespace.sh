#!/bin/bash
ip netns add ns1 #namespace olusturur
ip netns exec ns1 ip link set lo up # ns1 namespace loopback down'dan up yapar
ip link add veth0 type veth peer name veth1 # virtual ethernet cifti olusturur
ip link set veth0 netns ns1 # ciftin bir ucunu namespace icerisine yollar
#ip addr add 192.168.1.1/24 dev veth1 # veth1e ip atamasi yapar
ip netns exec ns1 ip addr add 192.168.1.2/24 dev veth0 # veth0a ip atar dhcp gibi
ip link set dev veth1 up # veth1 up yapar
ip netns exec ns1 ip link set dev veth0 up # veth0 up yapar
#ip addr delete 192.168.1.1/24 dev veth1 # veth0a ip atamayi siler
ip link add kopru type bridge # bridge interface olusturur
ip link set veth1 master kopru # veth1'i bridge interface ile baglar. veth0 da ns1 icerisinde.
ip addr add 192.168.1.1/24 dev kopru # kopruye ip atar
ip link set kopru up
ip link set veth1 up
ip netns exec ns1 ip route add default via 192.168.1.1
echo "1" > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
