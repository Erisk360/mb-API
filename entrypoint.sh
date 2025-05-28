#!/bin/sh

echo "Fetching bundle status..."

API_URL="https://capi.odido.nl/0a4ee54c4f59/customer/$CUSTOMERNUMBER/subscription/$MSISDN/databundles"

response=$(curl -s -X GET \
  -H "Authorization: Bearer $TOKEN" \
  -H "User-Agent: Odido/8.11 (build:26520; iOS 18.4.0)" \
  -H "Cookie: $COOKIE" \
  -H "Accept: application/json" \
  -H "Host: capi.odido.nl" \
  -H "Accept-Language: nl-NL,nl;q=0.9" \
  "$API_URL")

#for debugging
#echo "Raw response:"
#echo "$response" | head -n 10


#echo "$response" | head -n 20
echo "$response" > debug_output.json

# Extract bundle data
main_remaining=$(echo "$response" | jq -r '.Bundles[] | select(.Name == "Dagtegoed NL") | .Remaining.Value')
addon_remaining=$(echo "$response" | jq -r '.Bundles[] | select(.BuyingCode == "A0DAY05") | .Remaining.Value')
main_presentation=$(echo "$response" | jq -r '.Bundles[] | select(.Name == "Dagtegoed NL") | .Remaining.Presentation')
addon_presentation=$(echo "$response" | jq -r '.Bundles[] | select(.BuyingCode == "A0DAY05") | .Remaining.Presentation')

echo " MAIN Bundle: $main_presentation remaining"
echo " ADD-ON Bundle: ${addon_presentation:-Not active}"

echo ""
echo " Bundle Overview:"
echo "╔══════════════════════════════════════════════════════════════╗"
printf "║ %-39s │ %-10s │ %-10s ║\n" "Bundle Name" "Remaining" "BuyingCode"
echo "╠══════════════════════════════════════════════════════════════╣"

echo "$response" | jq -r '
  .Bundles[] | 
  [.Name, .Remaining.Presentation, (.BuyingCode // "-")] | 
  @tsv' | while IFS=$'\t' read -r name remaining buyingCode; do
    printf "║ %-39s │ %-10s │ %-10s ║\n" "$name" "$remaining" "$buyingCode"
done

echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Trigger top-up logic

# Dynamically calculate 10% threshold of the main bundle limit
main_limit=$(echo "$response" | jq -r '.Bundles[] | select(.Name == "Dagtegoed NL") | .Limit.Value')
THRESHOLD=$((main_limit / 10))


if [ "$main_remaining" -lt "$THRESHOLD" ] && [ "$addon_remaining" = "null" ]; then
  echo "  Main bundle < 2GB and no add-on. Buying 2GB add-on..."
  curl -X POST "https://capi.odido.nl/0a4ee54c4f59/customer/$CUSTOMERNUMBER/subscription/$MSISDN/roamingbundles" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json,application/vnd.capi.tmobile.nl.roamingbundles.v4+json" \
    # -H "User-Agent: Odido/8.11 (build:26520; iOS 18.4.0)" \ 
   #  -H "Accept-Language: nl-NL,nl;q=0.9" \
    --data-raw "{\"bundles\":[{\"buyingCode\":\"$BUYING_CODE\"}]}"
elif [ "$addon_remaining" = "0" ]; then
  echo "  Add-on is depleted. Buying another 2GB..."
  curl -X POST "https://capi.odido.nl/0a4ee54c4f59/customer/$CUSTOMERNUMBER/subscription/$MSISDN/roamingbundles" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json,application/vnd.capi.tmobile.nl.roamingbundles.v4+json" \
    #-H "User-Agent: Odido/8.11 (build:26520; iOS 18.4.0)" \
    #-H "Accept-Language: nl-NL,nl;q=0.9" \
    --data-raw "{\"bundles\":[{\"buyingCode\":\"$BUYING_CODE\"}]}"
else
  echo " No action needed. Enough MB available."
fi
