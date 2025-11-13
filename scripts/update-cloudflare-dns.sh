#!/bin/bash
# Update Cloudflare DNS record with Tailscale IP

set -e

# Configuration
CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
DNS_RECORD_NAME="${DNS_RECORD_NAME:-fkstrading.xyz}"
TAILSCALE_IP="${1:-}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check required variables
if [ -z "$CLOUDFLARE_ZONE_ID" ]; then
    echo -e "${RED}❌ CLOUDFLARE_ZONE_ID not set${NC}"
    exit 1
fi

if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo -e "${RED}❌ CLOUDFLARE_API_TOKEN not set${NC}"
    exit 1
fi

# Get Tailscale IP if not provided
if [ -z "$TAILSCALE_IP" ]; then
    echo -e "${YELLOW}Getting Tailscale IP...${NC}"
    TAILSCALE_IP=$(./get-tailscale-ip.sh)
    if [ -z "$TAILSCALE_IP" ]; then
        echo -e "${RED}❌ Could not get Tailscale IP${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Tailscale IP: $TAILSCALE_IP${NC}"

# Get current DNS record
echo "Getting current DNS record..."
CURRENT_RECORD=$(curl -s -X GET \
    "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=${DNS_RECORD_NAME}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json")

CURRENT_IP=$(echo "$CURRENT_RECORD" | jq -r '.result[0].content // empty')
RECORD_ID=$(echo "$CURRENT_RECORD" | jq -r '.result[0].id // empty')

if [ -z "$CURRENT_IP" ]; then
    echo -e "${YELLOW}⚠️  DNS record not found, creating new record...${NC}"
    
    RESPONSE=$(curl -s -X POST \
        "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${DNS_RECORD_NAME}\",\"content\":\"${TAILSCALE_IP}\",\"ttl\":300}")
    
    SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
        echo -e "${GREEN}✅ DNS record created successfully${NC}"
        exit 0
    else
        echo -e "${RED}❌ Failed to create DNS record${NC}"
        echo "$RESPONSE" | jq '.'
        exit 1
    fi
fi

echo -e "${GREEN}✅ Current DNS IP: $CURRENT_IP${NC}"

# Check if update is needed
if [ "$CURRENT_IP" = "$TAILSCALE_IP" ]; then
    echo -e "${GREEN}✅ IPs match, no update needed${NC}"
    exit 0
fi

# Update DNS record
echo -e "${YELLOW}🔄 Updating DNS record...${NC}"
RESPONSE=$(curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records/${RECORD_ID}" \
    -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"${DNS_RECORD_NAME}\",\"content\":\"${TAILSCALE_IP}\",\"ttl\":300}")

SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
    echo -e "${GREEN}✅ DNS record updated successfully${NC}"
    echo -e "${GREEN}   $CURRENT_IP → $TAILSCALE_IP${NC}"
    exit 0
else
    echo -e "${RED}❌ Failed to update DNS record${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

