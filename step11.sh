set -e
cd ~/delivery-twin
sed -i -e 's|^  <h3>Companion screen</h3>$|  <h3 style="display:none">Companion screen</h3>|' -e 's|id="companionBtn" aria-pressed="false" hidden>|id="companionBtn" aria-pressed="false" hidden style="display:none">|' -e 's|id="companionText" hidden>Off.</div>|id="companionText" hidden style="display:none">Off.</div>|' -e "/^  html += '<div class=\"question\">FT Companion screen<\/div>';$/d" -e "/^  html += '<div>FT Companion is a small dashboard screen board/d" index.html
