set -e
cd ~/delivery-twin
cat > $HOME/.dt-loyal.js <<'LOYALJS'
// Rewards links on uncovered spots. Delivery Twin keeps a list of chains and their rewards programs in the
// delivery_twin_loyalty table; a spot whose name or chain matches gets a button to that program. The link opens
// the chain's own web address, which Android hands to the chain's app when it is installed.
let dtLoyalty = null;
async function dtLoyaltyLoad() {
  if (dtLoyalty || !(sb && cloudUser)) return;
  try { const r = await sb.from('delivery_twin_loyalty').select('match,program,url'); dtLoyalty = r.data || []; } catch (e) { dtLoyalty = []; }
}
function dtLoyaltyFor(s) {
  if (!dtLoyalty || !s) return null;
  const hay = ((s.brand || '') + ' ' + (s.name || '')).toLowerCase().replace(/[\u2019`]/g, "'");
  return dtLoyalty.find(l => hay.indexOf(l.match) !== -1) || null;
}
function dtLoyaltyBtn(s) {
  const l = dtLoyaltyFor(s);
  if (!l) return '';
  return '<button class="secondary" data-dtloyal="' + escapeHtml(l.url) + '" style="margin-top:6px;">Rewards: ' + escapeHtml(l.program) + '</button>';
}
document.addEventListener('click', ev => {
  const b = ev.target.closest && ev.target.closest('[data-dtloyal]');
  if (!b) return;
  const url = b.getAttribute('data-dtloyal');
  if (!/^https:\/\//.test(url)) return;
  if (window.DeliveryTwinNative && typeof window.DeliveryTwinNative.openUrl === 'function') {
    try { window.DeliveryTwinNative.openUrl(url); return; } catch (e) {}
  }
  const w = window.open(url, '_blank', 'noopener');
  if (!w) window.location.href = url;
});

LOYALJS
awk 'FNR==NR{code=code $0 "\n"; next} /^function dtLinesBtn\(s\) \{$/{printf "%s", code} {print}' $HOME/.dt-loyal.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f $HOME/.dt-loyal.js
sed -i -e "s|^  m.bindPopup('<div style=\"font-size:14px;line-height:1.4;\">' + dtSpotLines(s).join('<br>') + btn + |  await dtLoyaltyLoad();\n  m.bindPopup('<div style=\"font-size:14px;line-height:1.4;\">' + dtSpotLines(s).join('<br>') + btn + dtLoyaltyBtn(s) + |" index.html
