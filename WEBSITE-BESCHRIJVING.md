# Volledige beschrijving van de website – Fitness App Affiliates (Lift Better)

Dit document beschrijft elk scherm van de website in detail: alle teksten, knoppen, functies en elementen.

---

## Algemene structuur (alle pagina’s)

- **Navigatiebalk (nav):** Boven aan elke pagina.
- **Footer:** Onderaan elke pagina.
- **Fonts:** Google Fonts – DM Sans (body), Outfit (headings).
- **Stylesheet:** `css/style.css`.
- **Favicon:** `favicon.png`.

---

## Navigatie (elke pagina)

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Logo** | Link | Tekst: "Lift**Better**" (Better in andere stijl). Link: `index.html`. |
| **Menu-knop** | Button | Label: "Menu". `aria-label`: "Open navigation menu". Opent/sluit het navigatiepaneel. Bevat drie horizontale streepjes (hamburger-icoon). |
| **Navigatiepaneel** | Panel (verborgen standaard) | Bevat alle nav-links. `id="nav-menu"`, `hidden` tot het wordt geopend. |
| **Home** | Link | Tekst: "Home". Link: `index.html`. Op Home-pagina: class `active`. |
| **Become affiliate** | Link | Tekst: "Become affiliate". Link: `become-affiliate.html`. Op Become-affiliate-pagina: `active`. |
| **Affiliate dashboard** | Link | Tekst: "Affiliate dashboard". Link: `affiliate.html`. Op dashboard-pagina: `active`. |
| **Log in** | Button | Tekst: "Log in". Class: `nav-menu-link nav-menu-link-button`, `data-nav-login`. Standaard `display: none`; wordt getoond door JS als gebruiker niet is ingelogd. |
| **Log out** | Button | Tekst: "Log out". Class: `nav-menu-link nav-menu-link-button`, `data-nav-logout`. Standaard `display: none`; wordt getoond door JS als gebruiker is ingelogd. |

---

# Scherm 1: Home (`index.html`)

**Titel (browser):** "Fitness App Affiliates – Earn with the app that actually works"

## Hero-sectie

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Hoofdtitel** | H1 | "Why become an affiliate?" |
| **Ondertitel** | Paragraaf | "We've made the product. / Just promote it... / Get up to **90% commission** on profits of the first month. / Get up to **50% commission** on profits of the first year." (highlight rond 90% en 50%) |

## Kaart "How it works"

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "How it works" |
| **Lijst** | Genummerde lijst (ol) | 1. We give you a personal link. 2. You promote the app however you want. 3. You can track your clicks, downloads, and subscriptions live in your dashboard. 4. You get 90% commission on the first month's profits from your link. 5. You get 50% commission on the first year's profits from your link. |

## Sectie "Is this for you?"

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "Is this for you?" |
| **Kaart 1 – Label** | Span | "Believe in our product?" |
| **Kaart 1 – Tekst** | Paragraaf | "There are thousands of fitness apps, but they all miss correct information. By building an enormous codebase, we've created the first app that gives every individual their optimal workout schedule." |
| **Kaart 2 – Label** | Span | "Got convincing power?" |
| **Kaart 2 – Tekst** | Paragraaf | "Asking €25/month for a workout app is not easy. We've got the best app, but it's your task to convince your audience. You get full creative freedom to promote the app, so your earnings are in your hand." |
| **Kaart 3 – Label** | Span | "Willing to grow?" |
| **Kaart 3 – Tekst** | Paragraaf | "It's our ambition to give every gym goer the best advice possible. You help us grow, and we help you grow. We know how to convince and we will help you with becoming a successful affiliate." |

