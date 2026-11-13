set -e
# Part one: Delivery Twin's own inventory app, copied from Field Twin Violet into ~/delivery-twin-violet
if [ ! -d ~/delivery-twin-violet ]; then
  gh repo clone sudosilo/field-twin-violet-api ~/delivery-twin-violet -- --depth 1
  cd ~/delivery-twin-violet
  rm -rf .git .github
  mv field-twin-fonts-v1 delivery-twin-fonts-v1
  for f in delivery-twin-fonts-v1/field-twin-*; do mv "$f" "${f/field-twin-/delivery-twin-}"; done
  mv field-twin-violet-api delivery-twin-violet-api
  mv field-twin-violet-reports delivery-twin-violet-reports
  rm -rf delivery-twin-violet-reports/__pycache__
  for f in $(find . -name '*field-twin*' -o -name '*field_twin*' | sort -r); do mv "$f" "$(dirname $f)/$(basename $f | sed -e 's/field-twin/delivery-twin/g' -e 's/field_twin/delivery_twin/g')"; done
  FILES=$(find . -type f ! -name '*.woff2' ! -name '*.pyc')
  sed -i -e 's/field-twin-violet-api-production/KEEPA/g' -e 's/field-twin-glaucous/KEEPB/g' -e 's/field-twin-teal\.vercel\.app/delivery-twin.vercel.app/g' -e 's/\bviolet_\(holders\|catalog\|events\|orders\|reports\)\b/delivery_twin_violet_\1/g' -e 's/"violet-photos"/"delivery-twin-violet-photos"/g' $FILES
  sed -i -e 's/FieldTwin/DeliveryTwin/g' -e 's/fieldTwin/deliveryTwin/g' -e 's/field-twin/delivery-twin/g' -e 's/fieldtwin/deliverytwin/g' -e 's/field_twin/delivery_twin/g' -e 's/Field Twin/Delivery Twin/g' -e 's/FIELD TWIN/DELIVERY TWIN/g' $FILES
  sed -i -e 's/KEEPA/field-twin-violet-api-production/g' -e 's/KEEPB/field-twin-glaucous/g' $FILES
  sed -i 's|<a href="https://field-twin-glaucous.vercel.app/">Roads</a>|<a href="https://delivery-twin.vercel.app/#offers">Offers</a>|' index.html
  git init -q -b main
  git add .
  git commit -q -m "Delivery Twin inventory from Field Twin Violet"
  gh repo create delivery-twin-violet --public --source=. --remote=origin --push
  vercel --prod --yes
fi
# Part two: Delivery Twin points its Inventory tab at its own inventory app and swaps Roads for Offers
cd ~/delivery-twin
sed -i -e 's|https://field-twin-violet.vercel.app|https://delivery-twin-violet.vercel.app|g' -e 's/fieldtwin-session/deliverytwin-session/g' -e 's|<button id="tabRoads">Roads</button>|<button id="tabRoads">Offers</button>|' -e "s|document.getElementById('tabRoads').addEventListener('click', openGlaucous);|document.getElementById('tabRoads').addEventListener('click', () => { show('teal'); showOffers(); });|" -e "s|^  if (location.hash === '#inventory') start = 'violet';$|  if (location.hash === '#inventory') start = 'violet';\n  if (location.hash === '#offers') { start = 'teal'; setTimeout(showOffers, 1500); }|" index.html
