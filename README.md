# NoReels

An iPhone app that opens Instagram's own website full-screen and removes the Reels
tab, Reels on profiles and in your feed, and the Explore grid (Explore opens straight to search).
Your feed, stories, DMs, profiles, posting and search all work as normal. You log in
on Instagram's real login page inside the app, and the app stays logged in.

Change what gets hidden in the `SETTINGS` block at the top of `Sources/NoReelsScript.swift`.

## 1. Build the .ipa (free, on GitHub's Mac build machines)

1. Make a free account at github.com and create a new **public** repository called `NoReels`.
2. On the repo page, click **Add file → Upload files** and drag in everything from this
   folder, including the `.github` folder. Click **Commit changes**.
   - If the `.github` folder doesn't upload, click **Add file → Create new file**, name it
     `.github/workflows/build.yml`, and paste in the contents of that file.
3. Open the **Actions** tab (enable workflows if it asks), click **Build NoReels IPA**,
   then **Run workflow**. It takes about 5 minutes.
4. When it shows a green tick, open the run and download **NoReels-ipa** at the bottom.
   Unzip it and you have `NoReels.ipa`.

If the build goes red, open the failed step and copy the error.

## 2. Put it on your iPhone (from a Windows PC)

1. Install **iTunes** and **iCloud** from apple.com (not the Microsoft Store versions).
2. Install **Sideloadly** from sideloadly.io.
3. Plug your iPhone into the PC with a cable, open Sideloadly, type your Apple ID,
   drag `NoReels.ipa` in and click **Start**.
4. On the iPhone:
   - **Settings → Privacy & Security → Developer Mode** → on (the phone restarts).
   - **Settings → General → VPN & Device Management** → tap your Apple ID → **Trust**.
5. Open NoReels and log in.

With a free Apple ID the app stops opening after 7 days. Re-install it with Sideloadly,
or turn on Sideloadly's automatic refresh.