## Sectie "The app" (`id="the-app"`)

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "The app your audience actually uses" |
| **Paragraaf 1** | p | "Structured training plans, exercise instructions, and clear progress tracking. The app is built so users make more progress in less time – which makes it easy for you to recommend." |
| **Paragraaf 2** | p | "We continuously ship updates, listen to user feedback, and keep programming aligned with real training science. You never have to worry about maintaining the product yourself." |
| **Screenshot 1** | img | `images/Screenshot-1.png`, alt: "Lift Better app – home and overview screen" |
| **Screenshot 2** | img | `images/Screenshot-2.png`, alt: "Lift Better app – training plan and week overview" |
| **Screenshot 3** | img | `images/Screenshot-3.png`, alt: "Lift Better app – exercise execution and technique cues" |
| **Screenshot 4** | img | `images/Screenshot-4.png`, alt: "Lift Better app – progress tracking and history" |
| **App Store-knop** | Link | Afbeelding: `images/Download_on_the_App_Store_Badge.svg.webp`. Link: `https://liftbetter.cloud/join2/`. `aria-label`: "Download Lift Better on the App Store" |
| **Google Play-knop** | Link | Afbeelding: `images/Google_Play_Store_badge_EN.svg.webp`. Link: `https://liftbetter.cloud/join2/`. `aria-label`: "Get Lift Better on Google Play" |

## CTA

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Knop** | Link, class `btn btn-primary` | Tekst: "More details". Link: `become-affiliate.html`. `id="btn-more-details"` |

## Footer

Tekst: "Fitness App Affiliates – Together for a fitness app that actually works."

---

# Scherm 2: Become affiliate (`become-affiliate.html`)

**Titel (browser):** "Become an affiliate – Fitness App Affiliates"

## Kop

| Element | Type | Tekst |
|--------|------|--------|
| **Titel** | H1, class `section-title` | "Become an affiliate" |
| **Ondertitel** | p, class `section-subtitle` | "All the details about the affiliate program and how to join." |

## Auth-gate (inlogscherm) – `id="auth-gate"`

Wordt getoond als de gebruiker nog niet is ingelogd (en auth is geconfigureerd). Standaard `display: none`.

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Titel** | H2 | "Sign in to become an affiliate" |
| **Knop** | Button, `id="btn-google"`, class `btn btn-primary` | "Sign in to become an affiliate". Opent Google Sign-in popup. |

## Formulierblok – `id="form-block"`

Wordt getoond na inloggen of als er geen auth is. Standaard `display: none` tot auth/form logic het toont.

### Kaart: "How much will you earn?"

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "How much will you earn?" |
| **Lijst** | ul | • Note: our prices are subject to change. • Note: The appstore and playstore take 15% of the revenue. Commission is paid on the net revenue. • For every monthly subscription from your link, we pay out 90% of the net revenue of the first month. • For every yearly subscription from your link, we pay out 50% of the net revenue of the first year. • You can track your subscriptions in your dashboard, and we will pay you out every 1st of the month. • Custom offers and partnerships are allowed, but not guaranteed. |

### Kaart: "How does the sign-up process work?"

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "How does the sign-up process work?" |
| **Lijst** | ul | 1. Fill out the form below, and we will contact you within 48 hours. 2. You will get access to your dashboard, where you can find your unique link too. 3. That's it, you can start sharing the link. |

### Kaart: "Track all of your stats"

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "Track all of your stats" |
| **Paragraaf 1** | p | "After we've created your personal link, you will get access to your dashboard. In your dashboard you can see all the stats of your link, such as clicks, downloads, and subscriptions." |
| **Paragraaf 2** | p | "Tracking is measured directly by the LiftBetter app and our backend." |
| **Form note** | p, class `form-note` | "Affiliate code is chosen during registration and can be changed in the dashboard. A download is counted when a user enters the code in the in-app paywall (no purchase). A subscription is counted when a user makes a purchase using the affiliate code. Users get 10% off when they enter a valid code. If multiple codes are entered, only the first code counts for both downloads and subscriptions." |
| **Knop** | Link, class `btn btn-secondary` | "Privacy policy". Link: `privacy.html`, target `_blank`, rel `noopener`. Styling: `color: var(--accent)` |

### Sectie: Affiliate terms

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "Affiliate terms & conditions" |
| **Tekst** | p | "By becoming an affiliate, you agree to our terms and conditions." |
| **Knop** | Link, class `btn btn-secondary` | "Affiliate terms & conditions". Link: `terms.html`, target `_blank`, rel `noopener`. Styling: `color: var(--accent)` |

