set -e
awk 'BEGIN{skip=0} /^\/\/ Delivery Twin food spots: /{skip=1} /^function dayLogN\(n, word\) \{$/{skip=0} !skip{print}' index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
cat > $HOME/.dt-fog.js <<'FOGJS'
// Delivery Twin spots: every known food and liquor spot shows as a small gray square until a driver confirms a delivery there.
let dtFoodOn = localStorage.getItem('dtFoodOn') !== '0';
let dtFoodLayer = null;
let dtFoodTimer = null;
let dtFoodBusy = false;
let dtFoodSeen = {};
let dtCanvas = null;

const DtSquare = L.CircleMarker.extend({
  _updatePath: function () {
    const r = this._renderer;
    if (!r._drawing || this._empty()) return;
    const p = this._point, ctx = r._ctx, s = this._radius;
    ctx.beginPath();
    ctx.rect(p.x - s, p.y - s, s * 2, s * 2);
    r._fillStroke(ctx, this);
  }
});

function dtSpotLines(s) {
  const bits = ['<b>' + escapeHtml(s.name || 'Unnamed') + '</b>'];
  if (s.brand && s.brand !== s.name) bits.push(escapeHtml(s.brand));
  if (s.category) bits.push(escapeHtml(String(s.category).replace(/_/g, ' ')));
  const addr = [s.address, s.city, s.zip].filter(Boolean).join(', ');
  if (addr) bits.push(escapeHtml(addr));
  if (s.phone) bits.push(escapeHtml(s.phone));
  if (s.website) bits.push(escapeHtml(String(s.website).replace(/^https?:\/\//, '').replace(/\/$/, '')));
  if (s.hours) bits.push(escapeHtml(s.hours));
  bits.push(s.drive_thru === true ? 'Drive-thru' : s.drive_thru === false ? 'No drive-thru' : 'Drive-thru not known');
  if (s.gig_apps && s.gig_apps.length) bits.push('Apps: ' + escapeHtml(s.gig_apps.join(', ')));
  if (s.notes) bits.push(escapeHtml(s.notes));
  return bits;
}

async function dtFoodLoad() {
  if (!dtFoodOn || !map || dtFoodBusy) return;
  if (!(sb && cloudUser)) { setStatus('Sign in to see spots'); return; }
  dtFoodBusy = true;
  try {
    const b = map.getBounds();
    const res = await sb.rpc('dt_spot_dots', { s: b.getSouth(), w: b.getWest(), n: b.getNorth(), e: b.getEast() });
    if (res.error) { setStatus('Spots failed, ' + String(res.error.message).slice(0, 80)); return; }
    if (!dtCanvas) dtCanvas = L.canvas({ padding: 0.3 });
    if (!dtFoodLayer) dtFoodLayer = L.layerGroup().addTo(map);
    dtFoodLayer.clearLayers();
    dtFoodSeen = {};
    let open = 0;
    const big = map.getZoom() >= 15;
    (res.data || []).forEach(d => {
      dtFoodSeen[d.id] = d;
      if (d.revealed) open++;
      const m = d.revealed
        ? new DtSquare([d.lat, d.lng], { renderer: dtCanvas, radius: big ? 6 : 4, color: '#0a1b2e', weight: 1.5, fillColor: d.kind === 'liquor' ? '#8e44ad' : '#2e9e4f', fillOpacity: 1 })
        : new DtSquare([d.lat, d.lng], { renderer: dtCanvas, radius: big ? 3 : 2, stroke: false, fillColor: '#8a939c', fillOpacity: 0.55 });
      m.on('click', () => dtSpotTap(d, m));
      m.addTo(dtFoodLayer);
    });
    setStatus((res.data || []).length + ' spots here, ' + open + ' uncovered');
  } catch (err) {
    setStatus('Spots failed to load');
  } finally {
    dtFoodBusy = false;
  }
}

async function dtSpotTap(d, m) {
  if (!d.revealed) {
    m.bindPopup('<div style="font-size:14px;line-height:1.4;">Something is here.<br><button data-dtgot="' + escapeHtml(d.id) + '" style="margin-top:6px;">Got a delivery here</button></div>').openPopup();
    return;
  }
  const res = await sb.from('delivery_twin_food_spots').select('*').eq('id', d.id).limit(1);
  const s = res.data && res.data[0];
  if (!s) return;
  dtFoodSeen[d.id] = Object.assign({}, d, s);
  const btn = s.source === 'added' && s.user_id === cloudUser.id
    ? '<button class="secondary" data-dtedit="' + escapeHtml(s.id) + '" style="margin-top:6px;">Edit</button>'
    : '<button class="secondary" data-dtgot="' + escapeHtml(s.id) + '" style="margin-top:6px;">Another delivery here</button>';
  m.bindPopup('<div style="font-size:14px;line-height:1.4;">' + dtSpotLines(s).join('<br>') + btn + '</div>').openPopup();
}

async function dtReveal(id) {
  const last = dtOffersLoad()[0];
  const app = last && last.app ? last.app : '';
  const res = await sb.rpc('dt_reveal', { spot: id, app: app });
  if (res.error) { setStatus('Could not save, ' + String(res.error.message).slice(0, 80)); return; }
  const s = res.data && res.data[0];
  if (map) map.closePopup();
  const panel = document.getElementById('panel');
  let html = '<h2>Spot uncovered</h2>';
  if (s) html += '<div class="meta-line">' + dtSpotLines(s).join('</div><div class="meta-line">') + '</div>';
  if (app) html += '<div class="meta-line">Delivery logged for ' + escapeHtml(app) + '</div>';
  try {
    const c = await sb.rpc('dt_reveal_count');
    if (c.data && c.data[0]) html += '<div class="question">You have uncovered ' + c.data[0].revealed + ' spots</div>';
  } catch (e) {}
  html += '<div class="panel-actions"><button class="secondary" id="dtRevealClose">Close</button></div>';
  panel.innerHTML = html;
  panel.scrollTop = 0;
  panel.classList.add('open');
  document.getElementById('dtRevealClose').addEventListener('click', closePanel);
  dtFoodLoad();
}

function dtFoodSoon() {
  clearTimeout(dtFoodTimer);
  dtFoodTimer = setTimeout(dtFoodLoad, 600);
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
  let html = '<h2>' + (editing ? 'Edit spot' : 'Add spot') + '</h2>';
  html += '<div class="meta-line">Anywhere that sells food or drinks or lets drivers pick up an order.</div>';
  html += '<label class="hz-label" for="fsKind">Kind</label><select id="fsKind"><option value="food"' + (s.kind !== 'liquor' ? ' selected' : '') + '>Food</option><option value="liquor"' + (s.kind === 'liquor' ? ' selected' : '') + '>Liquor</option></select>';
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
    if (!(sb && cloudUser)) { setStatus('Sign in first to save spots'); return; }
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
      source: 'added', source_ref: editing ? (s.source_ref || null) : null,
      user_id: cloudUser.id, kind: document.getElementById('fsKind').value, name: name,
      brand: document.getElementById('fsBrand').value.trim() || null,
      category: s.category || null, lat: lat, lng: lng, address: document.getElementById('fsAddr').value.trim() || null,
      drive_thru: dv === 'yes' ? true : dv === 'no' ? false : null,
      gig_apps: document.getElementById('fsApps').value.split(',').map(x => x.trim()).filter(Boolean),
      hours: document.getElementById('fsHours').value.trim() || null,
      notes: document.getElementById('fsNotes').value.trim() || null, updated_at: new Date().toISOString()
    };
    const res = await sb.from('delivery_twin_food_spots').upsert(row, { onConflict: 'id' });
    if (res.error) { setStatus('Save failed, ' + String(res.error.message).slice(0, 80)); return; }
    closePanel();
    setStatus('Spot saved');
    if (!dtFoodOn) dtFoodSet(true); else dtFoodLoad();
  });
  if (editing) document.getElementById('fsDelete').addEventListener('click', async () => {
    await sb.from('delivery_twin_food_spots').delete().eq('id', s.id);
    closePanel();
    setStatus('Spot deleted');
    dtFoodLoad();
  });
}

