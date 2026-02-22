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
4. Open op je computer het bestand `supabase/migrations/001_affiliates.sql` (in deze projectmap). Kopieer **alle** tekst uit dat bestand.
5. Plak die tekst in het grote invoerveld in de SQL Editor.
6. Klik onderaan op **Run** (of Ctrl+Enter).
7. Als het goed is, zie je onderaan iets als “Success” of “Success. No rows returned”. De tabellen bestaan nu.

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

## 9. Updating stats (clicks, downloads, subscriptions)

The dashboard reads from the `affiliate_stats` table. Your main app (or another backend) should update this table when:

- Someone clicks the affiliate link → increment `clicks`.
- Someone downloads via the link → increment `downloads`.
- Someone signs up for a monthly subscription via the link → increment `monthly_subs`.
- Someone signs up for a yearly subscription via the link → increment `yearly_subs`.

Example (from a backend with the Supabase service role key):

```js
await supabase.from('affiliate_stats').update({
  clicks: existing.clicks + 1,
  updated_at: new Date().toISOString()
}).eq('affiliate_id', affiliateId);
```

Resolve `affiliateId` by looking up `affiliates` with `affiliate_code` from the link (e.g. from the URL path or query parameter).

---

## 10. Troubleshooting

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
