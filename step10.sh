set -e
cd ~/delivery-twin
cat > $HOME/.dt-cats.js <<'CATSJS'
// Delivery Twin dropoff places and the work-only categories it keeps out of the pickers.
const DT_HIDDEN_CATS = ['amazon_locker', 'warehouse', 'printer_site', 'memorial', 'airstrip'];
const DT_FULL_Q = ['residential', 'apartment', 'highrise', 'gated', 'hotel'];
Object.assign(CATEGORIES, {
  residential: { label: 'House',            icon: '\u{1F3E0}', color: '#2e7d32' },
  apartment:   { label: 'Apartment complex', icon: '\u{1F3D8}', color: '#6a1b9a' },
  highrise:    { label: 'High-rise apartments', icon: '\u{1F3E2}', color: '#283593' },
  gated:       { label: 'Gated community',   icon: '\u{1F6A7}', color: '#bf360c' }
});
Object.assign(ICON_ART, {"residential": {"v": "0 0 15 15", "p": "<path d=\"M2,13.7478c0,0.13807,0.11193,0.25,0.25,0.25h3.749v-3h3v3h3.749c0.13807,0,0.25-0.11193,0.25-0.25V7.9987H2  C2,7.9987,2,13.7478,2,13.7478z M13.93,6.5778l-0.9319-0.8189V2c0-0.55228-0.44771-1-1-1s-1,0.44772-1,1v2L7.6808,1.09  C7.5863,0.9897,7.42846,0.98478,7.3279,1.079L7.3169,1.09L1.0678,6.553C0.9734,6.65376,0.97856,6.81197,1.07932,6.90637  C1.12478,6.94896,1.18451,6.97304,1.2468,6.9739L3,6.9989h10.7468c0.13807,0.00046,0.25037-0.1111,0.25083-0.24917  C13.99784,6.68592,13.97365,6.62445,13.93,6.5779V6.5778z\"/>"}, "apartment": {"v": "0 0 15 15", "p": "<path d=\"m11.8 12.5v-2.5c.7-.1 1.2-.7 1.2-1.5s-.7-1.5-1.5-1.5-1.5.7-1.5 1.5c0 .7.5 1.4 1.2 1.5v2.5h-4.2v-11.5h-5v11.5h-1v.5h13v-.5zm-5.8-2.5h-3v-1h3zm0-2h-3v-1h3zm0-2h-3v-1h3zm0-2h-3v-1h3z\"/>"}, "highrise": {"v": "0 0 15 15", "p": "<path d=\"M11,13.5v-9C11,4.2,10.8,4,10.5,4H9V1L5,2.1v11.4H2V14h11v-0.5H11z M7,13.5V3h1v10.5H7z\"/>"}, "gated": {"v": "0 0 15 15", "p": "<path d=\"M1 4a2 2 0 1 1 4 0v8a1 1 0 0 1-1 1H2a1 1 0 0 1-1-1V4Zm3 0a1 1 0 1 0-2 0 1 1 0 0 0 2 0Zm4.5 2L7 3H6v3h2.5ZM10 6h1.5L10 3H8.5L10 6Zm3.25 0H13l-1.5-3h1.75a.75.75 0 0 1 .75.75v1.5a.75.75 0 0 1-.75.75Z\"/>"}});
CATSJS
cat > $HOME/.dt-pools.js <<'POOLSJS'
    residential: [
      sq('dropSpot', 'Where do orders get left', ['Front door', 'Side or back door', 'Garage', 'Porch box', 'Hand to customer']),
      bq('numberVisible', 'Is the house number easy to see from the street', ['Yes', 'No']),
      bq('numberLit', 'Is the house number lit at night', ['Yes', 'No']),
      bq('fence', 'Is there a fence or yard gate to get through', ['Yes', 'No']),
      bq('dog', 'Is there a dog loose or behind the gate', ['Yes', 'No']),
      bq('parking', 'Where do you park', ['Driveway', 'Street', 'Alley']),
      bq('porchLight', 'Is the porch lit at night', ['Yes', 'No']),
      tq('dropNote', 'Anything the next driver should know')
    ],
    apartment: [
      sq('gateAccess', 'How do you get through the gate', ['No gate', 'Call box', 'Gate code', 'Guard', 'Resident lets you in']),
      bq('mapPosted', 'Is a building map posted at the entrance', ['Yes', 'No']),
      bq('buildingNumbers', 'Are building numbers easy to see', ['Yes', 'No']),
      sq('dropSpot', 'Where do orders get left', ['Unit door', 'Leasing office', 'Package room', 'Lockers', 'Meet at the gate']),
      sq('stairsLift', 'How do you reach upper units', ['Ground floor only', 'Stairs', 'Elevator', 'Both']),
      sq('parking', 'Where do you park', ['Visitor spots', 'Fire lane', 'Street', 'No parking']),
      bq('dog', 'Are loose dogs common here', ['Yes', 'No']),
      tq('gateNote', 'Gate code or call box tips')
    ],
    highrise: [
      sq('floors', 'How many floors', ['5-10', '11-25', '26-50', 'Over 50']),
      sq('dropSpot', 'Where do orders get left', ['Front desk', 'Concierge', 'Package room', 'Up to the unit', 'Customer comes down']),
      bq('upstairs', 'Are drivers allowed up to the unit', ['Yes', 'No', 'Escorted only']),
      bq('fob', 'Does the elevator need a key fob', ['Yes', 'No']),
      bq('signIn', 'Do drivers sign in or show ID at the desk', ['Yes', 'No']),
      sq('parking', 'Where do you park', ['Loading zone', 'Valet', 'Garage', 'Street', 'No parking']),
      sq('extraTime', 'Extra time it takes past the door', ['Under 5 min', '5-10 min', '10-20 min', 'Over 20 min']),
      tq('lobbyNote', 'Lobby or elevator tips')
    ],
    gated: [
      sq('gateType', 'What kind of gate', ['Guard', 'Code keypad', 'Call box', 'Remote only']),
      bq('guardId', 'Does the guard ask for ID or the resident name', ['Yes', 'No']),
      bq('visitorLane', 'Is there a separate visitor lane', ['Yes', 'No']),
      sq('gateWait', 'How long does the gate take', ['Under 1 min', '1-3 min', '3-5 min', 'Over 5 min']),
      bq('mapPosted', 'Is a map posted at the gate', ['Yes', 'No']),
      bq('numbersVisible', 'Are house numbers easy to see inside', ['Yes', 'No']),
      tq('gateNote', 'Gate code or guard tips')
    ],
    hotel: [
      sq('propertyType', 'Property type', ['Motel', 'Budget hotel', 'Mid range', 'Upscale', 'Casino resort']),
      sq('floors', 'How many floors', ['1', '2', '3-4', '5-20', 'Over 20']),
      sq('dropSpot', 'Where do orders get left', ['Front desk', 'Bell desk', 'Up to the room', 'Guest comes down', 'Room door outside']),
      bq('upstairs', 'Are drivers allowed up to rooms', ['Yes', 'No', 'Escorted only']),
      bq('exteriorEntry', 'Room entry style', ['Exterior doors', 'Interior corridors']),
      bq('fob', 'Does the elevator need a room key', ['Yes', 'No']),
      sq('parking', 'Where do you park', ['Front entrance', 'Valet', 'Garage', 'Lot', 'No parking']),
      sq('extraTime', 'Extra time it takes past the door', ['Under 5 min', '5-10 min', '10-20 min', 'Over 20 min']),
      tq('dropNote', 'Anything the next driver should know')
    ],