### Kop: Registration form

| Element | Type | Tekst |
|--------|------|--------|
| **Titel** | H2, class `section-title` | "Registration form" |
| **Ondertitel** | p, class `section-subtitle` | "After registering you can start already, but we contact you to make you an amazing affiliate." |

### Formulier – `id="affiliate-form"`, class `card`, max-width 600px

| Veld | Label | Type | Placeholder / opties | Verplicht |
|------|--------|------|----------------------|------------|
| **email** | "Email address *" | input type="email", id="email", name="email" | "you@example.com" | Ja |
| **phone** | "Phone number (optional)" | input type="tel", id="phone", name="phone" | "+1 234 567 8900" | Nee |
| **social** | "Social media (optional)" | input type="text", id="social", name="social" | "Instagram, TikTok, YouTube, etc." | Nee |
| **preferred-method** | "Preferred contact method (optional)" | select, id="preferred-method", name="preferred_method" | Opties: "No preference", "Email", "WhatsApp", "Messages", "Phone call", "Instagram", "TikTok", "Other social media" | Nee |
| **terms-consent** | (checkbox-label) | checkbox, id="terms-consent" | — | Ja (required) |
| **privacy-consent** | (checkbox-label) | checkbox, id="privacy-consent" | — | Ja (required) |

**Checkbox-labels:**

- Terms: "By clicking "Contact me", I agree with the [terms and conditions](terms.html)."
- Privacy: "I have read and agree with the [privacy policy](privacy.html)."

**Submit-knop:** Button, type="submit", class `btn btn-primary`, id="btn-submit". Tekst: **"Contact me"**.

**Form note bij preferred method:** "We'll try to contact you using this channel first."

### Feedback na verzenden

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Succesbericht** | p, id="form-message" | Groene kleur (`var(--success)`), standaard `display: none`. Wordt getoond na succesvolle submit. |
| **Foutbericht** | p, id="form-error" | Kleur #ef4444, standaard `display: none`. Wordt getoond bij validatie- of serverfout. |

### Debug-paneel (alleen bij `?debug=1`)

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Paneel** | div, id="debug-panel" | Donkere achtergrond, monospace font. Bevat "Debug: laatste fouten" en knop "Kopieer". |
| **Knop** | Button, id="debug-copy" | "Kopieer" – kopieert debug-log naar klembord. |
| **Log** | pre, id="debug-log" | Toont laatste fouten (max 10). |

## Footer

"Fitness App Affiliates – Together for a fitness app that actually works."

---

# Scherm 3: Affiliate dashboard (`affiliate.html`)

**Titel (browser):** "Affiliate dashboard – Lift Better"

## Kop

| Element | Type | Tekst |
|--------|------|--------|
| **Titel** | H1, class `section-title` | "Affiliate dashboard" |
| **Ondertitel** | p, class `section-subtitle` | "See exactly what your link is doing – earnings, funnel, payouts and everything you need to grow." |

---

## Scherm 3a: Gate (niet ingelogd) – `id="dashboard-gate"`

Wordt getoond als de gebruiker niet is ingelogd. Max-width 480px, standaard `display: none`.

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Titel** | H2 | "Sign in to view your stats" |
| **Tekst** | p | "You need to be signed in with the Google account you used to register as an affiliate." |
| **Knop** | Button, id="btn-google", class `btn btn-primary` | "Sign in with Google". Opent Google Sign-in; bij succes wordt het dashboard geladen. |

---

## Scherm 3b: Dashboard-inhoud – `id="dashboard-content"`

Wordt getoond zodra de gebruiker is ingelogd en (indien van toepassing) een affiliate-record heeft.

### Blok 1: Earnings overview (kaart)

