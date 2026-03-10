# Rocky Linux 10.1 Wi-Fi Setup — MediaTek MT7922

## Hardware

- **Chipset:** MediaTek MT7922 (802.11ax)
- **Driver:** `mt7921e` (covers MT7921/MT7922/MT7923 family)
- **Interface:** `wlp41s0`
- **Motherboard:** MSI B550M-VC (MS-7C95)

## Problem

After a minimal (no desktop) Rocky Linux 10.1 install, Wi-Fi was non-functional despite working during the Anaconda installer. Symptoms:

- `nmcli device status` showed `wlp41s0` as **unmanaged**
- `nmcli device wifi list` returned **"No Wi-Fi device found"**
- `dmesg` showed `Direct firmware load for regulatory.db failed with error -2`
- NetworkManager logs showed `'wifi' plugin not available; creating generic device`

## Root Cause

The minimal install was missing three packages that are not included by default:

1. **`wireless-regdb`** — the wireless regulatory database (`/lib/firmware/regulatory.db`). Without this, the driver can't determine legal channels/frequencies for the region.
2. **`NetworkManager-wifi`** — the Wi-Fi plugin for NetworkManager. Without this, NM treats Wi-Fi interfaces as generic devices and cannot perform any Wi-Fi operations.
3. **`wpa_supplicant`** — WPA/WPA2 authentication (installed as a dependency of `NetworkManager-wifi`).

Additionally, a config file at `/etc/NetworkManager/conf.d/10-managed.conf` had `unmanaged-devices=none` which needed to be corrected.

## Fix

### 1. Get network access

Since Wi-Fi was broken and no ethernet was available at the server location, a Raspberry Pi was used as a temporary Wi-Fi-to-Ethernet bridge:

**On the Pi (already connected to Wi-Fi):**

```bash
sudo nmcli connection add type ethernet con-name eth-share ifname eth0 ipv4.method shared
sudo nmcli connection up eth-share

# If packets aren't forwarding, manually enable NAT:
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
sudo iptables -A FORWARD -i eth0 -o wlan0 -j ACCEPT
sudo iptables -A FORWARD -i wlan0 -o eth0 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

Then connect an Ethernet cable from the Pi to camp-fai.

**On camp-fai:**

```bash
sudo nmcli device connect enp42s0
ping -c 3 google.com  # verify connectivity
```

### 2. Install missing packages

```bash
sudo dnf install wireless-regdb -y
sudo dnf install NetworkManager-wifi -y
# wpa_supplicant is pulled in as a dependency
```

### 3. Fix NetworkManager config

```bash
sudo tee /etc/NetworkManager/conf.d/10-managed.conf << 'EOF'
[keyfile]
unmanaged-devices=
EOF
```

### 4. Reload driver and restart NetworkManager

```bash
sudo modprobe -r mt7921e
sudo modprobe mt7921e
sudo systemctl restart NetworkManager
```

### 5. Connect to Wi-Fi

```bash
sudo nmcli device wifi list
sudo nmcli device wifi connect <SSID> password <PASSWORD>
```

### 6. Disconnect Pi bridge and verify

```bash
sudo nmcli device disconnect enp42s0
ping -c 3 google.com  # should work over Wi-Fi now
```

### 7. Ensure auto-connect persists across reboots

After connecting, verify you have a single saved profile and that autoconnect is enabled:

```bash
# List saved connections — look for duplicates
nmcli connection show

# If there are duplicate IRVINE_SPEC entries, delete the inactive one (no DEVICE assigned)
sudo nmcli connection delete <inactive-uuid>

# Enable autoconnect on the active profile
sudo nmcli connection modify <active-uuid> autoconnect yes

# Verify
nmcli connection show <active-uuid> | grep autoconnect
# Should show: connection.autoconnect: yes
```

### 8. Reboot and confirm persistence

```bash
sudo reboot
# After reboot:
nmcli device status
ping -c 3 google.com
```

If Wi-Fi auto-connects and the ping works, you're done.

## Diagnostic Commands Reference

| Command | Purpose |
|---------|---------|
| `lspci \| grep -i net` | Identify network chipset |
| `sudo dmesg \| grep -i firmware` | Check for firmware load errors |
| `sudo dmesg \| grep -i regdb` | Check regulatory database loading |
| `sudo rfkill list` | Check for radio soft/hard blocks |
| `sudo iw dev wlp41s0 scan` | Low-level Wi-Fi scan (bypasses NM) |
| `nmcli device status` | NetworkManager device overview |
| `nmcli device show wlp41s0` | Detailed device info |
| `sudo journalctl -u NetworkManager` | NetworkManager logs |
| `rpm -qa \| grep -i wifi` | Check installed Wi-Fi packages |

## Lessons Learned

- Rocky Linux minimal installs do **not** include wireless packages — always budget for wired access on first boot or pre-plan package installation
- The Anaconda installer bundles its own firmware/drivers that may not match the installed package set
- `NetworkManager-wifi` is a separate package from `NetworkManager` — without it, NM literally cannot manage Wi-Fi
- The `mt7921e` driver covers the MT7922 chipset (don't look for a `mt7922` module)
- A Raspberry Pi makes an excellent emergency Wi-Fi bridge using `nmcli connection add ... ipv4.method shared`
