set -e
cd ~/delivery-twin
cat > $HOME/.dt-logpin.js <<'LOGPINJS'
// Logging happens on the map itself in Delivery Twin: every spot has Log a stop here, and every dropoff is a pin
// you drag onto the exact building, door or room, then log with the House, Apartment or High-rise questions.
function dtSpotCategory(s) {
  const c = String((s && s.category) || '').toLowerCase();
  if (/fast_food|ice_cream|food_court|burger|pizza|taco/.test(c)) return 'fast_food';
  if (/cafe|coffee/.test(c)) return 'coffee_shop';
  if (/restaurant|bar|pub|diner/.test(c)) return 'restaurant';
  if (/casino/.test(c)) return 'casino';
  if (/grocery|supermarket/.test(c)) return 'grocery';
  if (/liquor|convenience|store|shop/.test(c)) return 'retail';
  if (/hotel|motel|resort/.test(c)) return 'hotel';
  return '';
}
async function dtLogAt(lat, lon, preset) {
  preset = preset || {};
  if (map) map.closePopup();
  try {
    setStatus('resolving address');
    setRadar(3);
    const geo = await reverseGeocode(lat, lon).catch(() => ({}));
    const now = new Date();
    let cls = classify(geo, false, timeOfDay(now));
    if (preset.category && CATEGORIES[preset.category]) {
      cls = { placeType: categoryLabel(preset.category), confidence: 5, formType: 'category', questions: categoryQuestions(preset.category), category: preset.category };
    } else if (cls.formType === 'none') {
      cls = { placeType: categoryLabel('general'), confidence: 3, formType: 'category', questions: categoryQuestions('general'), category: 'general' };
    }
    const entry = {
      id: now.getTime() + '-' + Math.random().toString(36).slice(2, 8),
      timestamp: now.toISOString(),
      lat: lat, lon: lon,
      addressLabel: preset.label || formatAddress(geo.address || {}),
      placeType: cls.placeType, confidence: cls.confidence, formType: cls.formType,
      category: cls.category, questions: cls.questions, answers: [],
      context: preset.context || '',
      icon: (CATEGORIES[cls.category] || CATEGORIES.general).icon,
      twinId: TWIN_ID
    };
    setRadar(0);
    pendingEntry = entry;
    showForm(entry);
  } catch (err) {
    setStatus('log failed, ' + (err.message || 'unknown error'));
    setRadar(0);
  }
}
function dtSpotLogBtn(id) {
  return '<button class="secondary" data-dtlog="' + escapeHtml(id) + '" style="margin-top:6px;">Log a stop here</button>';
}
const DT_PIN_ICON = L.divIcon({ className: 'dt-pin', iconSize: [26, 34], iconAnchor: [13, 32],
  html: '<svg width="26" height="34" viewBox="0 0 26 34" style="display:block"><path d="M13 1.5a11 11 0 0 1 11 11c0 8-11 19.5-11 19.5S2 20.5 2 12.5a11 11 0 0 1 11-11z" fill="#e8710a" stroke="#0a1b2e" stroke-width="2"/><circle cx="13" cy="12.5" r="4.2" fill="#ffffff"/></svg>' });
