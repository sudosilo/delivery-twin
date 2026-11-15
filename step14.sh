set -e
cd ~/delivery-twin
cat > $HOME/.dt-chev.js <<'CHEVJS'
// Small chevrons along a delivery line, pointing from the pickup spot toward the dropoff.
function dtChevrons(aLat, aLng, bLat, bLng) {
  const p1 = map.latLngToLayerPoint([aLat, aLng]), p2 = map.latLngToLayerPoint([bLat, bLng]);
  const ang = Math.atan2(p2.y - p1.y, p2.x - p1.x) * 180 / Math.PI;
  const icon = L.divIcon({ className: 'dt-chev', iconSize: [12, 12], iconAnchor: [6, 6],
    html: '<svg width="12" height="12" viewBox="0 0 12 12" style="display:block;transform:rotate(' + ang.toFixed(1) + 'deg)"><path d="M3.5 2.5 L8 6 L3.5 9.5" fill="none" stroke="#0a1b2e" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><path d="M3.5 2.5 L8 6 L3.5 9.5" fill="none" stroke="#e8710a" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>' });
  [0.2, 0.4, 0.6, 0.8].forEach(f => L.marker([aLat + (bLat - aLat) * f, aLng + (bLng - aLng) * f], { icon: icon, interactive: false, keyboard: false }).addTo(dtLinesLayer));
}

CHEVJS
awk 'FNR==NR{code=code $0 "\n"; next} /^function dtLinesBtn\(s\) \{$/{printf "%s", code} {print}' $HOME/.dt-chev.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f $HOME/.dt-chev.js
sed -i "s|^    L.polyline(\[\[spot.lat, spot.lng\], \[r.dropoff_lat, r.dropoff_lng\]\], { color: '#e8710a', weight: 2, opacity: 0.7 }).addTo(dtLinesLayer);$|&\n    dtChevrons(spot.lat, spot.lng, r.dropoff_lat, r.dropoff_lng);|" index.html
