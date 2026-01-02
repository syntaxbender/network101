# ssh hardened with fwknop gpg+hmac
- blocking replay attacks with time based spa with gpg + hmac

## 1) install reqiurements

```bash
# server side
sudo apt update
sudo apt install fwknop-server fwknop-client iptables-persistent netfilter-persistent gnupg

# client side
sudo apt update
sudo apt install fwknop-client gnupg

```

## 2) configure iptables rules on server side

- configure iptables for following rules;
  - disable ipv6
  - exclude ur ip adress for ssh port
  - drop all incoming connections
  - allow all outgoing connections
  - allow all local/loopback interface connections
  - exclude and allow all establisted connections
  - allow 80,443 and 62201 ports
  - delete ur custom ip rule for ssh connection when ssh connection established
  - persistent iptables rules
```bash
# server side

sudo ufw disable
echo -e "\n# Disable IPv6\nnet.ipv6.conf.all.disable_ipv6 = 1\nnet.ipv6.conf.default.disable_ipv6 = 1\nnet.ipv6.conf.lo.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null

# accept input rule for ssh connect to your ip
sudo iptables -I INPUT -p tcp -s <YOUR_EXTERNAL_CLIENT_IP> --dport 22 -j ACCEPT

# loopback interface fullaccess
sudo iptables -A INPUT -i lo -j ACCEPT

# if a connection established wont drop. need this for access while blocking ssh port if connection established.
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# allow fwknop udp port, http, https
sudo iptables -A INPUT -p udp --dport 62201 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT

# set default iptables policy
sudo iptables -P INPUT DROP
sudo iptables -P FORWARD DROP
sudo iptables -P OUTPUT ACCEPT

# delete custom sshport rule for ur ip when ssh connection established
sudo iptables -D INPUT -p tcp -s <YOUR_EXTERNAL_CLIENT_IP> --dport 22 -j ACCEPT

# set iptable rules persistant
sudo iptables-save | sudo tee /etc/iptables/rules.v4
sudo systemctl enable --now netfilter-persistent
sudo netfilter-persistent save
```

## 3) generate gpg keys and export to client pubkey, server pubkey on both sides

- generate gpg key on client

```bash
# client side
gpg --full-generate-key
Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
  (14) Existing key from card
- Your selection? : 1
- What keysize do you want? : 2048
- Key is valid for? : 1y
- Real name: client-fwknop
- Email address: info@example.com
- Comment:
You selected this USER-ID:
    "client-fwknop <info@example.com>"
- Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit?: O
- Enter passphrase: <CLIENT_KEY_PASSPHRASE>

gpg: key XXXXX marked as ultimately trusted
gpg: revocation certificate stored as '/home/xxx/.gnupg/openpgp-revocs.d/XXXXX.rev'
public and secret key created and signed.

pub   rsa2048 2026-01-02 [SC] [expires: 2027-01-02]
      XXXXX
uid           client-fwknop <info@example.com>
sub   rsa2048 2026-01-02 [E] [expires: 2027-01-02]
```

- generate gpg key on server

```bash
# server side
gpg --full-generate-key
Please select what kind of key you want:
   (1) RSA and RSA (default)
   (2) DSA and Elgamal
   (3) DSA (sign only)
   (4) RSA (sign only)
  (14) Existing key from card
- Your selection? : 1
- What keysize do you want? : 2048
- Key is valid for? : 1y
- Real name: server-fwknop
- Email address: info@remote-server.com
- Comment:
You selected this USER-ID:
    "server-fwknop <info@remote-server.com>"
- Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit?: O
- Enter passphrase: <SERVER_KEY_PASSPHRASE>

gpg: key XXXXX marked as ultimately trusted
gpg: revocation certificate stored as '/home/xxx/.gnupg/openpgp-revocs.d/XXXXX.rev'
public and secret key created and signed.

pub   rsa2048 2026-01-02 [SC] [expires: 2027-01-02]
      XXXXX
uid           server-fwknop <info@remote-server.com>
sub   rsa2048 2026-01-02 [E] [expires: 2027-01-02]
```

- export gpg keys on both sides

```bash
# client side
gpg --armor --export client-fwknop |  tee ./client-fwknop-pub.asc
# server side
gpg --armor --export server-fwknop |  tee ./server-fwknop-pub.asc
```

- copy server pub key to client, client pub key to server

```bash
# client side, copy client pubkey to server on client shell
scp ~/client-fwknop-pub.asc user@remote-server.com:/home/user/
# client side, copy server pubkey from server on client shell
scp user@remote-server.com:/home/user/server-fwknop-pub.asc ~/
```

- import keys on both sides

```bash
# server side
gpg --import client-fwknop-pub.asc
gpg --sign-key client-fwknop
gpg --edit-key client-fwknop

gpg> trust
  2 = I do NOT trust
- Your decision? 2
gpg> quit

# client side
gpg --import server-fwknop-pub.asc
gpg --sign-key server-fwknop
gpg --edit-key server-fwknop

gpg> trust
  2 = I do NOT trust
- Your decision? 2
gpg> quit
```

## 4) configure fwknopd on server side 

- configure fwknopd config on server side

```bash
# server side
sudo nano /etc/fwknop/fwknopd.conf
```

```bash
# server side
# /etc/fwknop/fwknopd.conf

PCAP_INTF                   ens3;

# spa packet time based validity against hardening replay attacks
ENABLE_SPA_PACKET_AGING      Y;

# packet validity time in secs
MAX_SPA_PACKET_AGE           60;

```

- configure fwknopd access config on server side

```bash
# server side
sudo nano /etc/fwknop/access.conf
```

```bash
# server side
# /etc/fwknop/access.conf

# tüm kaynaklardan istekler kabul edilir.
SOURCE              ANY

# fw tanımlaması yapar. istekte bu header ile gelinir. bu isteğe göre fw kuralı çalışır fakat cmd ile bu kısmı biraz eğip büktük.
OPEN_PORTS          tcp/22

# spa paketi içerisinde isteği yapan kaynağın ip adresini istek içerisinde göndermesini zorlar
REQUIRE_SOURCE_ADDRESS  Y

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

- start fwknop-server

```bash
# server side
sudo systemctl enable --now fwknop-server
```

## 5) configure fwknop client on client side 

- client side edit fwknop client config and define remote-server-profile

```bash
# client side
nano ~/.fwknoprc
```

```bash
# client side
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

# Client & Server arasında PAYLAŞILAN ortak HMAC key. İKİ TARAFTA DA AYNI OLMAK ZORUNDA
USE_HMAC                    Y
HMAC_KEY_BASE64             <SHARED_HMAC_KEY_SERVER_CLIENT>
HMAC_DIGEST_TYPE            sha512

```

- try spa connection to remote server

```bash
# -vv # 2x debug flag
# -n remote-server-profile # ur fwknop profile name
fwknop -n remote-server-profile -vv
```

## debug
```bash
# server side
sudo journalctl -u fwknop-server --no-pager
sudo iptables -L INPUT -v --line-numbers

# for example, delete 4. line verbose output
sudo iptables -D INPUT 4
```

## troubleshooting

- Fixing GPG "Inappropriate ioctl for device" errors: https://gist.github.com/syntaxbender/a2ff42c92f36afc937f037767a505fe1
