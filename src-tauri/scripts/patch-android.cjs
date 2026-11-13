// Copies the Delivery Twin tracking code into the generated Android project and adds its permissions,
// the tracking service, and the deliverytwin:// link that odometer prompts use.
const fs = require("fs");
const path = require("path");
const root = "src-tauri/gen/android/app/src/main";
const pkgDir = path.join(root, "java", "app", "deliverytwin", "teal");
if (!fs.existsSync(pkgDir)) throw new Error("generated package folder not found at " + pkgDir);
for (const f of fs.readdirSync("src-tauri/android")) {
  if (f.endsWith(".kt")) fs.copyFileSync(path.join("src-tauri/android", f), path.join(pkgDir, f));
}
const mf = path.join(root, "AndroidManifest.xml");
let s = fs.readFileSync(mf, "utf8");
const perms = [
  "android.permission.ACCESS_FINE_LOCATION",
  "android.permission.ACCESS_COARSE_LOCATION",
  "android.permission.FOREGROUND_SERVICE",
  "android.permission.FOREGROUND_SERVICE_LOCATION",
  "android.permission.POST_NOTIFICATIONS",
  "android.permission.CAMERA",
  "android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS",
  "android.permission.BLUETOOTH_SCAN",
  "android.permission.BLUETOOTH_CONNECT"
];
if (!s.includes('android.permission.BLUETOOTH"')) s = s.replace("<application", '    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />\n    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />\n    <application');
let add = "";
for (const p of perms) if (!s.includes('"' + p + '"')) add += '    <uses-permission android:name="' + p + '" />\n';
s = s.replace("<application", add + "    <application");
if (!s.includes("DeliveryTwinTrackService")) {
  s = s.replace("</application>",
    '    <service android:name=".DeliveryTwinTrackService" android:exported="false" android:foregroundServiceType="location" />\n    </application>');
}
if (!s.includes('android:scheme="deliverytwin"')) {
  const filter = '<intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="deliverytwin" />\n            </intent-filter>\n            ';
  const i = s.indexOf("</activity>");
  if (i < 0) throw new Error("no activity in manifest");
  s = s.slice(0, i) + filter + s.slice(i);
}
if (!s.includes("android:launchMode")) s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:launchMode="singleTask"');
if (!s.includes("supportsPictureInPicture")) s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:supportsPictureInPicture="true"');
const need = ["screenSize", "smallestScreenSize", "screenLayout", "orientation"];
const cm = s.match(/android:configChanges="([^"]*)"/);
if (cm) { const have = cm[1].split("|"); for (const n of need) if (!have.includes(n)) have.push(n); s = s.replace(cm[0], 'android:configChanges="' + have.join("|") + '"'); }
else s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:configChanges="' + need.join("|") + '"');
fs.writeFileSync(mf, s);
console.log("Delivery Twin Android project patched");
