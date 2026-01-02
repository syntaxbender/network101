# ssh hardened with fwknop gpg+hmac
- blocking replay attacks with time based spa with gpg + hmac

```
client 
openssl rand -base64 64
```

```
// remote-server shell

sudo ufw disable
echo -e "\n# Disable IPv6\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null

# loopback interface fullaccess
sudo iptables -A INPUT -i lo -j ACCEPT

# if a connection established wont drop. need this for access while blocking ssh port if connection established.
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# allow fwknop udp port, http, https
sudo iptables -A INPUT -p udp --dport 62201 -j ACCEPT 
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# disable ssh port
sudo iptables -A INPUT -p tcp --dport 22 -j DROP

# set ıptable rules persıstant
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# install fwknop for open ssh to ur ip
sudo apt install fwknop-server fwknop-client iptables-persistent netfilter-persistent gnupg
sudo nano /etc/fwknop/fwknopd.conf

```

```
// remote-server
# /etc/fwknop/fwknopd.conf

PCAP_INTF                   ens3;
ENABLE_SPA_PACKET_AGING      Y;
MAX_SPA_PACKET_AGE           60;

```

```
// remote-server
# /etc/fwknop/access.conf

### ===============================
### GPG – SERVER SIDE KEYS
### ===============================

GPG_HOME_DIR           /root/.gnupg

# Server’ın private key’i. Client tarafından gönderilen SPA paketini AÇMAK için kullanılır.
GPG_DECRYPT_ID                 <SERVER_PRIVATE_GPG_KEY_ID>
GPG_DECRYPT_PW                 <SERVER_PRIVATE_GPG_KEY_PASSPHRASE>

# Client SPA paketini imzaladı mı?
GPG_REQUIRE_SIG                Y
GPG_IGNORE_SIG_VERIFY_ERROR    N

# Client’ın PUBLIC key ID’si. Server, imzayı bu key ile DOĞRULAR
GPG_REMOTE_ID                  <CLIENT_PUBLIC_GPG_KEY_ID>


### ===============================
### HMAC – SERVER SIDE
### ===============================

# Server & Client arasında ORTAK gizli anahtar
HMAC_KEY_BASE64                <SHARED_HMAC_KEY_SERVER_CLIENT>
HMAC_DIGEST_TYPE               sha512


### ===============================
### FIREWALL (SERVER)
### ===============================

CMD_CYCLE_OPEN                 /usr/sbin/iptables -I INPUT -p tcp -s $SRC --dport $PORT -j ACCEPT
CMD_CYCLE_CLOSE                /usr/sbin/iptables -D INPUT -p tcp -s $SRC --dport $PORT -j ACCEPT
CMD_CYCLE_TIMER                60
```

```
sudo systemctl enable fwknop-server
sudo systemctl enable ssh
sudo systemctl enable --now netfilter-persistent
sudo systemctl reload netfilter-persistent
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
SPA_SERVER                  example.com
SPA_SERVER_PROTO            udp
SPA_SERVER_PORT             62201
ALLOW_IP                    resolve

USE_GPG                     Y

# Server’ın PUBLIC GPG key’i. Client, SPA paketini bu key ile ENCRYPT eder
GPG_RECIPIENT               <SERVER_PUBLIC_GPG_KEY_ID>

# Client’ın PRIVATE GPG key’i. Client, SPA paketini bu key ile SIGN eder
GPG_SIGNER                  <CLIENT_PRIVATE_GPG_KEY_ID>

# Client private key passphrase (sign işlemi için)
GPG_SIGNING_PW              <CLIENT_PRIVATE_GPG_KEY_PASSPHRASE>

USE_HMAC                    Y

# Client & Server arasında PAYLAŞILAN ortak HMAC key. İKİ TARAFTA DA AYNI OLMAK ZORUNDA
HMAC_KEY_BASE64             <SHARED_HMAC_KEY_SERVER_CLIENT>
HMAC_DIGEST_TYPE            sha512

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

# for example, delete 4. line verbose output
sudo iptables -D INPUT 4 
```
