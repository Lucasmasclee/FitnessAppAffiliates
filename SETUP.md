# Registration flow – setup guide

This guide explains how to set up the full affiliate registration flow: **Google sign-in**, **Supabase** (database + auth), **SMS via Twilio** to your phone when someone clicks “Contact me”, and the **affiliate dashboard** with stats.

---

## 1. Supabase project

### 1.1 Create project

1. Go to [supabase.com](https://supabase.com) and sign in.
2. Click **New project**.
3. Choose your organization, set a **Project name** and **Database password** (save the password).
4. Pick a region and click **Create new project**. Wait until the project is ready.

### 1.2 Get API keys

1. In the Supabase Dashboard, go to **Project Settings** (gear icon) → **API**.
2. Note:
   - **Project URL** (e.g. `https://xxxxx.supabase.co`)
   - **anon public** key (under “Project API keys”)
   - **service_role** key (click “Reveal” and copy it; keep this secret and never use it in frontend code).

---

## 2. Enable Google sign-in

1. In Supabase Dashboard go to **Authentication** → **Providers**.
2. Find **Google** and turn it **ON**.
3. You need a **Google OAuth client**:
   - Open [Google Cloud Console](https://console.cloud.google.com/) → create or select a project.
   - Go to **APIs & Services** → **Credentials** → **Create credentials** → **OAuth client ID**.
   - Application type: **Web application**.
   - Add **Authorized redirect URIs**:  
     `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`  
     (replace `YOUR_PROJECT_REF` with your Supabase project reference from the URL).
   - Create and copy **Client ID** and **Client secret**.
4. Back in Supabase → **Google** provider: paste **Client ID** and **Client secret**, then **Save**.

### Redirect URLs in Supabase (voor popup-inlog)

Google-inloggen gebruikt een **popup**. Daarvoor moet Supabase weten dat hij na inloggen mag doorsturen naar je callback-pagina.

1. In Supabase Dashboard: **Authentication** → **URL Configuration**.
2. Onder **Redirect URLs** voeg je toe (en op **Add URL**):
   - `http://localhost:3000/auth-callback.html` (lokaal)
   - Bij productie ook: `https://jouwdomein.com/auth-callback.html`

Zonder deze URL opent de popup wel, maar na inloggen gaat het mis.

### Google Cloud Console (origins)

In Google Cloud Console, bij je OAuth client:

- **Authorized JavaScript origins**: `http://localhost:3000` (dev), `https://yourdomain.com` (prod).
- **Authorized redirect URIs**: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` (de Supabase-callback; je eigen callback-URL regel je in Supabase zoals hierboven).

---

## 3. Database tables aanmaken

**Wat is dit?** De site moet ergens de affiliates en hun statistieken (kliks, downloads, abo’s) opslaan. Dat doen we in Supabase met twee tabellen: `affiliates` en `affiliate_stats`. Die tabellen moet je één keer aanmaken.

**Wat moet jij doen?** Kies **één** van de twee manieren hieronder. De eerste (via de website) is het makkelijkst.

---

### Optie A: Via de Supabase-website (aanbevolen)

1. Ga naar [supabase.com](https://supabase.com) en open je project.
2. Klik in het linkermenu op **SQL Editor**.
3. Klik op **New query** (nieuwe query).
4. Open op je computer de bestanden `supabase/migrations/001_affiliates.sql` en `002_branch_link_alias.sql`. Kopieer alle tekst uit beide (eerst 001, dan 002) en plak in de SQL Editor (of voer ze apart uit).
5. Klik onderaan op **Run** (of Ctrl+Enter).
6. De tabellen en de kolom branch_link_alias bestaan nu. (Bij succes zie je onderaan iets als “Success” of “Success. No rows returned”. De tabellen bestaan nu.

Klaar. Je hoeft geen Supabase CLI te installeren.

---

### Optie B: Via de Supabase CLI (als je die al gebruikt)

Als je de [Supabase CLI](https://supabase.com/docs/guides/cli) al hebt geïnstalleerd en je project wilt koppelen:

1. In een terminal: `supabase login` en daarna `supabase link --project-ref JOUW_PROJECT_REF` (vervang `JOUW_PROJECT_REF` door het stukje uit je Supabase-URL vóór `.supabase.co`).
2. In de projectmap: `supabase db push`. Dat voert de SQL uit en maakt de tabellen aan.

---

## 4. Twilio (SMS when someone clicks “Contact me”)

SMS is sent to the number you configure (e.g. +31682856114) with the affiliate’s email, phone, social media, and affiliate code.

### 4.1 Twilio account and number

1. Go to [twilio.com](https://www.twilio.com) and sign up (or sign in).
2. In the Twilio Console go to **Phone Numbers** → **Manage** → **Buy a number** (or use a trial number; trial accounts can only send to verified numbers).
3. Note your **Twilio phone number** (e.g. +1234567890); this will be the “From” number for SMS.

### 4.2 Get credentials

1. In Twilio Console go to **Account** → **API keys & tokens** (or **Dashboard** → Account Info).
2. Note:
   - **Account SID**
   - **Auth Token** (or create an API key and use **SID + Secret**).

---

## 5. Supabase Edge Function (opslaan affiliate + SMS sturen)

Als iemand op “Contact me” klikt, roept de site een **Edge Function** aan. Die slaat de affiliate op in de database en stuurt de SMS via Twilio.

### 5.1 Secrets instellen ✓

**Via het Dashboard:** Supabase → jouw project → **Edge Functions** → tab **Secrets**. Voeg deze vier toe:

| Name | Waarde |
|------|--------|
| `TWILIO_ACCOUNT_SID` | Twilio Account SID |
| `TWILIO_AUTH_TOKEN` | Twilio Auth Token |
| `TWILIO_PHONE_NUMBER` | Twilio “From”-nummer |
| `AFFILIATE_SMS_TO` | Nummer waar de SMS naartoe moet |

**Volgende stap:** de Edge Function deployen (zie 5.2).

### 5.2 Edge Function deployen

De code staat in `supabase/functions/submit-affiliate/index.ts`. **Belangrijk:** in `supabase/config.toml` staat `verify_jwt = false` voor deze function, zodat het Supabase-gateway het verzoek niet weigert met 401; de function controleert de JWT zelf.

Kies één manier:

**Optie A – Via Supabase CLI**

Gebruik `npx supabase` (geen globale installatie nodig). In de projectmap:

1. Inloggen (opent je browser):  
   `npx supabase login`
2. Project koppelen (vervang `JOUW_PROJECT_REF` door het stukje uit je Supabase-URL):  
   `npx supabase link --project-ref JOUW_PROJECT_REF`
3. Functie deployen (gebruikt automatisch `supabase/config.toml`):  
   `npx supabase functions deploy submit-affiliate`

**Optie B – Zonder CLI**

Supabase Dashboard → **Edge Functions** → **Create a new function** → naam `submit-affiliate`. Plak de inhoud van `supabase/functions/submit-affiliate/index.ts` in de editor en deploy vanuit het dashboard.

### 5.3 Testen

Na het deployen:

1. Site openen (bijv. `http://localhost:3000`).
2. **Become affiliate** → **Sign in with Google** → formulier invullen → **Contact me**.
3. In Supabase **Table Editor** controleren: tabellen `affiliates` en `affiliate_stats`.
4. Op het nummer van `AFFILIATE_SMS_TO` de SMS controleren.

---

## 6. Frontend config (config.js)

1. Copy the example config:

   ```bash
   copy js\config.example.js js\config.js
   ```

2. Edit `js/config.js` (this file is in `.gitignore`; do not commit it with real keys):

   - **supabaseUrl**: your Supabase Project URL (step 1.2).
   - **supabaseAnonKey**: your Supabase **anon public** key (step 1.2).
   - **appBaseUrl**: base URL of your app for affiliate links (e.g. `https://yourapp.com/ref/`). This is used on the dashboard as “Your affiliate link”.

Example:

```js
window.AFFILIATE_CONFIG = {
  supabaseUrl: "https://abcdefgh.supabase.co",
  supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  appBaseUrl: "https://yourapp.com/ref/",
};
```

---

## 7. Run the site locally

1. Ensure `js/config.js` exists and is filled in (step 6).
2. **Zie je oude gedrag?** Doe een **harde refresh** zodat de nieuwste code laadt: **Ctrl+Shift+R** (of **Ctrl+F5**). Of in het menu van je browser: DevTools openen (F12) → rechtermuisklik op de refreshknop → **Empty cache and hard reload**.
3. From the project folder:

   ```bash
   npx serve . -l 3000
   ```

3. Open `http://localhost:3000`.
4. Click **Become an affiliate** → sign in with Google → fill form → **Contact me**. You should see the new affiliate in Supabase and receive the SMS on the number in `AFFILIATE_SMS_TO`.

---

## 7b. Website online zetten met je eigen domein (bijv. liftbetter.cloud)

Om de site live te zetten op **https://liftbetter.cloud** (of een ander domein) doe je het volgende.

### Stap 1: Hosting kiezen

De site is alleen HTML/CSS/JS; elke host voor statische sites werkt. Voorbeelden:

| Optie | Hoe |
|-------|-----|
| **Netlify** | [netlify.com](https://netlify.com) → “Add new site” → “Deploy manually” of koppel een Git-repo. Upload de map (alle bestanden behalve `node_modules`, `.local.env`). |
| **Vercel** | [vercel.com](https://vercel.com) → “Add New Project” → importeer je Git-repo of upload de map. |
| **Cloudflare Pages** | [dash.cloudflare.com](https://dash.cloudflare.com) → Pages → Create project → upload of koppel Git. |

Belangrijk: **`js/config.js`** staat in `.gitignore`. Op de host moet die wél bestaan. Doe één van de twee:

- **Build settings** op de host: “Build command” leeg of `echo done`, “Publish directory” = root (`.`). Voeg in het dashboard bij **Environment variables** of **Build env** geen secrets toe voor deze statische site; de config zit in `config.js`.
- Of: lokaal een **productie-**`config.js` maken (met `appBaseUrl: "https://liftbetter.cloud/ref/"` en dezelfde Supabase keys), die je wél meedeployt (bijv. in een “production” branch of via een build step die `config.production.js` als `config.js` kopieert). **Let op:** dan staan je Supabase anon key (en eventueel andere waarden) in de repo; alleen anon key mag publiek, geen service_role of wachtwoorden.

Eenvoudigste: op Netlify/Vercel/Cloudflare de site deployen vanuit Git, en **Environment variables** gebruiken waar de host dat ondersteunt. Voor een puur statische site zonder build: na deploy handmatig een `config.js` op de host toevoegen (als de host “Edit file” toestaat), of een klein build script dat uit env vars een `config.js` schrijft.

Hieronder gaan we ervan uit dat de site bereikbaar wordt op **https://liftbetter.cloud** (of een tijdelijke URL van de host).

### Stap 2: Domein koppelen (liftbetter.cloud)

1. Bij je **host** (Netlify/Vercel/Cloudflare): zoek “Custom domain” of “Domain settings”.
2. Voeg **liftbetter.cloud** toe. De host toont dan wat je in DNS moet zetten, bijvoorbeeld:
   - **CNAME**: `liftbetter.cloud` → `jouw-site.netlify.app` (of wat de host aangeeft), of
   - **A-record** naar het IP dat de host geeft.
3. Bij de **partij waar je liftbetter.cloud hebt gekocht** (registrar, bijv. TransIP, Namecheap, Cloudflare, etc.):
   - Ga naar DNS-instellingen voor **liftbetter.cloud**.
   - Voeg het CNAME- of A-record toe zoals de host aangeeft.
   - Soms moet je voor het **root-domein** (liftbetter.cloud) een “ALIAS”/“ANAME” of “CNAME flattening” gebruiken; de host legt dat uit.
4. Wacht 5–60 minuten. Daarna zou **https://liftbetter.cloud** naar je site moeten wijzen. De host regelt meestal automatisch een **SSL-certificaat** (HTTPS).

### Stap 3: config.js voor productie

Zorg dat op de live site in **`js/config.js`** in ieder geval staat:

- **supabaseUrl** en **supabaseAnonKey**: dezelfde waarden als lokaal (Supabase Project URL en anon key).
- **appBaseUrl**: basis voor affiliate-links, bijv. `https://liftbetter.cloud/ref/` (zonder domein wijzigen we geen bestaande keys).

Voorbeeld:

```js
window.AFFILIATE_CONFIG = {
  supabaseUrl: "https://JOUW_PROJECT_REF.supabase.co",
  supabaseAnonKey: "JOUW_ANON_KEY",
  appBaseUrl: "https://liftbetter.cloud/ref/",
};
```

### Stap 4: Supabase – Redirect URLs

1. Supabase Dashboard → **Authentication** → **URL Configuration**.
2. Bij **Redirect URLs** voeg je toe:
   - `https://liftbetter.cloud/auth-callback.html`
3. Optioneel: zet **Site URL** op `https://liftbetter.cloud` (dan gebruikt Supabase dit als standaard redirect-base).

### Stap 5: Google Cloud – OAuth

1. [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services** → **Credentials** → je OAuth 2.0 Client.
2. Bij **Authorized JavaScript origins** voeg toe:
   - `https://liftbetter.cloud`
3. **Authorized redirect URIs** blijft: `https://JOUW_PROJECT_REF.supabase.co/auth/v1/callback` (niets veranderen voor het domein).

Daarna zou de site op **https://liftbetter.cloud** moeten werken, inclusief Google-inloggen en “Contact me”.

---

## 7c. Exacte stappen op Render.com

Volg deze stappen om de site op **Render** te zetten en daarna je domein **liftbetter.cloud** te koppelen.

### 1. Repository op GitHub

Zorg dat je project op **GitHub** staat en dat je de laatste wijzigingen hebt gepusht (inclusief de map `scripts/` met `render-build.js`). **Niet** pushen: `.local.env`, `js/config.js` (staan in `.gitignore`).

### 2. Nieuwe Static Site op Render

1. Ga naar **[dashboard.render.com](https://dashboard.render.com)** en log in.
2. Klik op **New +** → **Static Site**.
3. Bij **Connect a repository** kies **GitHub** en geef Render toegang tot je account als dat nog niet is gedaan. Selecteer het repository van dit project (bijv. `FitnessAppAffiliates`).
4. Vul de velden in:
   - **Name**: bijvoorbeeld `liftbetter-affiliates` (mag je zelf kiezen).
   - **Branch**: `main` (of de branch die je gebruikt).
   - **Root Directory**: laat **leeg** (project staat in de root).
   - **Build Command**:  
     `node scripts/render-build.js`  
     (Dit script maakt tijdens de build `js/config.js` aan uit je environment variables.)
   - **Publish Directory**:  
     `.`  
     (De hele map na de build is de site; er is geen aparte "output" map.)
5. Klik nog **niet** op **Create Static Site**.

### 3. Environment variables toevoegen

1. Scroll naar **Environment** (of klik op **Advanced** als die sectie verborgen is).
2. Klik op **Add Environment Variable** en voeg deze drie toe (waarden uit je Supabase Dashboard → Project Settings → API):

   | Key | Value |
   |-----|--------|
   | `SUPABASE_URL` | Je Supabase Project URL (bijv. `https://xxxxx.supabase.co`) |
   | `SUPABASE_ANON_KEY` | Je Supabase anon public key |
   | `APP_BASE_URL` | `https://liftbetter.cloud/ref/` |

3. Klik op **Create Static Site**. Render start de eerste deploy.

### 4. Eerste deploy afwachten

- Onder je Static Site zie je **Logs**. De build draait `node scripts/render-build.js` en schrijft `js/config.js`.
- Als de build groen/succesvol is, krijg je een URL zoals **`https://liftbetter-affiliates.onrender.com`**. Open die URL om te testen.

### 5. Custom domain (liftbetter.cloud) toevoegen

1. In Render: open je **Static Site** → tab **Settings**.
2. Scroll naar **Custom Domains**.
3. Klik op **Add Custom Domain**.
4. Voer in: **`liftbetter.cloud`** (en eventueel **`www.liftbetter.cloud`** als je dat ook wilt).
5. Render toont wat je in DNS moet zetten (bijv. CNAME naar `jouw-site.onrender.com` of een A-record).
6. Ga naar de **DNS-instellingen** bij de partij waar je **liftbetter.cloud** hebt gekocht en voeg het CNAME- of A-record toe zoals Render aangeeft.
7. In Render: bij je custom domain kun je **Verify** doen. Na 5–60 minuten wijst **https://liftbetter.cloud** naar je site; Render regelt HTTPS.

### 6. Supabase – Redirect URL

1. Supabase Dashboard → **Authentication** → **URL Configuration**.
2. Bij **Redirect URLs** voeg toe: **`https://liftbetter.cloud/auth-callback.html`** (en eventueel je Render-URL zoals `https://liftbetter-affiliates.onrender.com/auth-callback.html`).
3. Optioneel: **Site URL** = **`https://liftbetter.cloud`**.

### 7. Google Cloud – OAuth

1. [Google Cloud Console](https://console.cloud.google.com) → **APIs & Services** → **Credentials** → je OAuth 2.0 Client.
2. Bij **Authorized JavaScript origins** voeg toe: **`https://liftbetter.cloud`** (en eventueel je Render-URL).
3. **Authorized redirect URIs** blijft: **`https://JOUW_PROJECT_REF.supabase.co/auth/v1/callback`**.

Daarna is de site live op **https://liftbetter.cloud**. Bij elke push naar je branch bouwt Render opnieuw en gebruikt dezelfde environment variables voor `js/config.js`.

---

## 8. Flow summary

| Step | What happens |
|------|----------------|
| 1 | User clicks “Become an affiliate” and lands on the become-affiliate page. |
| 2 | If not signed in: they click **Sign in with Google** and are redirected to Google, then back to the become-affiliate page. |
| 3 | They fill in email, phone, and optionally social media, then click **Contact me**. |
| 4 | Frontend sends the data (with the user’s Supabase JWT) to the Edge Function `submit-affiliate`. |
| 5 | Edge Function: checks JWT, creates/updates a row in `affiliates` (with a unique `affiliate_code`), ensures a row in `affiliate_stats`, and sends an SMS to `AFFILIATE_SMS_TO` via Twilio. |
| 6 | You contact the user and give them their affiliate link (e.g. `https://yourapp.com/ref/{affiliate_code}`). |
| 7 | The affiliate is already stored in Supabase and linked to that `affiliate_code`. When your app tracks clicks/downloads/subscriptions, update `affiliate_stats` for the corresponding `affiliate_id`. |
| 8 | When the user logs in and opens the **Affiliate dashboard**, the site loads their affiliate row and stats from Supabase and shows clicks, downloads, monthly subs, yearly subs, and their link. |

---

## 9. Affiliate links + clicks in dashboard

Affiliate-links zijn je eigen links op je domein (bijv. `https://liftbetter.cloud/join1`). De Edge Function `affiliate-redirect` telt clicks en redirect daarna naar de juiste store.

### 9.1 Edge Functions

- De Edge Function **affiliate-redirect** telt clicks en schrijft (optioneel) event-rows in `affiliate_click_events` voor tijdsgrafieken.
- De Edge Functions **affiliate-download** en **affiliate-subscription** worden door de app aangeroepen om downloads (code ingevuld in paywall) en subscriptions (aankoop met code) te registreren.

### 9.2 `affiliate-redirect` deployen + secrets

1. **Supabase secrets**  
   Supabase Dashboard → **Edge Functions** → **Secrets**. Voeg toe:
   - `APPSTORE_URL`: iOS App Store URL
   - `PLAYSTORE_URL`: Google Play Store URL
   - (optioneel) `AFFILIATE_REDIRECT_FALLBACK`: fallback URL als store URLs ontbreken

2. **Deploy**  
   In de projectmap:

```bash
npx supabase functions deploy affiliate-redirect
npx supabase functions deploy affiliate-download
npx supabase functions deploy affiliate-subscription
```

### 9.3 Affiliate code

De affiliate code is de slug in de link, bijv. `join1` in `https://liftbetter.cloud/join1`. De code beheer je via je affiliate registratie/dashboard.

---

## 10. Overige stats (downloads, subscriptions)

Het dashboard leest verder uit `affiliate_stats` en `affiliate_transactions`. Clicks komen uit `affiliate-redirect`. Downloads en abonnementen komen uit je app via de Edge Functions `affiliate-download` en `affiliate-subscription`.

- Someone downloads via the link → increment `downloads`.
- Someone signs up for a monthly subscription → increment `monthly_subs`.
- Someone signs up for a yearly subscription → increment `yearly_subs`.

Example (from a backend with the Supabase service role key):

```js
await supabase.from('affiliate_stats').update({
  monthly_subs: existing.monthly_subs + 1,
  updated_at: new Date().toISOString()
}).eq('affiliate_id', affiliateId);
```

Resolve `affiliateId` by looking up `affiliates` (by `affiliate_code`).

---

## 11. Troubleshooting

- **“Missing authorization” or “Invalid or expired session”**  
  User is not signed in or token expired. They should sign in again with Google on the become-affiliate page.

- **No SMS received**  
  Check Twilio credentials and that `AFFILIATE_SMS_TO` and `TWILIO_PHONE_NUMBER` are set correctly in Supabase secrets. For Twilio trial accounts, the destination number must be verified. Check Twilio Console → Logs for errors.

- **Google sign-in redirects to wrong URL**  
  In Google Cloud Console, ensure the redirect URI is exactly  
  `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`  
  and that your site’s origin is in Authorized JavaScript origins.

- **Dashboard shows “Complete registration…”**  
  The user has no row in `affiliates` yet. They must complete the form on the become-affiliate page and click **Contact me** once signed in.

- **Config / 404 on config.js**  
  Copy `js/config.example.js` to `js/config.js` and fill in your Supabase URL and anon key so the site can talk to Supabase and the Edge Function.

- **CORS error bij “Contact me” (blocked by CORS policy / preflight)**  
  De Edge Function moet OPTIONS-requests beantwoorden met status 200 en CORS-headers. De code in `supabase/functions/submit-affiliate/index.ts` doet dat. **Redeploy de function** na wijzigingen:  
  `npx supabase functions deploy submit-affiliate`  
  De frontend stuurt ook de `apikey`-header (anon key) mee; zorg dat die in `js/config.js` staat.

- **Clicks op dashboard blijven 0**  
  Check dat `affiliate-redirect` live is en dat je referral links daadwerkelijk naar `https://liftbetter.cloud/<code>` wijzen.

- **401 “Missing authorization header” bij “Contact me”**  
  Het Supabase-gateway controleert standaard de JWT en geeft dan 401 voordat het verzoek je function bereikt. Daarom staat in **`supabase/config.toml`** voor deze function **`verify_jwt = false`**. De function controleert de token zelf (header of body). Zorg dat `supabase/config.toml` in je project staat en **deploy opnieuw**:  
  `npx supabase functions deploy submit-affiliate`  
  Controleer ook dat in **`js/config.js`** je **`supabaseUrl`** en **`supabaseAnonKey`** kloppen (Project Settings → API in het Supabase-dashboard).

---

## Fouten zichtbaar maken (debug) + checklist variabelen

**Debug-paneel op de pagina**

Als je na Google-inloggen errors ziet maar niet weet welke:

1. Ga naar **become-affiliate** met `?debug=1` in de URL, bijvoorbeeld:  
   `http://localhost:3000/become-affiliate.html?debug=1`
2. Klik op **Sign in with Google** en log in zoals normaal.
3. Onder aan de pagina verschijnt een **“Debug: laatste fouten”**-blok met de laatste foutmeldingen.
4. Klik op **Kopieer** om alle regels naar het klembord te kopiëren (bijv. om te plakken in een ticket of hier).

**Checklist: variabelen en keys die goed moeten staan**

| Waar | Wat | Waar te vinden |
|------|-----|----------------|
| **js/config.js** | `supabaseUrl` | Supabase Dashboard → Project Settings → API → Project URL (bijv. `https://xxxx.supabase.co`) |
| **js/config.js** | `supabaseAnonKey` | Supabase Dashboard → Project Settings → API → anon public key |
| **Supabase** | Redirect URL voor auth | Supabase Dashboard → **Authentication** → **URL Configuration** → **Redirect URLs**. Voeg exact toe: `http://localhost:3000/auth-callback.html` (of de poort die jij gebruikt). Voor productie ook `https://jouwdomein.com/auth-callback.html`. |
| **Google Cloud** | OAuth redirect URI | Google Cloud Console → APIs & Services → Credentials → je OAuth 2.0 Client → **Authorized redirect URIs**: moet `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback` zijn (zelfde projectref als in Supabase URL). |
| **Google Cloud** | JavaScript origins | In dezelfde OAuth client: **Authorized JavaScript origins**: `http://localhost:3000` (dev) en `https://jouwdomein.com` (prod). |
| **Supabase** | `APPSTORE_URL` | Edge Functions → Secrets. iOS App Store URL. |
| **Supabase** | `PLAYSTORE_URL` | Edge Functions → Secrets. Google Play Store URL. |

Veelvoorkomende fouten bij Google-inlog:

- **Redirect URL not allowed** → De exacte URL van auth-callback staat niet in Supabase Redirect URLs of in Google Authorized redirect URIs (Supabase-callback).
- **Invalid or expired session** / **No session after popup** → Sessie wordt niet in de popup opgeslagen; controleer of de redirect na inloggen echt naar jouw auth-callback.html gaat (zelfde origin als de site).
- **Popup blocked** → De browser blokkeert het popupvenster; sta popups voor deze site toe.

---

## Terminal en errors bekijken

**Server / localhost-terminal**

Om de terminal te zien waar je lokale server draait (en eventuele errors):

1. In Cursor: **View** → **Terminal** (of `Ctrl+`` `).
2. Start de server in die terminal, bijvoorbeeld:
   - `npm run serve` (als je npm gebruikt), of
   - `npx serve .` (poort 3000), of
   - `python -m http.server 8080`
3. Alle logregels en errors van de server verschijnen in die terminal.

**Browser / frontend-errors**

De site draait in de browser; auth- en netwerkfouten zie je in de **Developer Console**:

1. Open je site in Chrome of Edge.
2. Druk op **F12** (of rechtsklik → **Inspect**).
3. Ga naar het tabblad **Console**.
4. Bij inloggen of formulierverzenden verschijnen hier nu ook `[Auth]`- en `[BecomeAffiliate]`-logs. Rode regels zijn errors.
