set -e
cat > $HOME/.dt-offers.js <<'OFFERSJS'
// Delivery Twin offer logger. Every offer is kept on the phone and copied to the cloud when signed in.
const DT_OFFERS_KEY = 'dtOffers';
const DT_APPS_KEY = 'dtGigApps';

function dtOffersLoad() {
  try { return JSON.parse(localStorage.getItem(DT_OFFERS_KEY) || '[]'); } catch (e) { return []; }
}
function dtOffersSave(list) {
  try { localStorage.setItem(DT_OFFERS_KEY, JSON.stringify(list)); } catch (e) {}
}
function dtAppsLoad() {
  try { return JSON.parse(localStorage.getItem(DT_APPS_KEY) || '[]'); } catch (e) { return []; }
}
function dtAppsSave(list) {
  try { localStorage.setItem(DT_APPS_KEY, JSON.stringify(list)); } catch (e) {}
}
function dtNum(v) {
  const n = parseFloat(String(v || '').replace(/[^0-9.]/g, ''));
  return isFinite(n) ? n : null;
}
function dtOfferRow(o) {
  return {
    id: o.id, gig_app: o.app || null, offered_at: new Date(o.ts).toISOString(),
    lat: o.lat, lng: o.lng, pay: o.pay, miles: o.miles, minutes: o.minutes,
    pickup: o.pickup || null, dropoff: o.dropoff || null, accepted: o.accepted,
    wait_minutes: o.wait, note: o.note || null, updated_at: new Date().toISOString()
  };
}
async function dtOfferPush(o) {
  if (!(sb && cloudUser)) return;
  try { await sb.from('delivery_twin_offers').upsert(dtOfferRow(o), { onConflict: 'id' }); } catch (e) {}
}
async function dtOffersPull() {
  if (!(sb && cloudUser)) return;
  try {
    const res = await sb.from('delivery_twin_offers').select('*').order('offered_at', { ascending: false }).limit(2000);
    if (!res.data) return;
    const list = dtOffersLoad();
    const have = {};
    list.forEach(o => { have[o.id] = true; });
    res.data.forEach(r => {
      if (have[r.id]) return;
      list.push({
        id: r.id, app: r.gig_app || '', ts: new Date(r.offered_at).getTime(), lat: r.lat, lng: r.lng,
        pay: r.pay === null ? null : Number(r.pay), miles: r.miles === null ? null : Number(r.miles),
        minutes: r.minutes === null ? null : Number(r.minutes), pickup: r.pickup || '', dropoff: r.dropoff || '',
        accepted: r.accepted, wait: r.wait_minutes === null ? null : Number(r.wait_minutes), note: r.note || ''
      });
    });
    list.sort((a, b) => b.ts - a.ts);
    dtOffersSave(list);
  } catch (e) {}
}

function dtCloseMenu() {
  const m = document.getElementById('sideMenu'), ov = document.getElementById('menuOverlay');
  if (m) m.classList.remove('open');
  if (ov) ov.classList.remove('open');
}