| Element | Type | Tekst / Inhoud (dynamisch) |
|--------|------|----------------------------|
| **Titel** | H2 | "Earnings overview" |
| **Uitleg** | p, muted | "Expected total earnings from your link – This number is only an estimate, and might differ from the actual earnings." |
| **Hoofdgetal** | div, id="earnings-expected-total", class `earnings-main-number` | Bijv. "€0" (format: EUR, nl-NL) |
| **Subtitle** | div, id="earnings-subtitle" | "Based on approved & pending commissions." |
| **Label** | div | "Paid out (all time)" |
| **Waarde** | div, id="earnings-paid-out" | Bijv. "€0" |
| **Label** | div | "Expected payouts" |
| **Waarde** | div, id="earnings-expected-payouts" | Bijv. "€0" |
| **Volgende payout** | p, id="earnings-next-payout" | "Next payout: [id=earnings-next-payout-date] · Minimum payout: €50" |
| **Datum** | span, id="earnings-next-payout-date" | Bijv. "1st of next month" (maandnaam in en-GB) |

### Blok 2: Your affiliate link (kaart)

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Titel** | H2 | "Your affiliate link" |
| **Uitleg** | p, muted | "Share this link so every click, install and subscription is tracked." |
| **Link** | code, id="affiliate-link" | Toont de volledige affiliate-URL (origin + "/" + affiliate_code). Als geen account: "Complete registration on the Become affiliate page to get your link." of placeholder "—". |
| **Knop** | Button, id="btn-copy-link", class `btn btn-secondary btn-ghost` | "Copy". Kopieert de link naar klembord; korte tijd "Copied". |
| **Meta** | span, id="affiliate-qr-note" | "Want different links for different channels? Message us." |

### Blok 3: Key metrics (kaart)

| Element | Type | Labels / IDs (waarden dynamisch) |
|--------|------|----------------------------------|
| **Titel** | H2 | "Key metrics" |
| **Ondertitel** | p | "Quick snapshot of how your link is performing." |
| **KPI: Clicks** | kpi-card | Label: "Clicks". Waarde: id="kpi-clicks-all" (bijv. 0). Sub: id="kpi-clicks-breakdown" → "iOS: 0" / "Android: 0" |
| **KPI: Installs** | kpi-card | Label: "Installs (attributed)". Waarde: id="kpi-installs-all". Sub: id="kpi-installs-breakdown" → iOS/Android |
| **KPI: Monthly subs** | kpi-card | Label: "Monthly subscriptions". Waarde: id="kpi-monthly-subs". Sub: "All-time monthly subscriptions." |
| **KPI: Yearly subs** | kpi-card | Label: "Yearly subscriptions". Waarde: id="kpi-yearly-subs". Sub: "All-time yearly subscriptions." |
| **KPI: Click → Install** | kpi-card | Label: "Click → Install". Waarde: id="kpi-conv-click-install-main" (%). Sub: id="kpi-conv-click-install-sub" (all-time uitleg) |
| **KPI: Install → Subscription** | kpi-card | Label: "Install → Subscription". Waarde: id="kpi-conv-install-sub-main". Sub: id="kpi-conv-install-sub-sub" |
| **KPI: Click → Subscription** | kpi-card | Label: "Click → Subscription". Waarde: id="kpi-conv-click-sub-main". Sub: id="kpi-conv-click-sub-sub" |
| **KPI: EPU** | kpi-card | Label: "Avg earnings per user (EPU)". Waarde: id="kpi-epu-main". Sub: id="kpi-epu-breakdown" → "Based on all paying users." |

### Blok 4: Performance analytics (kaart)

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Titel** | H2 | "Performance analytics" |
| **Ondertitel** | p | "See how your traffic turns into installs, paying users and revenue." |
| **Label** | label for="date-from" | "Range" |
| **Datum van** | input type="date", id="date-from" | Startdatum range |
| **Datum tot** | input type="date", id="date-to" | Einddatum range |
| **Knop** | Button, id="btn-range-apply", class `btn btn-secondary btn-ghost` | "Apply" |
| **Knop** | Button, id="btn-range-30d", class `btn btn-secondary btn-ghost` | "Last 30 days" |

