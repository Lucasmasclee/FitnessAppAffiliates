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

const config = `window.AFFILIATE_CONFIG = {
  supabaseUrl: ${JSON.stringify(supabaseUrl)},
  supabaseAnonKey: ${JSON.stringify(supabaseAnonKey)},
  appBaseUrl: ${JSON.stringify(appBaseUrl)},
};
`;

const outDir = path.join(__dirname, "..", "js");
const outPath = path.join(outDir, "config.js");
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(outPath, config, "utf8");
console.log("Wrote js/config.js from environment variables.");