function showOfferForm() {
  const panel = document.getElementById('panel');
  const apps = dtAppsLoad();
  const last = dtOffersLoad()[0];
  const pick = last && last.app ? last.app : (apps[0] || '');
  let html = '<h2>Log offer</h2>';
  html += '<div class="meta-line">Time and location are saved on their own.</div>';
  html += '<label class="hz-label" for="dtApp">Gig app</label><select id="dtApp">';
  apps.forEach(a => { html += '<option' + (a === pick ? ' selected' : '') + '>' + escapeHtml(a) + '</option>'; });
  html += '<option value="__new">Add a new app</option></select>';
  html += '<input type="text" id="dtAppNew" placeholder="App name" style="display:' + (apps.length ? 'none' : 'block') + ';margin-top:8px;">';
  html += '<label class="hz-label" for="dtPay">Pay in dollars</label><input type="number" inputmode="decimal" id="dtPay">';
  html += '<label class="hz-label" for="dtMiles">Miles</label><input type="number" inputmode="decimal" id="dtMiles">';
  html += '<label class="hz-label" for="dtMinutes">Minutes the app says it takes</label><input type="number" inputmode="decimal" id="dtMinutes">';
  html += '<label class="hz-label" for="dtPickup">Pickup</label><input type="text" id="dtPickup">';
  html += '<label class="hz-label" for="dtDropoff">Dropoff area</label><input type="text" id="dtDropoff">';
  html += '<label class="hz-label" for="dtWait">Wait at pickup in minutes, if you know it</label><input type="number" inputmode="decimal" id="dtWait">';
  html += '<div id="dtRate" class="meta-line" style="margin-top:8px;"></div>';
  html += '<div class="panel-actions"><button id="dtAccept">Accepted</button><button class="secondary" id="dtDecline">Declined</button><button class="secondary" id="dtCancel">Close</button></div>';
  panel.innerHTML = html;
  panel.scrollTop = 0;
  panel.classList.add('open');
  const sel = document.getElementById('dtApp'), nw = document.getElementById('dtAppNew');
  if (!apps.length) sel.value = '__new';
  sel.addEventListener('change', () => { nw.style.display = sel.value === '__new' ? 'block' : 'none'; if (sel.value === '__new') nw.focus(); });
  const rate = () => {
    const p = dtNum(document.getElementById('dtPay').value), m = dtNum(document.getElementById('dtMiles').value), t = dtNum(document.getElementById('dtMinutes').value);
    const bits = [];
    if (p !== null && m) bits.push('$' + (p / m).toFixed(2) + ' a mile');
    if (p !== null && t) bits.push('$' + (p / t * 60).toFixed(2) + ' an hour');
    document.getElementById('dtRate').textContent = bits.join(', ');
  };
  ['dtPay', 'dtMiles', 'dtMinutes'].forEach(id => document.getElementById(id).addEventListener('input', rate));
  const save = async accepted => {
    let app = sel.value === '__new' ? nw.value.trim() : sel.value;
    if (app && apps.indexOf(app) === -1) { apps.push(app); dtAppsSave(apps); }
    const o = {
      id: 'o' + Date.now().toString(36) + Math.random().toString(36).slice(2, 6),
      app: app || '', ts: Date.now(), lat: null, lng: null,
      pay: dtNum(document.getElementById('dtPay').value), miles: dtNum(document.getElementById('dtMiles').value),
      minutes: dtNum(document.getElementById('dtMinutes').value),
      pickup: document.getElementById('dtPickup').value.trim(), dropoff: document.getElementById('dtDropoff').value.trim(),
      accepted: accepted, wait: dtNum(document.getElementById('dtWait').value), note: ''
    };
    const list = dtOffersLoad();
    list.unshift(o);
    dtOffersSave(list);
    closePanel();
    setStatus((accepted ? 'Accepted' : 'Declined') + ' offer saved');
    try {
      const pos = await getPosition();
      o.lat = pos.coords.latitude; o.lng = pos.coords.longitude;
      const l2 = dtOffersLoad(), i = l2.findIndex(x => x.id === o.id);
      if (i !== -1) { l2[i] = o; dtOffersSave(l2); }
    } catch (e) {}
    dtOfferPush(o);
  };
  document.getElementById('dtAccept').addEventListener('click', () => save(true));
  document.getElementById('dtDecline').addEventListener('click', () => save(false));
  document.getElementById('dtCancel').addEventListener('click', closePanel);
}

function dtStats(list) {
  let pay = 0, miles = 0, mins = 0, acc = 0;
  list.forEach(o => {
    if (o.accepted) acc++;
    if (o.pay !== null && o.miles) { pay += o.pay; miles += o.miles; }
  });
  let pay2 = 0;
  list.forEach(o => { if (o.pay !== null && o.minutes) { pay2 += o.pay; mins += o.minutes; } });
  return {
    count: list.length, accepted: acc,
    perMile: miles ? pay / miles : null, perHour: mins ? pay2 / mins * 60 : null
  };
}
function dtStatsLine(s) {
  const bits = [s.count + (s.count === 1 ? ' offer' : ' offers'), s.accepted + ' accepted'];
  if (s.perMile !== null) bits.push('$' + s.perMile.toFixed(2) + ' a mile');
  if (s.perHour !== null) bits.push('$' + s.perHour.toFixed(2) + ' an hour');
  return bits.join(', ');
}

async function showOffers() {
  const panel = document.getElementById('panel');
  await dtOffersPull();
  const list = dtOffersLoad();
  let html = '<h2>Offers</h2>';
  html += '<div class="meta-line">' + dtStatsLine(dtStats(list)) + '</div>';
  const today = localDay(new Date());
  const todays = list.filter(o => localDay(new Date(o.ts)) === today);
  html += '<div class="question">Today</div><div class="meta-line">' + (todays.length ? dtStatsLine(dtStats(todays)) : 'no offers yet today') + '</div>';
  const byApp = {};
  list.forEach(o => { const k = o.app || 'no app named'; (byApp[k] = byApp[k] || []).push(o); });
  const keys = Object.keys(byApp);
  if (keys.length > 1) {
    html += '<div class="question">By app</div>';
    keys.sort((a, b) => byApp[b].length - byApp[a].length).forEach(k => {
      html += '<div class="meta-line">' + escapeHtml(k) + ', ' + dtStatsLine(dtStats(byApp[k])) + '</div>';
    });
  }
  html += '<div class="question">Latest</div>';
  list.slice(0, 30).forEach(o => {
    const t = new Date(o.ts).toLocaleString([], { weekday: 'short', hour: 'numeric', minute: '2-digit' });
    const bits = [t, escapeHtml(o.app || 'no app named'), o.accepted ? 'accepted' : 'declined'];
    if (o.pay !== null) bits.push('$' + o.pay.toFixed(2));
    if (o.miles) bits.push(o.miles + ' mi');
    if (o.pickup) bits.push(escapeHtml(o.pickup));
    html += '<div class="meta-line" style="padding:6px 0;border-bottom:1px solid var(--line);">' + bits.join(', ') +
      ' <span data-dtdel="' + o.id + '" style="color:var(--accent);cursor:pointer;margin-left:6px;">delete</span></div>';
  });
  if (!list.length) html += '<div class="meta-line">no offers logged yet</div>';
  html += '<div class="panel-actions"><button id="dtLogMore">Log offer</button><button class="secondary" id="dtCloseOffers">Close</button></div>';
  panel.innerHTML = html;
  panel.scrollTop = 0;
  panel.classList.add('open');
  document.getElementById('dtCloseOffers').addEventListener('click', closePanel);
  document.getElementById('dtLogMore').addEventListener('click', showOfferForm);
  panel.querySelectorAll('[data-dtdel]').forEach(el => el.addEventListener('click', async () => {
    const id = el.getAttribute('data-dtdel');
    dtOffersSave(dtOffersLoad().filter(x => x.id !== id));
    if (sb && cloudUser) { try { await sb.from('delivery_twin_offers').delete().eq('id', id); } catch (e) {} }
    showOffers();
  }));
}