**Chart: Clicks per day**

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | div, class `chart-title` | "Clicks per day" |
| **Subtitle** | div, class `chart-subtitle` | "See how often people hit your link." |
| **Label 7d** | div | "Last 7 days" |
| **Sparkline** | div, id="sparkline-clicks-7d", class `sparkline` | Staafdiagram of "Waiting for data…" / "No data yet." |
| **Label 30d** | div | "Last 30 days" |
| **Sparkline** | id="sparkline-clicks-30d" | Idem |
| **Label 12m** | div | "Last 12 months" |
| **Sparkline** | id="sparkline-clicks-365d" | Idem |

**Chart: Revenue & conversion trend**

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | div, class `chart-title` | "Revenue & conversion trend" |
| **Subtitle** | div, id="chart-revenue-subtitle" | Bijv. "Last 30 days" of datumrange |
| **Sparkline** | div, id="sparkline-revenue" | Primaire serie: revenue per dag; secundaire serie (muted bars): conversies per dag |

**Funnel insight**

| Element | Type | Tekst / IDs |
|--------|------|-------------|
| **Titel** | div, class `chart-title` | "Funnel insight" |
| **Subtitle** | div | "From click to install to paid user." |
| **Stap 1** | funnel-step | Label: "1. Clicks". Waarde: id="funnel-clicks" |
| **Stap 2** | funnel-step | Label: "2. Installs". Waarde: id="funnel-installs" (getal + percentage) |
| **Stap 3** | funnel-step | Label: "3. Paying users". Waarde: id="funnel-paying-users" (getal + %) |
| **Stap 4** | funnel-step | Label: "4. Earned". Waarde: id="funnel-earned" (€) |
| **Note** | p, class `funnel-note`, id="funnel-note" | "Use this to decide: do I need more traffic, or do I need to improve my content and conversion?" |

### Blok 5: Payouts (kaart)

| Element | Type | Tekst / IDs |
|--------|------|-------------|
| **Titel** | H2 | "Payouts" |
| **Ondertitel** | p | "See what is ready to be paid out and what has already been paid." |
| **Label** | p, class `payout-meta-item-label` | "Minimum payout" |
| **Waarde** | p, class `payout-meta-item-value` | "€50" (vast) |
| **Label** | p | "Available payout" |
| **Waarde** | p, id="payout-available" | Dynamisch (€) |
| **Label** | p | "Next payout date" |
| **Waarde** | p, id="payout-next-date" | Bijv. "1 March" (en-GB maandnaam) of "—" |
| **Label** | p | "Payout method" |
| **Waarde** | p, id="payout-method" | Bijv. "Not set yet" of ingestelde methode |
| **Badge** | span, id="payout-verified-badge", class `badge badge-muted` of `badge-success` | "Payment details not verified" of "Payment details verified" |
| **Label** | p | "Payout history" |
| **Lijst** | ul, id="payout-history" | Lijst items: "YYYY-MM" + bedrag, of "No payouts yet" + "—" |
| **Uitleg** | p | "Payouts are processed manually. If you have reached the minimum payout threshold, we'll contact you using your preferred method." |

### Blok 6: Commission structure & targets (kaart)

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "Commission structure & targets" |
| **Ondertitel** | p | "Know exactly what you earn and what the next bonus is." |
| **Subkaart titel** | H3 | "Commission rules" |
| **Lijst** | ul, class `list-compact` | • Monthly subscription: 90% commission on our net revenue. • Yearly subscription: 50% commission on our net revenue. • No commission is paid on refunded subscriptions. • Downloads and subscriptions are approved after 60 days. • Download = code entered in paywall. Subscription = purchase with code. |
| **Subkaart titel** | H3 | "Current tier" |
| **Tier** | p, strong id="commission-tier" | Bijv. "Base tier" |
| **Uitleg** | p, muted | "As your performance grows, we may move you into a higher tier with extra bonuses." |

### Blok 7: Announcements (kaart)

