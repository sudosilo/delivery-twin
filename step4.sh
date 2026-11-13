set -e
cat > $HOME/.dt-food.js <<'FOODJS'
// Delivery Twin food spots: chain and drive-thru spots from OpenStreetMap, plus spots drivers add by hand.
let dtFoodOn = localStorage.getItem('dtFoodOn') === '1';
let dtFoodLayer = null;
let dtFoodTimer = null;
let dtFoodBusy = false;
const DT_OVERPASS = 'https://overpass-api.de/api/interpreter';

function dtFoodColor(s) {
  if (s.source === 'added') return '#2e9e4f';
  if (s.drive_thru) return '#e8710a';
  return '#0b4ea2';
}

function dtFoodPopup(s) {
  const bits = ['<b>' + escapeHtml(s.name || 'Unnamed') + '</b>'];
  if (s.brand && s.brand !== s.name) bits.push(escapeHtml(s.brand));
  if (s.address) bits.push(escapeHtml(s.address));
  bits.push(s.drive_thru === true ? 'Drive-thru' : s.drive_thru === false ? 'No drive-thru' : 'Drive-thru not known');
  if (s.gig_apps && s.gig_apps.length) bits.push('Apps: ' + escapeHtml(s.gig_apps.join(', ')));
  if (s.hours) bits.push(escapeHtml(s.hours));
  if (s.notes) bits.push(escapeHtml(s.notes));
  bits.push(s.source === 'added' ? 'Added by a driver' : 'From OpenStreetMap');
  const btn = s.source === 'added'
    ? (cloudUser && s.user_id === cloudUser.id ? '<button class="secondary" data-dtedit="' + escapeHtml(s.id) + '" style="margin-top:6px;">Edit</button>' : '')
    : '<button class="secondary" data-dtosm="' + escapeHtml(s.id) + '" style="margin-top:6px;">Add details</button>';
  return '<div style="font-size:14px;line-height:1.4;">' + bits.join('<br>') + btn + '</div>';
}

let dtFoodSeen = {};

async function dtFoodLoad() {
  if (!dtFoodOn || !map || dtFoodBusy) return;
  if (map.getZoom() < 12) { setStatus('Zoom in to see food spots'); if (dtFoodLayer) dtFoodLayer.clearLayers(); return; }
  dtFoodBusy = true;
  const b = map.getBounds();
  const s = b.getSouth(), w = b.getWest(), n = b.getNorth(), e = b.getEast();
  const spots = [];
  const linked = {};
  if (sb && cloudUser) {
    try {
      const res = await sb.from('delivery_twin_food_spots').select('*').gte('lat', s).lte('lat', n).gte('lng', w).lte('lng', e).limit(2000);
      (res.data || []).forEach(r => { spots.push(r); if (r.source_ref) linked[r.source_ref] = true; });
    } catch (err) {}
  }
  try {
    const box = s + ',' + w + ',' + n + ',' + e;
    const q = '[out:json][timeout:25];(' +
      'nwr["amenity"="fast_food"](' + box + ');' +
      'nwr["amenity"~"^(restaurant|cafe|ice_cream)$"]["drive_through"="yes"](' + box + ');' +
      ');out center tags 1500;';
    const r = await fetch(DT_OVERPASS, { method: 'POST', body: 'data=' + encodeURIComponent(q), headers: { 'Content-Type': 'application/x-www-form-urlencoded' } });
    const j = await r.json();
    (j.elements || []).forEach(el => {
      const t = el.tags || {};
      const ref = 'osm:' + el.type + '/' + el.id;
      if (linked[ref]) return;
      const lat = el.lat !== undefined ? el.lat : el.center && el.center.lat;
      const lng = el.lon !== undefined ? el.lon : el.center && el.center.lon;
      if (lat === undefined || lng === undefined) return;
      const addr = [[t['addr:housenumber'], t['addr:street']].filter(Boolean).join(' '), t['addr:city']].filter(Boolean).join(', ');
      spots.push({
        id: ref, source: 'osm', source_ref: ref, name: t.name || t.brand || 'Unnamed', brand: t.brand || '',
        category: t.amenity || '', lat: lat, lng: lng, address: addr,
        drive_thru: t.drive_through === 'yes' ? true : t.drive_through === 'no' ? false : null,
        hours: t.opening_hours || '', gig_apps: null, notes: ''
      });
    });
  } catch (err) {
    setStatus('OpenStreetMap is busy, showing driver spots only');
  }
  if (!dtFoodLayer) dtFoodLayer = L.layerGroup().addTo(map);
  dtFoodLayer.clearLayers();
  dtFoodSeen = {};
  spots.forEach(sp => {
    dtFoodSeen[sp.id] = sp;
    L.circleMarker([sp.lat, sp.lng], { radius: 7, color: '#0a1b2e', weight: 2, fillColor: dtFoodColor(sp), fillOpacity: 0.9 })
      .bindPopup(dtFoodPopup(sp)).addTo(dtFoodLayer);
  });
  setStatus(spots.length + ' food spots here');
  dtFoodBusy = false;
}

function dtFoodSoon() {
  clearTimeout(dtFoodTimer);
  dtFoodTimer = setTimeout(dtFoodLoad, 800);
}

function dtFoodSet(on) {
  dtFoodOn = on;
  try { localStorage.setItem('dtFoodOn', on ? '1' : '0'); } catch (e) {}
  setToggle('dtFoodBtn', on);
  if (on) dtFoodLoad();
  else if (dtFoodLayer) dtFoodLayer.clearLayers();
}