document.getElementById('offerDockBtn').addEventListener('click', showOfferForm);
document.getElementById('logOfferBtn').addEventListener('click', () => { dtCloseMenu(); showOfferForm(); });
document.getElementById('offersBtn').addEventListener('click', () => { dtCloseMenu(); showOffers(); });

OFFERSJS
sed -i -e "s/sb\.storage\.from('photos')/sb.storage.from('delivery-twin-photos')/g" -e "s/sb\.from('entries')/sb.from('delivery_twin_entries')/g" -e "s/sb\.from('receipts')/sb.from('delivery_twin_receipts')/g" -e "s/allRows('entries'/allRows('delivery_twin_entries'/" -e "s/allRows('receipts'/allRows('delivery_twin_receipts'/" index.html
git mv field-twin-fonts-v1 delivery-twin-fonts-v1
for f in delivery-twin-fonts-v1/field-twin-*; do git mv "$f" "${f/field-twin-/delivery-twin-}"; done
git mv fieldtwin-api deliverytwin-api
git mv field-twin-companion delivery-twin-companion
for f in $(find delivery-twin-companion -name '*field-twin*' | sort -r); do git mv "$f" "$(dirname $f)/$(basename $f | sed 's/field-twin/delivery-twin/g')"; done
for f in src-tauri/android/FieldTwin*.kt; do git mv "$f" "${f/FieldTwin/DeliveryTwin}"; done
for f in supabase/field-twin-*.sql; do git mv "$f" "${f/field-twin-/delivery-twin-}"; done
FILES=$(git ls-files | grep -v '\.woff2$\|\.bin$\|\.png$\|^step3\.sh$')
sed -i -e 's/fieldtwin-api-production/KEEPA/g' -e 's/field-twin-glaucous/KEEPB/g' -e 's/field-twin-violet/KEEPC/g' -e 's/fieldtwin-session/KEEPD/g' $FILES
sed -i -e 's/FieldTwin/DeliveryTwin/g' -e 's/fieldTwin/deliveryTwin/g' -e 's/field-twin/delivery-twin/g' -e 's/fieldtwin/deliverytwin/g' -e 's/field_twin/delivery_twin/g' -e 's/Field Twin/Delivery Twin/g' -e 's/FIELD TWIN/DELIVERY TWIN/g' $FILES
sed -i -e 's/KEEPA/fieldtwin-api-production/g' -e 's/KEEPB/field-twin-glaucous/g' -e 's/KEEPC/field-twin-violet/g' -e 's/KEEPD/fieldtwin-session/g' $FILES
sed -i 's|<button id="updateBtn">Log</button>|<button id="offerDockBtn">Offer</button>\n  <button id="updateBtn">Log</button>|' index.html
sed -i 's|^  <h3>Capture</h3>$|  <h3>Delivery</h3>\n  <button class="secondary" id="logOfferBtn">Log offer</button>\n  <button class="secondary" id="offersBtn">Offers</button>\n  <h3>Capture</h3>|' index.html
sed -i 's/ style="display:none" style="display:none"/ style="display:none"/g' index.html
sed -i -e 's/^  #updateBtn, #receiptDockBtn {/  #updateBtn, #receiptDockBtn, #offerDockBtn {/' -e 's/^  #receiptDockBtn { background/  #receiptDockBtn, #offerDockBtn { background/' -e 's/^  #updateBtn:active, #receiptDockBtn:active {/  #updateBtn:active, #receiptDockBtn:active, #offerDockBtn:active {/' -e 's/^  #actionBar.three #updateBtn, #actionBar.three #receiptDockBtn {/  #actionBar.three #updateBtn, #actionBar.three #receiptDockBtn, #actionBar.three #offerDockBtn {/' -e 's/^  :root\[data-theme=night\] #receiptDockBtn {/  :root[data-theme=night] #receiptDockBtn, :root[data-theme=night] #offerDockBtn {/' index.html
awk 'FNR==NR{code=code $0 "\n"; next} /^function dayLogN\(n, word\) \{$/{printf "%s", code} {print}' $HOME/.dt-offers.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f "$HOME/.dt-offers.js"
