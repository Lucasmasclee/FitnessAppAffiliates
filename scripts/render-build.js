/**
 * Build script for Render.com static site.
 * Reads SUPABASE_URL, SUPABASE_ANON_KEY, APP_BASE_URL from environment
 * and writes js/config.js so the site works without committing secrets.
 */
const fs = require("fs");
const path = require("path");

const supabaseUrl = process.env.SUPABASE_URL || "";
const supabaseAnonKey = process.env.SUPABASE_ANON_KEY || "";
const appBaseUrl = process.env.APP_BASE_URL || "https://liftbetter.cloud/ref/";
const branchLinkBaseUrl = process.env.BRANCH_LINK_BASE_URL || "https://liftbetter.app.link";

const config = `window.AFFILIATE_CONFIG = {
  supabaseUrl: ${JSON.stringify(supabaseUrl)},
  supabaseAnonKey: ${JSON.stringify(supabaseAnonKey)},
  appBaseUrl: ${JSON.stringify(appBaseUrl)},
  branchLinkBaseUrl: ${JSON.stringify(branchLinkBaseUrl)},
};
`;

const outDir = path.join(__dirname, "..", "js");
const outPath = path.join(outDir, "config.js");
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outPath, config, "utf8");
console.log("Wrote js/config.js from environment variables.");

// Render serves /join/<code> via rewrite to join/index.html (see _redirects).
// Rewriting to /index.html alone returns an empty body on Render; this matches the pre-redesign setup.
const rootDir = path.join(__dirname, "..");
const indexPath = path.join(rootDir, "index.html");
const joinDir = path.join(rootDir, "join");
const joinIndexPath = path.join(joinDir, "index.html");
if (!fs.existsSync(joinDir)) fs.mkdirSync(joinDir, { recursive: true });
fs.copyFileSync(indexPath, joinIndexPath);
console.log("Copied index.html → join/index.html for /join/* routes.");
