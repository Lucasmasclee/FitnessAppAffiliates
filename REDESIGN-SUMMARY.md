# Affiliate Onboarding Redesign – Summary

## 1. Biggest onboarding problems in the current site

- **Friction before value:** The home page leads with "Why become an affiliate?" and commission numbers before clearly stating what Lift Better is or who the program is for. The main CTA is a single "More details" at the bottom.
- **Information hierarchy:** The become-affiliate page stacks earnings, sign-up process, tracking, and terms as separate blocks with similar weight. Legal and commission details are not ordered for conversion (trust first, then details, then form).
- **Registration experience:** The form appears after a hard auth gate with little context. There is no clear intro above the form, and the success state is a short line of text with an optional "Go to dashboard" link—no next steps or Creator Kit mention.
- **Trust fragmented:** Terms and privacy are inline links in the middle of the page. Consent checkboxes sit at the bottom of the form. The page doesn’t frame "rules exist and we take privacy seriously" as reassurance before submit.
- **Auth feels disconnected:** Sign-in is required before any program details are visible. There’s no explanation of why Google is used. The callback page is minimal. The nav doesn’t clearly reflect "signed in but not registered" vs "signed in, ready for dashboard."
- **Dashboard has no onboarding:** New affiliates (no traffic yet) see the same layout as active affiliates. There’s no "first steps" (copy link, what it does, where stats appear, payouts, support). No placeholder for a future Creator Kit.
- **No single funnel:** The site feels like separate pages (home, become affiliate, dashboard) rather than one guided path: interest → details & trust → registration → activation.

---

## 2. Improved affiliate onboarding funnel (step by step)

1. **Landing / interest (home)**  
   - Hero: what Lift Better is, why the program is attractive, who it’s for, and the next action.  
   - How it works: 3–5 clear step cards (link → promote → track → earn).  
   - Why creators join: sharper, scannable "is this for you?" section.  
   - App proof: stronger "real product, worth promoting" section with screenshots and store links.  
   - Primary CTA: one clear next step (e.g. "See program details" → become-affiliate).

2. **Details / trust (become affiliate)**  
   - Intro: what this page is, what creators can expect, what happens after they apply.  
   - Earnings block: same commission rules (90% / 50%, net revenue, platform fees, payout cadence, custom offers), improved layout and hierarchy.  
   - Sign-up process block: submit form → we contact you → dashboard + link → start sharing.  
   - Tracking / dashboard / attribution block: same AppsFlyer and privacy wording, easier to scan.  
   - Terms & privacy reassurance: same links and consent; presented as "review before you submit."  
   - Registration form: clearer intro, grouped fields, helper text, professional submit CTA.  
   - Post-submit: clear success state with "we’ll contact you," "dashboard available," next steps, and where the Creator Kit will live.

3. **Registration / entry (auth + form)**  
   - User clicks "Become affiliate" or "Start" from home.  
   - Become-affiliate page shows program summary and value before any gate.  
   - When auth is required: explicit "Sign in with Google to continue" and short explanation why (e.g. one account for dashboard and link).  
   - After sign-in: show registration form if not yet registered; after submit, show success and direct to dashboard.  
   - Callback: redirect to `next` (e.g. become-affiliate or dashboard); fallback "Continue to form" link.  
   - Nav: Log in / Log out and active states so it’s clear whether the user is signed in and where they are.

4. **Activation (dashboard)**  
   - New affiliates (no or zero stats): onboarding strip/card with first actions (copy link, what the link does, where stats appear, payouts, support, Creator Kit).  
   - All affiliates: same data (earnings, link, KPIs, analytics, payouts, commission rules, announcements, account & support).  
   - Creator Kit: dedicated entry (card/section) with "Promo resources, scripts, hooks, app visuals—coming soon."

---

## 3. How legal / commission / attribution are preserved

- **Commission:** All numbers and rules unchanged: 90% on first month’s net revenue for monthly subs, 50% on first year’s net revenue for yearly subs. Notes on app store cut (15%), net revenue, payout on the 1st of the month, and "custom offers allowed but not guaranteed" are kept; only layout and wording clarity improved.
- **Payouts:** Minimum payout (€50), payout timing (e.g. 1st of the month), and "we’ll contact you when you reach threshold" are unchanged.
- **Attribution:** AppsFlyer attribution, "most recent eligible click," and "attribution windows may vary" are kept verbatim where they appear (become-affiliate and dashboard).
- **Approval / tracking:** 60-day approval for installs/subscriptions and related dashboard logic are not changed.
- **Terms & privacy:** No changes to the content or meaning of `terms.html` and `privacy.html`. Links and required consent checkboxes remain; they are grouped in a reassurance block and positioned so creators can "review before you submit."

---

## 4. Where and how the Creator Kit placeholder is added

- **Dashboard:** A dedicated **Creator Kit** card (or "Resources") in the dashboard content area. Copy: this is where approved affiliates will find promo resources; scripts, hooks, app visuals, and posting guidance will live here; "Coming soon" or "Available soon." No actual kit content or links are added—only the entry point and messaging.
- **Post-registration success (become-affiliate):** In the success state after form submit, one line or bullet: "You’ll find promo resources (scripts, visuals, guides) in your dashboard under **Creator Kit** once they’re available."

This gives a single, consistent place for the future Creator Kit in both the dashboard and the post-signup flow.
