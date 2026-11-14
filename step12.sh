set -e
cd ~/delivery-twin
cat > $HOME/.dt-chat.js <<'CHATJS'
// Driver Chat: Delivery Twin's own private chat, on Delivery Twin's own database tables, signed in with the
// same account as the rest of Delivery Twin. It shares nothing with Cat Command Chat or Field Twin.
// With alerts on, a message from someone else flashes the screen in rainbow colors for a moment.
let fcMember = false, fcChan = null, fcMsgs = [], fcNames = {}, fcAlerts = false, fcUnread = 0;
try { fcAlerts = localStorage.getItem('dtChatAlerts') === '1'; } catch (e) {}
async function fcStart() {
  if (!(sb && cloudUser)) return false;
  try {
    const r = await sb.rpc('dt_chat_member');
    fcMember = r.data === true;
    if (fcMember) { await fcLoadNames(); fcListen(); }
    return true;
  } catch (e) { return false; }
}
async function fcLoadNames() {
  try { const n = await sb.from('delivery_twin_chat_names').select('id,name,color'); (n.data || []).forEach(x => { fcNames[x.id] = x; }); } catch (e) {}
}
function fcName(id) { return id === (cloudUser && cloudUser.id) ? 'You' : ((fcNames[id] && fcNames[id].name) || 'Someone'); }
function fcListen() {
  if (fcChan || !sb) return;
  fcChan = sb.channel('delivery-twin-chat')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'delivery_twin_chat_messages' }, p => {
      const m = p.new;
      if (!m || fcMsgs.some(x => x.id === m.id)) return;
      fcMsgs.push(m);
      if (!fcNames[m.sender]) fcLoadNames();
      const mine = cloudUser && m.sender === cloudUser.id;
      const open = document.getElementById('fcList');
      if (open) fcDraw(); else if (!mine) { fcUnread++; fcBadge(); }
      if (!mine && fcAlerts) fcFlash();
    })
    .subscribe();
}
function fcFlash() {
  const old = document.getElementById('fcStar');
  if (old) old.remove();
  const d = document.createElement('div');
  d.id = 'fcStar';
  document.body.appendChild(d);
  setTimeout(() => d.remove(), 1300);
}
function fcBadge() {
  const b = document.getElementById('fieldChatOpen');
  if (b) b.textContent = fcUnread ? 'Open Driver Chat (' + fcUnread + ' new)' : 'Open Driver Chat';
}
async function fcSetAlerts(on) {
  fcAlerts = on;
  try { localStorage.setItem('dtChatAlerts', on ? '1' : '0'); } catch (e) {}
  setToggle('fieldChatBtn', on);
  if (on) { await fcStart(); if (!fcMember) setStatus('open Driver Chat once to join with an invite code'); }
}
function fcDraw() {
  const list = document.getElementById('fcList');
  if (!list) return;
  list.innerHTML = fcMsgs.filter(m => !m.deleted_at).slice(-80).map(m => '<div class="fc-msg' + (cloudUser && m.sender === cloudUser.id ? ' mine' : '') + '"><b>' + escapeHtml(fcName(m.sender)) + '</b> <span class="meta-line">' + new Date(m.created_at).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }) + '</span><div>' + escapeHtml(m.body) + '</div></div>').join('') || '<div class="meta-line">No messages yet.</div>';
  list.scrollTop = list.scrollHeight;
}
async function fcOpen() {
  const panel = document.getElementById('panel');
  panel.innerHTML = '<h2>Driver Chat</h2><div class="meta-line" id="fcMsg">Connecting.</div>';
  panel.classList.add('open');
  if (!(sb && cloudUser)) { document.getElementById('fcMsg').textContent = 'Sign in to Delivery Twin first, under Account and profile.'; return; }
  if (!(await fcStart())) { document.getElementById('fcMsg').textContent = 'Could not reach the chat. Check the signal and try again.'; return; }
  fcUnread = 0; fcBadge();
  if (!fcMember) {
    panel.innerHTML = '<h2>Driver Chat</h2><div class="meta-line">Driver Chat is private to Delivery Twin drivers. Ask a member for an invite code.</div>' +
      '<input type="text" id="fcCode" autocomplete="off" placeholder="Invite code"><input type="text" id="fcNameIn" autocomplete="off" placeholder="Your name in the chat">' +
      '<div class="meta-line" id="fcErr"></div><div class="panel-actions"><button id="fcJoin">Join</button><button class="secondary" id="fcClose">Close</button></div>';
    document.getElementById('fcClose').addEventListener('click', closePanel);
    document.getElementById('fcJoin').addEventListener('click', async () => {
      const code = document.getElementById('fcCode').value.trim();
      const name = document.getElementById('fcNameIn').value.trim();
      const err = document.getElementById('fcErr');
      if (!code || !name) { err.textContent = 'Type the invite code and your name.'; return; }
      err.textContent = 'Joining.';
      const r = await sb.rpc('dt_chat_join', { code: code });
      if (r.error || r.data !== true) { err.textContent = 'That code did not work. Check it with the person who invited you.'; return; }
      await sb.from('delivery_twin_chat_names').upsert({ id: cloudUser.id, name: name, color: '#0b4ea2' });
      fcMember = true;
      await fcLoadNames();
      fcListen();
      fcOpen();
    });
    return;
  }
  panel.innerHTML = '<h2>Driver Chat</h2><div id="fcList" style="max-height:46vh;overflow-y:auto;margin:6px 0;"></div>' +
    '<textarea id="fcText" rows="2" placeholder="Message the other drivers"></textarea>' +
    '<div class="panel-actions"><button id="fcSend">Send</button><button class="secondary" id="fcInvite">Invite code</button><button class="secondary" id="fcClose">Close</button></div>' +
    '<div class="meta-line" id="fcInviteOut"></div>';
  document.getElementById('fcClose').addEventListener('click', closePanel);
  document.getElementById('fcInvite').addEventListener('click', async () => {
    const out = document.getElementById('fcInviteOut');
    const r = await sb.rpc('dt_chat_invite', { p_max_uses: 1, p_days: 7 });
    out.textContent = r.error ? 'Could not make a code, ' + r.error.message : 'Invite code, good for one person for seven days: ' + r.data;
  });
  const send = async () => {
    const t = document.getElementById('fcText');
    const body = t.value.trim();
    if (!body) return;
    t.value = '';
    const r = await sb.from('delivery_twin_chat_messages').insert({ body: body }).select().single();
    if (r.error) { t.value = body; setStatus('message did not send, ' + r.error.message); return; }
    if (r.data && !fcMsgs.some(x => x.id === r.data.id)) { fcMsgs.push(r.data); fcDraw(); }
  };
  document.getElementById('fcSend').addEventListener('click', send);
  try {
    const r = await sb.from('delivery_twin_chat_messages').select('*').is('deleted_at', null).order('id', { ascending: false }).limit(80);
    if (!r.error) fcMsgs = (r.data || []).reverse();
  } catch (e) {}
  fcDraw();
}
setTimeout(() => { setToggle('fieldChatBtn', fcAlerts); if (fcAlerts) fcStart(); }, 4000);
CHATJS
cat > $HOME/.dt-help.js <<'HELPJS'
  html += '<div class="question">Delivery Twin</div>';
  html += '<div>A map and logbook for delivery drivers on any gig app. It runs in the browser and as an Android app, and everything saves to your Delivery Twin account. Nothing is shared with Field Twin.</div>';
  html += '<div class="question">Offers</div>';
  html += '<div>Tap Offer on the bottom bar each time an app sends you an offer. Pick the app, type the pay, miles and minutes, then tap Accepted or Declined. Time and location save on their own. The Offers tab shows pay per mile and per hour, for today and by app.</div>';
  html += '<div class="question">Spots</div>';
  html += '<div>Every known restaurant, fast food place, cafe, bar and liquor store shows as the same small gray square. Tap one and choose Got a delivery here to uncover it, which fills in its name, address, phone, hours and drive-thru. Uncovered food spots turn green and liquor spots turn purple. Add spot puts a place on the map that is not there yet.</div>';
  html += '<div class="question">Deliveries and delivery lines</div>';
  html += '<div>Got a delivery here starts a delivery and shows a bar at the top. Tap Dropped off when you hand the order over and the dropoff spot is saved. Tap an uncovered spot and choose Delivery lines to see a straight line from it to every dropoff you made from there. Dropoffs are private to you.</div>';
  html += '<div class="question">Logging a stop</div>';
  html += '<div>Log saves where you are with the kind of place. House, Apartment complex, High-rise apartments, Gated community and Hotel ask what the next driver needs to know: where orders get left, gates and codes, elevators, front desk rules, parking and extra time past the door.</div>';
  html += '<div class="question">Inventory</div>';
  html += '<div>The Inventory tab is Delivery Twin\'s own inventory, kept apart from Field Twin\'s.</div>';
  html += '<div class="question">Driver Chat</div>';
  html += '<div>Driver Chat is private to Delivery Twin drivers and runs on Delivery Twin\'s own database, apart from every other chat. Join with an invite code from a member, and members can make codes with the Invite code button. With Driver Chat alerts on, a new message from someone else flashes the screen in rainbow colors for a moment.</div>';
  html += '<div class="question">Receipts and miles</div>';
  html += '<div>Receipt reads a photo of a receipt and files it under its printed date. Spend lists what you paid, and Mileage adds up your driving by day.</div>';
  html += '<div class="question">Sync</div>';
  html += '<div>Signed in, everything saves to your Delivery Twin account and matches across phones. Without an account, entries stay on this phone for thirty days.</div>';