| Element | Type | Tekst / Inhoud |
|--------|------|----------------|
| **Titel** | H2 | "Announcements" |
| **Ondertitel** | p | "What's new in the app and affiliate program." |
| **Subkaart titel** | H3 | "Upcoming changes" |
| **Inhoud** | p, id="announcements-list" (grid), muted | "2-03 App update: New store listing: **Improves clicks → installs** / 2-03 App update: Updated survey: **Improves installs → subscriptions** / 9-03 App update: Improved UI/UX / Coming soon: Workout statistics page / Coming soon: Workout Reviewer" (accentkleur voor de benadrukte delen) |

### Blok 8: Account, settings & support (kaart)

| Element | Type | Tekst / IDs |
|--------|------|-------------|
| **Titel** | H2 | "Account, settings & support" |
| **Ondertitel** | p | "All the basics you need plus a fast way to reach us." |
| **Subkaart** | card | **Titel H3:** "Account". Lijst: Affiliate ID: id="account-affiliate-id", Affiliate code: id="account-affiliate-code", Join date: id="account-join-date", Commission tier: id="account-commission-tier", Tax info: id="account-tax-status" (bijv. "Not provided yet") |
| **Subkaart** | card | **Titel H3:** "FAQ & terms". Lijst: Link "Affiliate terms & conditions" (terms.html), Link "Privacy policy" (privacy.html), "FAQ: payouts, refunds, tracking (we'll keep expanding this)." |
| **Subkaart** | card | **Titel H3:** "Support". Tekst: "Got questions about your stats, payouts or how to promote the app better?" Lijst: "Contact: " + id="support-contact" ("You'll receive our direct contact after onboarding."), "Status: " + badge "Active" (badge-success) |

## Footer (dashboard)

"Lift Better – Together for a fitness app that actually works."

---

## Uitgecommentarieerde onderdelen (niet zichtbaar in de UI)

- **Transactions & installs:** Tabel met Date, Type, Subscription, Status, Commission, Payout status, Hold; badge "60-day hold"; lege staat "No installs or subscriptions yet...". Tabel-body id="transactions-body", lege id="transactions-empty".
- **Milestones:** 10 sales / 25 installs progress bars en teksten (in commentaar).
- **Marketing assets:** App visuals, Stories & short-form, Copy & scripts (in commentaar).

---

# Scherm 4: Affiliate Terms & Conditions (`terms.html`)

**Titel (browser):** "Affiliate Terms & Conditions – OptimalFitness / LiftBetter"

## Kop

| Element | Type | Tekst |
|--------|------|--------|
| **Titel** | H1 | "Affiliate Terms & Conditions" |
| **Ondertitel** | p, class `section-subtitle` | "These terms apply to the affiliate program of **OptimalFitness** for the mobile app **Lift Better - Perfect Workouts**." |
| **Datum** | p | "*Last updated: 26 February 2026*" |

## Secties (alleen tekst, geen knoppen)

