# Cloudflare API Token Setup Guide

Complete guide for creating a Cloudflare API token with the correct permissions for DNS updates.

## Required Permissions

The workflow needs to:
- ✅ **Read DNS records** (GET `/zones/{zone_id}/dns_records`)
- ✅ **Create DNS records** (POST `/zones/{zone_id}/dns_records`)
- ✅ **Update DNS records** (PUT `/zones/{zone_id}/dns_records/{record_id}`)

## Step-by-Step Setup

### Step 1: Go to Cloudflare API Tokens

1. Log in to Cloudflare Dashboard: https://dash.cloudflare.com/
2. Go to your profile (top right) → **My Profile**
3. Click **API Tokens** tab
4. Click **Create Token**

### Step 2: Use Edit Zone DNS Template (Easiest)

**Option A: Use Template (Recommended)**

1. Click **"Edit zone DNS"** template
2. This pre-configures the correct permissions
3. Under **Zone Resources**, select:
   - **Include** → **Specific zone** → Select `fkstrading.xyz`
4. Click **Continue to summary**
5. Review permissions:
   - ✅ Zone: DNS:Edit
   - ✅ Zone: Zone:Read
6. Click **Create Token**
7. **Copy the token immediately** (you won't see it again!)

### Step 3: Custom Token (Alternative)

If you prefer to create a custom token:

1. Click **Create Token**
2. Click **Get started** on "Create Custom Token"

**Token Name:**
```
FKS Tailscale DNS Updater
```

**Permissions:**
1. **Zone** → **DNS** → **Edit**
   - Zone Resources: Include → Specific zone → `fkstrading.xyz`

2. **Zone** → **Zone** → **Read**
   - Zone Resources: Include → Specific zone → `fkstrading.xyz`

**Zone Resources:**
- Select **Include**
- Choose **Specific zone**
- Select `fkstrading.xyz`

**Client IP Address Filtering:**
- Leave empty (or restrict to GitHub Actions IPs if desired)

**TTL:**
- Leave default (no expiration) or set custom expiration

3. Click **Continue to summary**
4. Review and click **Create Token**
5. **Copy the token immediately**

## Step 3: Get Zone ID

You'll also need the Zone ID:

1. Go to Cloudflare Dashboard
2. Select domain `fkstrading.xyz`
3. Scroll down to **API** section (right sidebar)
4. Under **Zone ID**, click **Copy**

Or use the API:
```bash
curl -X GET "https://api.cloudflare.com/client/v4/zones" \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  | jq -r '.result[] | select(.name=="fkstrading.xyz") | .id'
```

## Step 4: Add to GitHub Secrets

1. Go to: https://github.com/nuniesmith/fks_tailscale/settings/secrets/actions
2. Click **New repository secret**

**Add these secrets:**

1. **Name:** `CLOUDFLARE_ZONE_ID`
   - **Value:** Your zone ID (e.g., `abc123def456...`)

2. **Name:** `CLOUDFLARE_API_TOKEN`
   - **Value:** Your API token (starts with `...`)

## Permissions Summary

| Permission | Resource | Action | Why Needed |
|------------|----------|--------|------------|
| Zone: DNS | fkstrading.xyz | Edit | Update/create DNS A records |
| Zone: Zone | fkstrading.xyz | Read | Get zone information |

## Security Best Practices

✅ **Use API Tokens** (not Global API Key)
- More secure
- Scoped permissions
- Can be revoked individually

✅ **Limit to Specific Zone**
- Only `fkstrading.xyz`
- Can't affect other domains

✅ **DNS Edit Only**
- Can't modify other zone settings
- Can't access account settings

✅ **Set Expiration** (Optional)
- Rotate tokens regularly
- Set expiration date if desired

❌ **Don't use Global API Key**
- Too broad permissions
- Affects all zones
- Harder to revoke

## Testing the Token

Test your token works:

```bash
# Set your token
export CLOUDFLARE_API_TOKEN="your-token-here"
export CLOUDFLARE_ZONE_ID="your-zone-id-here"

# Test reading DNS records
curl -X GET \
  "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=fkstrading.xyz" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" \
  | jq '.'
```

**Expected response:**
```json
{
  "success": true,
  "result": [
    {
      "id": "...",
      "type": "A",
      "name": "fkstrading.xyz",
      "content": "100.x.x.x",
      ...
    }
  ]
}
```

## Troubleshooting

### Error: "Invalid API Token"
- ✅ Check token is copied correctly (no extra spaces)
- ✅ Verify token hasn't expired
- ✅ Make sure you're using API Token, not Global API Key

### Error: "Insufficient permissions"
- ✅ Verify token has "Zone: DNS: Edit" permission
- ✅ Check zone is included in token scope
- ✅ Ensure zone ID matches the token's allowed zones

### Error: "Zone not found"
- ✅ Verify zone ID is correct
- ✅ Check domain is in your Cloudflare account
- ✅ Ensure token has access to that zone

## Quick Reference

**Token Permissions Needed:**
- Zone: DNS: Edit (for `fkstrading.xyz`)
- Zone: Zone: Read (for `fkstrading.xyz`)

**GitHub Secrets:**
- `CLOUDFLARE_ZONE_ID` - Your zone ID
- `CLOUDFLARE_API_TOKEN` - Your API token

**API Endpoints Used:**
- `GET /zones/{zone_id}/dns_records` - Read DNS records
- `POST /zones/{zone_id}/dns_records` - Create DNS record
- `PUT /zones/{zone_id}/dns_records/{record_id}` - Update DNS record

---

**Setup complete!** Your token is ready to use. 🎉

