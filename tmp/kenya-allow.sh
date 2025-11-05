#!/bin/bash
# Download & extract Kenyan CIDRs
wget -q https://lite.ip2location.com/downloads/ip2location-lite-db1-csv-ke.zip -O /tmp/ke-ips.zip
cd /tmp && unzip -q ke-ips.zip

# Create nftables IP set for Kenya
sudo nft add set ip filter kenya_ips { type ipv4_addr\; flags interval\; }

# Add ALL CIDRs from CSV to the set (skips headers, converts to CIDR)
sudo awk -F, 'NR>1 {system("nft add element ip filter kenya_ips { " $3 " }")}' IP2LOCATION-LITE-DB1-CSV-KE.csv

# Add rule: Allow traffic FROM Kenya IPs (for ALL ports/services)
sudo nft add rule ip filter INPUT ip saddr @kenya_ips counter accept

# (Optional) Drop everything else (except loopback/established)
sudo nft add rule ip filter INPUT iif lo counter accept
sudo nft add rule ip filter INPUT ct state established,related counter accept
sudo nft insert rule ip filter INPUT position 1 ip protocol icmp counter accept  # Allow ping
sudo nft insert rule ip filter INPUT position 1 counter drop  # Drop all else

# Save permanently
sudo nft list ruleset > /etc/nftables.ruleset

# Load on boot (if not already)
echo 'include "/etc/nftables.ruleset"' | sudo tee -a /etc/nftables.conf
sudo systemctl enable nftables

echo "Kenyan IPs loaded! Test with: sudo nft list set ip filter kenya_ips | wc -l"  # Should show ~301
