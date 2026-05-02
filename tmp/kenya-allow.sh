#!/bin/bash
# 1. Cleanup and Download
rm -f /tmp/IP2LOCATION-LITE-DB1.CSV /tmp/ke-ips.zip
wget -q https://download.ip2location.com/lite/IP2LOCATION-LITE-DB1.CSV.ZIP -O /tmp/ke-ips.zip
unzip -q /tmp/ke-ips.zip -d /tmp/

# 2. Prepare the nftables command file
# This creates a "batch" file so nftables loads everything in one millisecond
echo "flush ruleset" > /tmp/firewall.nft
echo "table ip filter {" >> /tmp/firewall.nft
echo "    set kenya_ips { type ipv4_addr; flags interval; }" >> /tmp/firewall.nft

# 3. Convert CSV to nftables elements (efficiently)
# Note: Ensure the CSV format matches (StartIP, EndIP). 
# This handles the "range" format nftables likes.
awk -F'","' 'NR>1 {gsub(/"/,""); print "    add element ip filter kenya_ips { " $1 "-" $2 " }"}' /tmp/IP2LOCATION-LITE-DB1.CSV >> /tmp/firewall.nft

# 4. Define the Rules (Order is IMPORTANT)
cat <<EOF >> /tmp/firewall.nft
    chain INPUT {
        type filter hook input priority 0; policy drop;

        # 1. Allow local and established
        iif lo accept
        ct state established,related accept
        
        # 2. Allow ICMP (Ping)
        ip protocol icmp accept

        # 3. Allow KENYA to all VOIP ports (SIP, WebRTC, RTP)
        ip saddr @kenya_ips udp dport { 5060, 3478, 10000-65535 } accept
        ip saddr @kenya_ips tcp dport { 8089 } accept
        
        # 4. SSH Safety (Don't lock yourself out!)
        # Consider adding your specific IP here or leaving 22 open for now
        tcp dport 22 accept 
    }
}
EOF

# 5. Load the ruleset
sudo nft -f /tmp/firewall.nft

# 6. Save for reboot
sudo nft list ruleset | sudo tee /etc/nftables.conf

echo "Done! Kenyan ranges loaded into nftables."
