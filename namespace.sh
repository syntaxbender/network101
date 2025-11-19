#!/usr/bin/env bash
set -e

### --- Kullanıcı / Sistem Değişkenleri ---

NS_NAME="ns1"
VETH_HOST="veth0"
VETH_NS="veth1"
BR_NAME="kopru"

SUBNET="10.10.10.0/24"
BR_IP="10.10.10.1"
NS_IP="10.10.10.2"

EXT_IF=$(ip route show default | awk '/default/ {print $5}' | head -n1)

### --- Rollback Fonksiyonu ---
cleanup() {
    echo "[!] Cleaning up old configuration..."
    
    # IP tables cleanup
    sudo iptables -t nat -D POSTROUTING -s "$SUBNET" -o "$EXT_IF" -j MASQUERADE 2>/dev/null || true
    sudo iptables -D FORWARD -i "$EXT_IF" -o "$BR_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
    sudo iptables -D FORWARD -o "$EXT_IF" -i "$BR_NAME" -j ACCEPT 2>/dev/null || true

    # Namespace cleanup
    if ip netns list | grep -qw "$NS_NAME"; then
        echo " - Deleting namespace $NS_NAME"
        sudo ip netns del "$NS_NAME"
    fi

    # Veth cleanup
    for iface in "$VETH_HOST" "$VETH_NS"; do
        if ip link show "$iface" &>/dev/null; then
            echo " - Deleting interface $iface"
            sudo ip link del "$iface"
        fi
    done

    # Bridge cleanup
    if ip link show "$BR_NAME" &>/dev/null; then
        echo " - Deleting bridge $BR_NAME"
        sudo ip link set "$BR_NAME" down || true
        sudo ip link del "$BR_NAME" type bridge || true
    fi

    # Namespace-specific resolv.conf cleanup
    if [ -d "/etc/netns/$NS_NAME" ]; then
        echo " - Removing namespace directory resolv.conf for $NS_NAME"
        sudo rm -f "/etc/netns/$NS_NAME/resolv.conf"
        # Eğer dizin boşsa kaldır
        sudo rmdir --ignore-fail-on-non-empty "/etc/netns/$NS_NAME" 2>/dev/null || true
    fi

    echo "[✓] Cleanup complete."
}

### --- Ana İşlem ---
echo "[+] Detected external interface: $EXT_IF"
cleanup

echo "[+] Creating namespace: $NS_NAME"
sudo ip netns add "$NS_NAME"

echo "[+] Creating veth pair: $VETH_HOST <-> $VETH_NS"
sudo ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
sudo ip link set "$VETH_NS" netns "$NS_NAME"

echo "[+] Creating bridge: $BR_NAME"
sudo ip link add name "$BR_NAME" type bridge
sudo ip link set "$VETH_HOST" master "$BR_NAME"
sudo ip addr add "$BR_IP"/24 dev "$BR_NAME"
sudo ip link set "$BR_NAME" up
sudo ip link set "$VETH_HOST" up

echo "[+] Assigning IP addresses..."
sudo ip netns exec "$NS_NAME" ip addr add "$NS_IP"/24 dev "$VETH_NS"
sudo ip netns exec "$NS_NAME" ip link set "$VETH_NS" up
sudo ip netns exec "$NS_NAME" ip link set lo up

echo "[+] Setting default route..."
sudo ip netns exec "$NS_NAME" ip route add default via "$BR_IP"

echo "[+] Enabling IP forwarding..."
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward > /dev/null

echo "[+] Configuring NAT..."
sudo iptables -t nat -A POSTROUTING -s "$SUBNET" -o "$EXT_IF" -j MASQUERADE
sudo iptables -A FORWARD -i "$EXT_IF" -o "$BR_NAME" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -o "$EXT_IF" -i "$BR_NAME" -j ACCEPT

### --- Namespace için DNS yapılandırması ---
echo "[+] Configuring namespace DNS..."
sudo mkdir -p /etc/netns/"$NS_NAME"
echo "nameserver 8.8.8.8" | sudo tee /etc/netns/"$NS_NAME"/resolv.conf > /dev/null

echo "[+] Testing connectivity..."
sudo ip netns exec "$NS_NAME" ping -c 3 8.8.8.8
sudo ip netns exec "$NS_NAME" curl -s ifconfig.me

echo "[✓] Namespace '$NS_NAME' successfully configured via bridge '$BR_NAME' with NAT and Internet access."
