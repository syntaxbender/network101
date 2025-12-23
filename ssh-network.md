# ssh hardened without vpn

```
// remote-server shell

sudo ufw disable

# loopback interface fullaccess
sudo iptables -A INPUT -i lo -j ACCEPT

# if a connection established wont drop. need this for access while blocking ssh port if connection established.
sudo iptables -A INPUT -m conntrack --cstate ESTABLISHED,RELATED -j ACCEPT

# allow fwknop udp port, http, https
sudo iptables -A INPUT -p udp --dport 62201 -j ACCEPT 
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# disable ssh port
sudo iptables -A INPUT -p tcp --dport 22 -j DROP

sudo apt install fwknop-server fwknop-client
sudo nano /etc/fwknop/fwknopd.conf

```

```
// remote-server
# /etc/fwknop/fwknopd.conf

PCAP_INTF                   ens3;
```

```
// remote-server
# /etc/fwknop/access.conf

SOURCE              ANY
OPEN_PORTS          tcp/22
REQUIRE_SOURCE_ADDRESS  Y
KEY_BASE64          <YOUR_GENERATED_KEY>
HMAC_KEY_BASE64     <YOUR_GENERATED_KEY>
CMD_CYCLE_OPEN          /usr/sbin/iptables -I INPUT -p tcp -s $SRC --dport $PORT -j ACCEPT
CMD_CYCLE_CLOSE         /usr/sbin/iptables -D INPUT -p tcp -s $SRC --dport $PORT -j ACCEPT
CMD_CYCLE_TIMER       60
```

```
// local

sudo apt update
sudo apt install fwknop-client
fwknop -A tcp/22 -D remote-server.com --key-gen --use-hmac --save-rc-stanza

cat ~/.fwknoprc
```

```
// local
#  ~/.fwknoprc

[remote-server-profile]
ACCESS                      tcp/22
SPA_SERVER                  111.111.111.111 # remote-server-ip
KEY_BASE64                  <YOUR_GENERATED_KEY>
HMAC_KEY_BASE64             <YOUR_GENERATED_KEY>
USE_HMAC                    Y

```

```
# open ssh port to ur ip temporarly in ur local shell
# -R # query ur local ip
# -vv # 2x debug flag
# -n remote-server-profile # ur fwknop profile name
fwknop -n remote-server-profile -R -vv
```
# debug
```
// remote-server shell
sudo journalctl -u fwknop-server
sudo iptables -L INPUT -v --line-numbers

```