function showFoodSpotForm(base) {
  const panel = document.getElementById('panel');
  const s = base || {};
  const editing = s.source === 'added' && s.id;
  let html = '<h2>' + (editing ? 'Edit food spot' : 'Add food spot') + '</h2>';
  html += '<div class="meta-line">Anywhere that sells food or lets drivers pick up food.</div>';
  html += '<label class="hz-label" for="fsName">Name</label><input type="text" id="fsName" value="' + escapeHtml(s.name || '') + '">';
  html += '<label class="hz-label" for="fsBrand">Chain, leave empty if independent</label><input type="text" id="fsBrand" value="' + escapeHtml(s.brand || '') + '">';
  html += '<label class="hz-label" for="fsAddr">Address</label><input type="text" id="fsAddr" value="' + escapeHtml(s.address || '') + '">';
  html += '<label class="hz-label" for="fsDrive">Drive-thru</label><select id="fsDrive">' +
    '<option value=""' + (s.drive_thru == null ? ' selected' : '') + '>Not known</option>' +
    '<option value="yes"' + (s.drive_thru === true ? ' selected' : '') + '>Yes</option>' +
    '<option value="no"' + (s.drive_thru === false ? ' selected' : '') + '>No</option></select>';
  html += '<label class="hz-label" for="fsApps">Gig apps it shows up on, separated by commas</label><input type="text" id="fsApps" value="' + escapeHtml((s.gig_apps || []).join(', ')) + '">';
  html += '<label class="hz-label" for="fsHours">Hours</label><input type="text" id="fsHours" value="' + escapeHtml(s.hours || '') + '">';
  html += '<label class="hz-label" for="fsNotes">Notes, like pickup door or parking</label><textarea id="fsNotes">' + escapeHtml(s.notes || '') + '</textarea>';
  if (!base) html += '<label class="hz-label" for="fsWhere">Where the pin goes</label><select id="fsWhere"><option value="here">Where I am now</option><option value="center">Center of the map</option></select>';
  html += '<div class="panel-actions"><button id="fsSave">Save</button>' + (editing ? '<button class="secondary" id="fsDelete">Delete</button>' : '') + '<button class="secondary" id="fsClose">Close</button></div>';
  panel.innerHTML = html;
  panel.scrollTop = 0;
  panel.classList.add('open');
  document.getElementById('fsClose').addEventListener('click', closePanel);
  document.getElementById('fsSave').addEventListener('click', async () => {
    if (!(sb && cloudUser)) { setStatus('Sign in first to save food spots'); return; }
    const name = document.getElementById('fsName').value.trim();
    if (!name) { setStatus('Give the spot a name'); return; }
    let lat = s.lat, lng = s.lng;
    if (!base) {
      if (document.getElementById('fsWhere').value === 'here') {
        try { const pos = await getPosition(); lat = pos.coords.latitude; lng = pos.coords.longitude; }
        catch (e) { setStatus('No location, using map center'); }
      }
      if (lat === undefined) { const c = map.getCenter(); lat = c.lat; lng = c.lng; }
    }
    const dv = document.getElementById('fsDrive').value;
    const row = {
      id: editing ? s.id : 'f' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      source: 'added', source_ref: editing ? (s.source_ref || null) : (s.source === 'osm' ? s.source_ref : null),
      user_id: cloudUser.id, name: name, brand: document.getElementById('fsBrand').value.trim() || null,
      category: s.category || null, lat: lat, lng: lng, address: document.getElementById('fsAddr').value.trim() || null,
      drive_thru: dv === 'yes' ? true : dv === 'no' ? false : null,
      gig_apps: document.getElementById('fsApps').value.split(',').map(x => x.trim()).filter(Boolean),
      hours: document.getElementById('fsHours').value.trim() || null,
      notes: document.getElementById('fsNotes').value.trim() || null, updated_at: new Date().toISOString()
    };
    const res = await sb.from('delivery_twin_food_spots').upsert(row, { onConflict: 'id' });
    if (res.error) { setStatus('Save failed, ' + String(res.error.message).slice(0, 80)); return; }
    closePanel();
    setStatus('Food spot saved');
    if (!dtFoodOn) dtFoodSet(true); else dtFoodLoad();
  });
  if (editing) document.getElementById('fsDelete').addEventListener('click', async () => {
    await sb.from('delivery_twin_food_spots').delete().eq('id', s.id);
    closePanel();
    setStatus('Food spot deleted');
    dtFoodLoad();
  });
}

document.getElementById('dtFoodBtn').addEventListener('click', () => { dtFoodSet(!dtFoodOn); });
document.getElementById('addFoodSpotBtn').addEventListener('click', () => { dtCloseMenu(); showFoodSpotForm(null); });
document.addEventListener('click', ev => {
  const a = ev.target.closest && ev.target.closest('[data-dtosm],[data-dtedit]');
  if (!a) return;
  const id = a.getAttribute('data-dtosm') || a.getAttribute('data-dtedit');
  const sp = dtFoodSeen[id];
  if (!sp) return;
  if (map) map.closePopup();
  showFoodSpotForm(sp);
});
setTimeout(() => {
  setToggle('dtFoodBtn', dtFoodOn);
  if (map) map.on('moveend', () => { if (dtFoodOn) dtFoodSoon(); });
  if (dtFoodOn) dtFoodLoad();
}, 3000);

FOODJS
sed -i 's|^  <h3>Capture</h3>$|  <h3>Food spots</h3>\n  <button class="secondary tg" id="dtFoodBtn" aria-pressed="false"><span>Food spots on map</span><i class="tg-sw" aria-hidden="true"></i></button>\n  <button class="secondary" id="addFoodSpotBtn">Add food spot</button>\n  <h3>Capture</h3>|' index.html
awk 'FNR==NR{code=code $0 "\n"; next} /^function dayLogN\(n, word\) \{$/{printf "%s", code} {print}' $HOME/.dt-food.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f "$HOME/.dt-food.js"
