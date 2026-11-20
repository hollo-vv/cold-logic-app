# 𝙲𝙾𝙻𝙳 𝙻𝙾𝙶𝙸𝙲 (v2)

## What's new in v5

- App icon is now the eclipse logo (192, 512, maskable and Apple touch sizes).
- Sidebar visualizer is a small neon ring with long rainbow equalizer spikes. It follows the app's own sounds and moves on its own when idle.

## What's new in v4

- Sidebar header: silver COLD LOGIC wordmark with a small circular spectrum visualizer (3D depth on its left). It reacts to the app's own sounds and idles gently otherwise.
- Today only or every week: edit, reschedule or remove a routine item, a class, or an exercise with the pencil buttons. You are asked whether to change today only or every week. Today-only changes never touch the weekly template. "Revert day" undoes them. Settings holds the weekly template.
- Habit and work-out alerts with your choice of sound: built-in tones, a file you upload in Settings, or files you put in www/sounds (see www/sounds/README.txt).
- Netlify badge CSS override added. New app icon set (192, 512, maskable, 180 Apple touch).

## What's new in this update (v3)

- Day and Work-out tasks are done in order. A task can only be ticked once every earlier task is done. After a later task is ticked, earlier ones are locked. Work-out items stay ticked for good.
- The 90-second rest timer now sits inside each exercise card (with a length picker, +15s and Stop) instead of floating.
- Synthesized click, toggle, lock and completion sounds (no audio files). Turn them off or change the volume in Settings.
- Back button: from any section it goes to Day. On Day it asks before exiting.
- One Settings menu: background, haptics, sound effects, notifications, timetable, work-out plan, routine and backup.
- The menu footer shows a daily motivational quote.
- Every section has Clear. An emptied section shows an Add button that opens the matching Settings tab.
- Sync checks every 5 seconds while the app is open and pushes changes within a second. It now also carries haptic, sound, Pomodoro and rest settings.
- Smoother page transitions (View Transitions where supported) and press feedback.
- Pomodoro progress styles: Wave, Line, Blocks, Ring, Dots, Pulse.

Update your site by dragging the new www folder onto the same Netlify site (Deploys tab). Your data stays in the browser.


Upload the CONTENTS of the `www` folder to Netlify (drag the `www` folder onto Deploys of your existing site).
Always update the same site so your saved data stays on the same web address.

## Files in www
- index.html           the whole app
- manifest.json        PWA manifest (standalone, icons, theme colours, shortcuts, screenshots)
- sw.js                service worker (offline + notification clicks)
- firebase-config.js   PASTE YOUR FIREBASE KEYS HERE (optional, for sync)
- _headers             Netlify cache rules so updates show up quickly
- assets/ icons/ screenshots/

## Android APK with PWABuilder
1. Deploy www to Netlify and open the site once.
2. Go to https://www.pwabuilder.com, paste your Netlify address, press Start.
3. Open Package for stores, choose Android, then Generate. Download the zip.
4. Install the .apk from that zip on your phone (allow installs from this source).
5. If PWABuilder gives you an assetlinks.json file, put it in www/.well-known/assetlinks.json, redeploy, and the app
   opens without the browser address bar.

## Cloud sync (phone + laptop)
Menu > Sync has the full steps. Short version:
1. Create a free Firebase project, create a Firestore database, publish the rules shown on the Sync page.
2. Copy apiKey and projectId from Project settings > Your apps > Web into www/firebase-config.js
   (or paste the block into the Sync page on each device).
3. Enter the same sync code on both devices and tap Connect.
Uploaded files (PDF/PPT/images) and backgrounds stay on each device.

## Notes
- Reset buttons never touch the defaults in the code. "Restore defaults" brings them back; unticking
  "Keep my custom schedule" in the reset popup makes a refresh bring the defaults back.
- Class reminders arrive 30 minutes before class while the app is open or running in the background.

## v15 – Notifications fix
- Class reminders now show subject, class type, room, section, time and the open submissions / homework / notes for that subject. Submissions with a due date also remind you at 8 PM the day before and 8 AM on the due day.
- Reminder lead time is configurable (Settings > General > Class & submission reminders). Missed reminders are caught up when the app opens.
- Settings shows a diagnostics card and a real "Send a test" button.
- A website cannot wake a fully closed app. For best results install to the Home Screen and allow background activity. Chrome Android installed apps also use Periodic Background Sync (best effort).
- Reliable delivery while locked: build the Android APK. Run `npm install`, `npx cap add android`, `npx cap sync`; reminders are then scheduled natively with @capacitor/local-notifications.

## v16 – Music & visualizer (Settings > General)
- Play your own audio files; the header ring reacts to the real sound (lock-screen controls included).
- "Listen with microphone" makes the ring follow music from any other app (LastWave, Spotify, ...) through the mic. Phones cannot share another app's audio directly.
- "Capture tab audio" (desktop Chrome/Edge) follows a shared browser tab.
- "Your music app link" plus an Open button for a quick launch.
- manifest `id` is now "./" (fixes sub-path hosting such as GitHub Pages). Service worker cache is v17.
