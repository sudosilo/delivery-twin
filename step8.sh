set -e
cat > $HOME/.dt-deliv.js <<'DELIVJS'
// Delivery Twin deliveries: a pickup at a spot stays open until you tap Dropped off, which saves where it ended.
// Delivery lines draws a straight line from a spot to every dropoff you made from it.
const DT_ACTIVE_KEY = 'dtActiveDelivery';
let dtLinesLayer = null;
let dtLinesFor = null;

function dtActiveLoad() {
  try { return JSON.parse(localStorage.getItem(DT_ACTIVE_KEY) || 'null'); } catch (e) { return null; }
}
function dtActiveSave(a) {
  try { if (a) localStorage.setItem(DT_ACTIVE_KEY, JSON.stringify(a)); else localStorage.removeItem(DT_ACTIVE_KEY); } catch (e) {}
  dtActiveBar();
}

function dtActiveBar() {
  let bar = document.getElementById('dtDropBar');
  const a = dtActiveLoad();
  if (!a) { if (bar) bar.style.display = 'none'; return; }
  if (!bar) {
    bar = document.createElement('div');
    bar.id = 'dtDropBar';
    bar.style.cssText = 'position:absolute;left:10px;right:10px;top:120px;z-index:950;background:var(--panel);color:var(--text);border:2px solid var(--accent);display:flex;align-items:center;justify-content:space-between;gap:8px;padding:10px;font-size:13px;';
    bar.innerHTML = '<span id="dtDropText"></span><span style="display:flex;gap:6px;"><button id="dtDropBtn" style="padding:8px 10px;font-size:12px;">Dropped off</button><button class="secondary" id="dtDropCancel" style="padding:8px 10px;font-size:12px;">Cancel</button></span>';
    document.body.appendChild(bar);
    document.getElementById('dtDropBtn').addEventListener('click', dtDropOff);
    document.getElementById('dtDropCancel').addEventListener('click', async () => {
      const cur = dtActiveLoad();
      if (cur && sb && cloudUser) { try { await sb.from('delivery_twin_deliveries').delete().eq('id', cur.id); } catch (e) {} }
      dtActiveSave(null);
      setStatus('Delivery canceled');
    });
  }
  document.getElementById('dtDropText').textContent = 'Delivering from ' + (a.name || 'a spot');
  bar.style.display = 'flex';
}

async function dtStartDelivery(spotId, app, s) {
  if (!(sb && cloudUser)) return;
  const id = 'd' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
  const res = await sb.from('delivery_twin_deliveries').insert({ id: id, spot_id: spotId, gig_app: app || null });
  if (res.error) { setStatus('Could not start delivery, ' + String(res.error.message).slice(0, 80)); return; }
  dtActiveSave({ id: id, spot: spotId, name: s && s.name ? s.name : '' });
}

async function dtDropOff() {
  const a = dtActiveLoad();
  if (!a) return;
  setStatus('Getting your location');
  let pos;
  try { pos = await getPosition(); } catch (e) { setStatus('No location, try Dropped off again'); return; }
  const res = await sb.from('delivery_twin_deliveries').update({ dropoff_lat: pos.coords.latitude, dropoff_lng: pos.coords.longitude, dropped_at: new Date().toISOString() }).eq('id', a.id);
  if (res.error) { setStatus('Could not save dropoff, ' + String(res.error.message).slice(0, 80)); return; }
  dtActiveSave(null);
  setStatus('Dropoff saved');
  if (dtLinesFor === a.spot) { dtLinesFor = null; dtShowLines(a.spot); }
}

function dtLinesBtn(s) {
  return '<button class="secondary" data-dtlines="' + escapeHtml(s.id) + '" style="margin-top:6px;">' + (dtLinesFor === s.id ? 'Hide delivery lines' : 'Delivery lines') + '</button>';
}

async function dtShowLines(spotId) {
  if (dtLinesLayer) { map.removeLayer(dtLinesLayer); dtLinesLayer = null; }
  if (dtLinesFor === spotId) { dtLinesFor = null; setStatus('Delivery lines hidden'); return; }
  const spot = dtFoodSeen[spotId];
  if (!spot) return;
  const res = await sb.from('delivery_twin_deliveries').select('dropoff_lat,dropoff_lng').eq('spot_id', spotId).not('dropoff_lat', 'is', null).limit(2000);
  const rows = res.data || [];
  dtLinesFor = spotId;
  dtLinesLayer = L.layerGroup().addTo(map);
  const pts = [[spot.lat, spot.lng]];
  rows.forEach(r => {
    L.polyline([[spot.lat, spot.lng], [r.dropoff_lat, r.dropoff_lng]], { color: '#e8710a', weight: 2, opacity: 0.7 }).addTo(dtLinesLayer);
    L.circleMarker([r.dropoff_lat, r.dropoff_lng], { radius: 4, color: '#0a1b2e', weight: 1, fillColor: '#e8710a', fillOpacity: 1 }).addTo(dtLinesLayer);
    pts.push([r.dropoff_lat, r.dropoff_lng]);
  });
  map.closePopup();
  if (rows.length) map.fitBounds(pts, { padding: [40, 40] });
  setStatus(rows.length ? rows.length + (rows.length === 1 ? ' delivery' : ' deliveries') + ' from ' + (spot.name || 'this spot') : 'No dropoffs saved from this spot yet');
}

document.addEventListener('click', ev => {
  const b = ev.target.closest && ev.target.closest('[data-dtlines]');
  if (b) dtShowLines(b.getAttribute('data-dtlines'));
});
setTimeout(dtActiveBar, 1500);

DELIVJS
awk 'FNR==NR{code=code $0 "\n"; next} /^function dayLogN\(n, word\) \{$/{printf "%s", code} {print}' $HOME/.dt-deliv.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f "$HOME/.dt-deliv.js"
sed -i -e "s|^  if (app) html += '<div class=\"meta-line\">Delivery logged for ' + escapeHtml(app) + '</div>';$|  dtStartDelivery(id, app, s);\n  if (app) html += '<div class=\"meta-line\">Delivery logged for ' + escapeHtml(app) + '</div>';\n  html += '<div class=\"meta-line\">Tap Dropped off when you hand it over.</div>';|" -e "s|dtSpotLines(s).join('<br>') + btn + '</div>'|dtSpotLines(s).join('<br>') + btn + dtLinesBtn(s) + '</div>'|" index.html