- **1. Parties and definitions** – Company, Product, Affiliate, Affiliate account, Affiliate channel, Affiliate link, Customer, Commission.
- **2. Joining the program** – Registratie, acceptatie voorwaarden, goedkeuring/afwijzing, afwijzing bij ongepaste content.
- **3. Nature of the program** – Fitness app, commissie op abonnementen, onafhankelijke partner.
- **4. Promotion rules** – Alleen goedgekeurde kanalen, transparantie, verboden (naamsmisbruik, brand bidding zonder toestemming, spam, eigen kortingen, etc.), social disclosure (#ad/#affiliate).
- **5. Commission and payouts** – Wanneer commissie, structuur in dashboard, netto-ontvangsten, maandelijkse uitbetaling, minimum €50, bevestigde commissie binnen 60 dagen, betalingsgegevens en belastingen. Sub: Tracking, cookies, last-click attribution, cookie-duur.
- **6. Fraud, misuse and adjustments** – Inhouden/annuleren commissie bij fraude, self-referrals, manipulatie, schending; correcties.
- **7. Duration and termination** – Vanaf acceptatie, opzegging door affiliate, schorsing/beëindiging door ons, gevolgen na beëindiging.
- **8. Liability and disclaimers** – Verantwoordelijkheid affiliate, “as is”, beperking aansprakelijkheid.
- **9. Data protection** – Beperkte klantinformatie, GDPR/privacy policy.
- **10. Changes to these terms** – Wijzigingen publiceren/meedelen; voortgezet gebruik = acceptatie.
- **11. Governing law** – Nederlands recht, bevoegde rechter Nederland.

Onderaan: korte disclaimer dat deze pagina de affiliate terms voor OptimalFitness/LiftBetter zijn.

**Footer:** "OptimalFitness – LiftBetter, the fitness app that actually works."

---

# Scherm 5: Privacy Policy (`privacy.html`)

**Titel (browser):** "Privacy Policy – LiftBetter"

## Kop

| Element | Type | Tekst |
|--------|------|--------|
| **Titel** | H1 | "Privacy Policy – LiftBetter" |
| **Ondertitel** | p, class `section-subtitle` | "How we collect, use, and protect your data when you use our website, app, and services." |
| **Datum** | p | "**Last updated: 26 February 2026**" |

Inhoud: OptimalFitness V.O.F., De Boog 32, Heiloo, KvK 97730238, optimalfitnessapp@outlook.com. Daarna:

- **1. Information We Collect** – Account & usage data, payment data (App Store/Play, geen opslag betaalgegevens).
- **2. Affiliate & Install Tracking** – LiftBetter app + backend: clicks via referral link, download-event wanneer code in paywall wordt ingevuld, subscription-event bij aankoop met code.
- **3. How We Use Your Data** – Operationeel, tracking, commissies, UX, fraud, legal.
- **4. Legal Basis (GDPR)** – Contract, legitimate interest, legal obligation.
- **5. Data Sharing** – Supabase, app stores, hosting; geen verkoop data.
- **6. Data Retention** – Zo lang nodig; verwijdering op verzoek.
- **7. Your Rights (EU/EEA)** – Toegang, correctie, verwijdering, bezwaar, portability; contact e-mail; 30 dagen.
- **8. Cookies & Tracking** – Doel, duur, last-click regel; toestemming gebruik site.
- **9. Data Security** – Redelijke maatregelen; geen garantie.
- **10. Children** – Niet onder 13.
- **11. Changes** – Updates op website.
- **12. Contact** – Adres en e-mail voor privacyvragen.

**Footer:** "OptimalFitness – LiftBetter, the fitness app that actually works."

---

# Scherm 6: Auth callback (`auth-callback.html`)

**Titel (browser):** "Sign-in successful"

Minimale layout (eigen inline styles), geen gewone nav/footer.

| Element | Type | Tekst / Gedrag |
|--------|------|----------------|
| **Tekst** | p | "Sign-in successful." |
| **Status** | p, id="status" | "One moment…" of "Redirecting to the form…" of "You can close this window or continue here." of "Sign-in problem. Try closing this window and sign in again." |
| **Link** | a, id="continue-link", class `btn` | "Continue to form". Standaard verborgen; getoond in popup als window niet sluit. Link: `next` query-parameter of standaard `become-affiliate.html`. |

**Functie:** Verwerkt OAuth callback (hash/query `code`), wisselt code voor sessie, sluit popup of redirect naar `next`-pagina. Bij geen opener: redirect naar form.

---

## Technische afhankelijkheden (alle pagina’s waar van toepassing)

- **Supabase:** `@supabase/supabase-js@2`
- **Config:** `js/config.js`
- **Auth:** `js/auth.js` (affiliate, become-affiliate, auth-callback)
- **Nav:** `js/nav-auth.js`, `js/nav-menu.js`
- **Dashboard-data:** Supabase-tabellen `affiliates`, `affiliate_stats`, `affiliate_transactions`, `affiliate_click_events`
- **Become-affiliate submit:** Edge function `submit-affiliate` (POST met access_token, email, phone, social_media, preferred_contact_method)

---

*Document gegenereerd op basis van de huidige HTML/JS in het project. Uitgecommentarieerde secties (transactions, milestones, marketing assets) zijn beschreven als “niet zichtbaar” maar wel in de bron aanwezig.*