// A dropoff pin you can drag. Moving it saves the new spot for that delivery.
function dtDropMarker(id, lat, lng, onMoved) {
  const mk = L.marker([lat, lng], { icon: DT_PIN_ICON, draggable: true, autoPan: true });
  mk.on('dragend', async () => {
    const p = mk.getLatLng();
    const res = await sb.from('delivery_twin_deliveries').update({ dropoff_lat: p.lat, dropoff_lng: p.lng }).eq('id', id);
    setStatus(res.error ? 'Could not move the dropoff, ' + String(res.error.message).slice(0, 80) : 'Dropoff moved');
    if (!res.error && onMoved) onMoved(p);
  });
  return mk;
}
let dtPinLayer = null;
function dtPlaceDrop(id, lat, lng, spotId) {
  if (dtPinLayer) { map.removeLayer(dtPinLayer); dtPinLayer = null; }
  dtPinLayer = L.layerGroup().addTo(map);
  const mk = dtDropMarker(id, lat, lng, () => { if (dtLinesFor === spotId) { dtLinesFor = null; dtShowLines(spotId); } }).addTo(dtPinLayer);
  map.setView([lat, lng], Math.max(map.getZoom(), 18));
  let bar = document.getElementById('dtPinBar');
  if (!bar) {
    bar = document.createElement('div');
    bar.id = 'dtPinBar';
    bar.style.cssText = 'position:absolute;left:10px;right:10px;top:120px;z-index:950;background:var(--panel);color:var(--text);border:2px solid var(--accent);display:flex;align-items:center;justify-content:space-between;gap:8px;padding:10px;font-size:13px;';
    document.body.appendChild(bar);
  }
  bar.innerHTML = '<span>Dropoff saved. Drag the orange pin onto the exact building, door or room.</span><span style="display:flex;gap:6px;"><button id="dtPinLog" style="padding:8px 10px;font-size:12px;">Log it</button><button class="secondary" id="dtPinDone" style="padding:8px 10px;font-size:12px;">Done</button></span>';
  bar.style.display = 'flex';
  const close = () => { bar.style.display = 'none'; if (dtPinLayer) { map.removeLayer(dtPinLayer); dtPinLayer = null; } };
  document.getElementById('dtPinDone').addEventListener('click', close);
  document.getElementById('dtPinLog').addEventListener('click', () => { const p = mk.getLatLng(); close(); dtLogAt(p.lat, p.lng, { context: 'Dropoff' }); });
}
document.addEventListener('click', ev => {
  const b = ev.target.closest && ev.target.closest('[data-dtlog]');
  if (!b) return;
  const s = dtFoodSeen[b.getAttribute('data-dtlog')];
  if (!s) return;
  const label = [s.name, s.address].filter(Boolean).join(', ');
  dtLogAt(s.lat, s.lng, s.name ? { category: dtSpotCategory(s), label: label, context: s.name } : {});
});

LOGPINJS
awk 'FNR==NR{code=code $0 "\n"; next} /^function dtLinesBtn\(s\) \{$/{printf "%s", code} {print}' $HOME/.dt-logpin.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f $HOME/.dt-logpin.js
sed -i -e "s|<button data-dtgot=\"' + escapeHtml(d.id) + '\" style=\"margin-top:6px;\">Got a delivery here</button></div>').openPopup();|<button data-dtgot=\"' + escapeHtml(d.id) + '\" style=\"margin-top:6px;\">Got a delivery here</button>' + dtSpotLogBtn(d.id) + '</div>').openPopup();|" -e "s|dtSpotLines(s).join('<br>') + btn + dtLinesBtn(s) + |dtSpotLines(s).join('<br>') + btn + dtSpotLogBtn(s.id) + dtLinesBtn(s) + |" -e "s|^  setStatus('Dropoff saved');$|  setStatus('Dropoff saved');\n  dtPlaceDrop(a.id, pos.coords.latitude, pos.coords.longitude, a.spot);|" -e "s|select('dropoff_lat,dropoff_lng')|select('id,dropoff_lat,dropoff_lng')|" -e "s|^    L.circleMarker(\[r.dropoff_lat, r.dropoff_lng\], { radius: 4, color: '#0a1b2e', weight: 1, fillColor: '#e8710a', fillOpacity: 1 }).addTo(dtLinesLayer);$|    dtDropMarker(r.id, r.dropoff_lat, r.dropoff_lng, () => { dtLinesFor = null; dtShowLines(spotId); }).addTo(dtLinesLayer);|" -e 's|<button id="updateBtn">Log</button>|<button id="updateBtn" style="display:none">Log</button>|' index.html
