#!/bin/bash
# Update Cloudflare IP ranges

set -e

CLOUDFLARE_IPS_FILE="/home/jacobgood/theprogram5/deploy/nginx/cloudflare-ips.conf"
TEMP_FILE="/tmp/cloudflare-ips.conf"

echo "# Cloudflare IP ranges" > $TEMP_FILE
echo "# Updated: $(date)" >> $TEMP_FILE
echo "" >> $TEMP_FILE

echo "# IPv4" >> $TEMP_FILE
curl -s https://www.cloudflare.com/ips-v4 | while read ip; do
    echo "allow $ip;" >> $TEMP_FILE
done

echo "" >> $TEMP_FILE
echo "# IPv6" >> $TEMP_FILE
curl -s https://www.cloudflare.com/ips-v6 | while read ip; do
    echo "allow $ip;" >> $TEMP_FILE
done

mv $TEMP_FILE $CLOUDFLARE_IPS_FILE
echo "Cloudflare IPs updated successfully"