POOLSJS
awk 'FNR==NR{code=code $0 "\n"; next} {print} /^const ICON_ART = /{printf "%s", code}' $HOME/.dt-cats.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
awk 'BEGIN{skip=0} FNR==NR{code=code $0 "\n"; next} /^    hotel: \[$/{skip=1; next} skip && /^    \],$/{skip=0; next} skip{next} /^    mall: \[$/{printf "%s", code} {print}' $HOME/.dt-pools.js index.html > $HOME/.dt-index.html && mv $HOME/.dt-index.html index.html
rm -f $HOME/.dt-cats.js $HOME/.dt-pools.js
sed -i -e "s/k !== 'amazon_locker'/DT_HIDDEN_CATS.indexOf(k) === -1/g" -e "s/^  if (category === 'memorial') return pool;$/  if (category === 'memorial' || DT_FULL_Q.indexOf(category) !== -1) return pool;/" -e "s/^  if (shop || has('department_store') || has('marketplace')) return 'retail';$/  if (has('apartments') || has('apartment') || name.includes('apartment') || name.includes(' apts')) return (Number(addr['building:levels'] || 0) >= 5 || name.includes('tower')) ? 'highrise' : 'apartment';\n  if (name.includes('guard gate') || name.includes('gated') || (has('gate') \&\& name.includes('community'))) return 'gated';\n  if (has('house') || has('detached') || has('semidetached_house') || has('terrace') || has('residential')) return 'residential';\n&/" -e "s/^  general: 'shield', none: 'shield', receipt: 'tag', odometer: 'guide'$/  general: 'shield', none: 'shield', receipt: 'tag', odometer: 'guide',\n  residential: 'square', apartment: 'square', highrise: 'square', gated: 'pentagon'/" index.html
