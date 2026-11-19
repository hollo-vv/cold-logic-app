/* ------------------------------------------------------------------
   CLOUD SYNC KEYS (optional)  -  paste your free Firebase web keys here
   ------------------------------------------------------------------
   1. console.firebase.google.com -> Add project (free Spark plan).
   2. Build -> Firestore Database -> Create database.
   3. Rules tab -> paste the rules shown in the app's Sync page -> Publish.
   4. Project settings (gear) -> General -> Your apps -> Web (</>) -> copy firebaseConfig.
   5. Fill in the two values below (apiKey and projectId are the only ones needed),
      save this file, and upload the www folder to Netlify again.

   You can also paste the keys inside the app: Menu -> Sync.
   Leave the values empty to keep everything on the device only.
------------------------------------------------------------------ */
window.FIREBASE_CONFIG = {
  apiKey: "",
  projectId: ""
  /* The rest of the block Firebase shows you (authDomain, storageBucket,
     messagingSenderId, appId) is not needed and can be left out. */
};
