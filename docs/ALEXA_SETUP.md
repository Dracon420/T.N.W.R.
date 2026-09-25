# Setting up the online features: Alexa and photo approval

T.N.W.R. works fully offline. Two optional features need a small free backend:

- **Alexa**: Parts A–D below.
- **Photo approved by someone**: Part A, then [Part E](#part-e-photo-approval). You can skip the Alexa parts if you only want this.

---

## Alexa


This connects the app to an Echo. When a reminder is due, the Echo says it, and
then repeats it every 5 minutes (10 times) until the task is proven done in the
app. You do this setup **once**. Your beta testers only do [Part D](#part-d-beta-testers).

Everything here is **free**: a Supabase free project, and an Alexa-hosted skill.

```
App  --(upcoming reminders)-->  Supabase (alexa-sync)  --(Skill Messaging)-->  Alexa skill  -->  Echo reminders
App  --(get code)-->  Supabase (alexa-code)      Echo: "link code 482173"  -->  skill  -->  Supabase (alexa-pair)
```

You'll need about 30–45 minutes. Keep a notepad open for the four values
marked 📝.

---

## Part A: Supabase (the small backend)

1. Go to **supabase.com**, sign up (free), and click **New project**.
   - Name: `TNWR`, pick the region closest to you, and let it generate a
     database password (save it somewhere; you won't need it for this guide).
2. **Allow anonymous sign-ins.** The app uses these so users never need to
   make an account.
   - Left menu **Authentication → Sign In / Providers** →
     turn on **Allow anonymous sign-ins** → **Save**.
3. **Create the tables.**
   - Left menu **SQL Editor → New query**. Paste all of
     [`supabase/migrations/001_alexa.sql`](../supabase/migrations/001_alexa.sql) → **Run**.
     It should say "Success. No rows returned."
4. **Deploy the three functions.** Left menu **Edge Functions → Deploy a new
   function → Via Editor**. For each one below: set the name exactly as shown,
   replace the sample code with the file's contents, then click **Deploy**:
   - `alexa-code` ← [`supabase/functions/alexa-code/index.ts`](../supabase/functions/alexa-code/index.ts)
   - `alexa-sync` ← [`supabase/functions/alexa-sync/index.ts`](../supabase/functions/alexa-sync/index.ts)
   - `alexa-pair` ← [`supabase/functions/alexa-pair/index.ts`](../supabase/functions/alexa-pair/index.ts)
   - Then open **alexa-pair → Details** and turn **off** "Enforce JWT
     verification" (or "Verify JWT"). Alexa calls this one, not the app, and
     it's protected by its own secret instead.
5. **Make a pairing secret.** Any long random text, for example 40 random
   letters and numbers. 📝 **PAIR_SECRET**
6. 📝 Copy your **Project URL** and **publishable key** (older projects call it
   "anon" key) from **Project Settings → API Keys / Data API**. Both are
   meant to be public.

## Part B: The Alexa skill

1. Go to **developer.amazon.com/alexa/console/ask** and sign in with the
   **same Amazon account your Echo uses**. Accept the developer terms if asked.
2. **Create Skill**:
   - Name: `Naggy Wife`, Primary locale: **English (US)**
   - Type: **Custom**, Hosting: **Alexa-hosted (Node.js)**, template **Start from Scratch**
   - Wait a minute while it's created.
3. **Voice model.** **Build** tab → **Interaction Model → JSON Editor**. Replace
   everything with [`alexa/interactionModels/custom/en-US.json`](../alexa/interactionModels/custom/en-US.json)
   → **Save** → **Build skill**.
4. **Permissions.** **Build** tab → **Tools → Permissions**:
   - Turn on **Reminders**.
   - Scroll to **Alexa Skill Messaging**. 📝 Copy the **Client Id** and
     **Client Secret**.
5. **Code.** **Code** tab, in the `lambda` folder:
   - Replace `index.js` with [`alexa/lambda/index.js`](../alexa/lambda/index.js).
   - Replace `package.json` with [`alexa/lambda/package.json`](../alexa/lambda/package.json).
   - **Create** a new file `config.js` with the contents of
     [`alexa/lambda/config.example.js`](../alexa/lambda/config.example.js), and fill in
     your Supabase **Project URL** and the **PAIR_SECRET** from Part A.
     (Don't put this file in the GitHub repo: it's public.)
   - **Save**, then **Deploy**.
6. **Turn on testing.** **Test** tab → set "Skill testing is enabled in" to
   **Development**. Echo devices on your Amazon account can use the skill now.

## Part C: Connect the pieces

1. **Supabase secrets.** In Supabase, **Edge Functions → Secrets** (or
   **Project Settings → Edge Functions**), add:

   | Name | Value |
   |---|---|
   | `ALEXA_PAIR_SECRET` | your PAIR_SECRET |
   | `ALEXA_CLIENT_ID` | the skill's Client Id |
   | `ALEXA_CLIENT_SECRET` | the skill's Client Secret |

   If your Echo is in Europe, also add `ALEXA_API_HOST` = `https://api.eu.amazonalexa.com`.
   (Far East: `https://api.fe.amazon.com`.)
2. **App.** Put the Project URL and publishable key in
   [`lib/core/cloud_config.dart`](../lib/core/cloud_config.dart), then rebuild the app.
   (These two are public, so they're fine in the repo.)
3. **Link.** In the app, go to **⚙️ Settings → Connect Alexa → Get code**, then say:
   > "Alexa, ask naggy wife to link code **4 8 2 1 7 3**"

   When Alexa asks for permission to set reminders, say **yes**. The app shows
   **Connected to Alexa** within a few seconds.
4. **Test.** Make a reminder due in 3 minutes. The Echo should announce it, then
   repeat every 5 minutes until you prove it done in the app. Also try:
   > "Alexa, ask naggy wife what's due."

## Part D: Beta testers

To give a friend access (their Echo is on a different Amazon account):

1. In the skill console, **Distribution** tab:
   - Fill in the short and full description, example phrases
     (`Alexa, ask naggy wife what's due`), a category (Productivity), and the
     icons [`alexa/icons/icon_108.png`](../alexa/icons/icon_108.png) and
     [`icon_512.png`](../alexa/icons/icon_512.png).
   - Privacy policy URL: `https://github.com/Dracon420/TNWR/blob/main/PRIVACY.md`
   - **Availability → Beta Test**: add your friend's **Amazon account email**, then
     **Enable beta test**.
2. Your friend accepts the **email invite** from Amazon. The skill then appears in
   their Alexa app. Next they follow Part C step 3 on their phone or PC.

## Part E: Photo approval

The person approving gets a text with a link to a small web page showing the photo,
with **Approve** and **Not done** buttons. They don't need the app. The page lives in this repo
([`docs/approve/index.html`](approve/index.html)) and is served free by GitHub Pages.

1. **Part A first** (Supabase project, anonymous sign-ins, `001_alexa.sql`), and put
   the Project URL and publishable key in [`lib/core/cloud_config.dart`](../lib/core/cloud_config.dart).
2. **Table and photo storage.** Supabase **SQL Editor → New query**: paste all of
   [`supabase/migrations/002_photo_approvals.sql`](../supabase/migrations/002_photo_approvals.sql) → **Run**.
3. **Two more functions** (Edge Functions → Deploy a new function → Via Editor):
   - `approval-create` ← [`supabase/functions/approval-create/index.ts`](../supabase/functions/approval-create/index.ts). Keep JWT verification **on**; the app calls it.
   - `approval` ← [`supabase/functions/approval/index.ts`](../supabase/functions/approval/index.ts). Turn **off** "Enforce JWT verification". The web page calls it, and each link carries its own secret token.
4. **Turn on the web page.** On GitHub: the **TNWR** repo → **Settings → Pages** →
   Source **Deploy from a branch**, Branch **main**, folder **/docs** → **Save**. After a
   minute it's live at `https://dracon420.github.io/TNWR/approve/`. (Opening that
   address with no link details shows "Link problem", which means it's working.)
   If you ever host it elsewhere, set a Supabase secret `APPROVE_PAGE_URL` to the new address.
5. **Try it.** In the app, edit a reminder → **Photo approved by someone** → enter a
   name (and optionally their mobile number). Use **⋮ → Test: ring in 5 seconds**, then
   **Take photo and send**. Your messaging app opens with the text ready; send it to
   yourself first. Open the link, tap **Approve**, and the alarm stops within about 5 seconds.

Privacy: photos are in a private storage bucket, reachable only through the
link's short-lived signed address, and **deleted as soon as the approver decides**.

## Troubleshooting

| Problem | Check |
|---|---|
| "That code didn't work" | Codes expire after 10 minutes. `PAIR_SECRET` in the skill's `config.js` must exactly match `ALEXA_PAIR_SECRET` in Supabase, and `alexa-pair` must have JWT verification off. |
| "I couldn't reach the app's server" | `SUPABASE_URL` in `config.js`: it should look like `https://abcd1234.supabase.co` with no trailing slash. |
| Linked, but the Echo never reminds | Did you say yes to reminder permission? (Alexa app → Skills → Naggy Wife → Settings → Manage permissions.) In Supabase → Edge Functions → alexa-sync → Logs, look for errors: `401/403` means the Client Id/Secret are wrong. In the skill console → Code → CloudWatch logs, look for "create failed". |
| App says "Alexa sync failed" | Check the alexa-sync logs in Supabase. |
| "Couldn't send the photo" | Did you run `002_photo_approvals.sql` and deploy `approval-create`? Check its logs in Supabase. |
| Approval link says "invalid or has expired" | The `approval` function must have JWT verification **off**. Links stop working once a decision is made. |
| Approval page doesn't load at all | GitHub → Settings → Pages must be on (main, /docs). It can take a few minutes the first time. |
| Reminders at the wrong hour | The Echo uses its own time zone setting (Alexa app → Devices → your Echo → Time Zone). It should match your phone. |

**Heads-up for the public release:** Amazon's reminder guidelines ask for the
user's consent for reminders and discourage nagging. That's fine for a private
beta, but certification for the public Alexa store may need changes (for
example, a clearer opt-in and fewer repeats).