document.getElementById('dtFoodBtn').addEventListener('click', () => { dtFoodSet(!dtFoodOn); });
document.getElementById('addFoodSpotBtn').addEventListener('click', () => { dtCloseMenu(); showFoodSpotForm(null); });
document.addEventListener('click', ev => {
  const g = ev.target.closest && ev.target.closest('[data-dtgot]');
  if (g) { dtReveal(g.getAttribute('data-dtgot')); return; }
  const a = ev.target.closest && ev.target.closest('[data-dtedit]');
  if (!a) return;
  const sp = dtFoodSeen[a.getAttribute('data-dtedit')];
  if (!sp) return;
  if (map) map.closePopup();
  showFoodSpotForm(sp);
});
setTimeout(() => {
  setToggle('dtFoodBtn', dtFoodOn);
  if (map) map.on('moveend', () => { if (dtFoodOn) dtFoodSoon(); });
  if (dtFoodOn) dtFoodLoad();
}, 3000);

FOGJS
awk 'FNR==NR{code=code $0 "\n"; next} /^function dayLogN\(n, word\) \{$/{printf "%s", code} {print}' $HOME/.dt-fog.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f "$HOME/.dt-fog.js"
sed -i -e 's|<h3>Food spots</h3>|<h3>Spots</h3>|' -e 's|<span>Food spots on map</span>|<span>Spots on map</span>|' -e 's|id="addFoodSpotBtn">Add food spot</button>|id="addFoodSpotBtn">Add spot</button>|' index.html