HELPJS
awk 'FNR==NR{code=code $0 "\n"; next} /^\/\/ Field Chat: a room inside the Cat Command Chat backend/{skip=1; printf "%s", code} skip && /^\/\/ GO picks and arrivals raise a place/{skip=0} !skip{print}' $HOME/.dt-chat.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
awk 'FNR==NR{code=code $0 "\n"; next} /^function showInfo\(\) \{$/{ininfo=1} {if (!skip) print} ininfo && /^  let html = .<h2>About<\/h2>.;$/{printf "%s", code; skip=1; next} skip && /closeInfoBtn">Close<\/button><\/div>.;$/{skip=0; ininfo=0; print}' $HOME/.dt-help.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f $HOME/.dt-chat.js $HOME/.dt-help.js
sed -i -e 's|<button id="tabTeal" class="on">Field map</button>|<button id="tabTeal" class="on">Map</button>|' -e 's|^  <h3>Field chat</h3>$|  <h3>Driver chat</h3>|' -e 's|<span>Field Chat alerts</span>|<span>Driver Chat alerts</span>|' -e 's|id="fieldChatOpen">Open Field Chat</button>|id="fieldChatOpen">Open Driver Chat</button>|' -e 's|^  <h3>Other apps</h3>$|  <h3 style="display:none">Other apps</h3>|' -e 's|^  <div class="ext-row"><button class="ext" id="openCqBtn">|  <div class="ext-row" style="display:none"><button class="ext" id="openCqBtn">|' -e "s|  return { teal: true, violet: true, glaucous: true };|  return { teal: true, violet: true, glaucous: false };|" -e "s|'Delivery Twin Teal, the map'|'Delivery Twin, the map'|" -e "s|'Delivery Twin Violet, the inventory'|'Delivery Twin Inventory'|" -e "s|^    box('pickGlaucous', p.glaucous !== false, 'Delivery Twin Glaucous, the roads') + '</div>';|    '</div>';|" -e "s|violet: on('pickViolet'), glaucous: on('pickGlaucous') };|violet: on('pickViolet'), glaucous: false };|" -e "s|f.title = 'Delivery Twin Violet inventory';|f.title = 'Delivery Twin Inventory';|" -e 's/FT Companion/Companion/g' index.html
sed -i -e 's|^  if (pick.glaucous) {$|  if (false) {|' -e 's|^// Twin tabs: Field map is this app, Inventory is Delivery Twin Violet loaded in place so switching never leaves the page.$|// Tabs: Map is this app, Inventory is Delivery Twin Inventory loaded in place so switching never leaves the page.|' index.html
