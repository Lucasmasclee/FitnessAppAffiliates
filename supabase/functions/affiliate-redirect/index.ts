import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Platform = "ios" | "android" | "other";
type StorePlatform = "ios" | "android";

function detectPlatform(req: Request): Platform {
  const ua = (req.headers.get("user-agent") || "").toLowerCase();

  if (ua.includes("android")) return "android";
  if (
    ua.includes("iphone") ||
    ua.includes("ipad") ||
    ua.includes("ipod") ||
    ua.includes("ios")
  ) {
    return "ios";
  }
  return "other";
}

function parseStoreHint(raw: string | null): StorePlatform | null {
  const hint = (raw || "").trim().toLowerCase();
  if (hint === "ios" || hint === "apple" || hint === "appstore" || hint === "app") {
    return "ios";
  }
  if (hint === "android" || hint === "play" || hint === "google" || hint === "playstore") {
    return "android";
  }
  return null;
}

function pickDesktopStorePlatform(ua: string): StorePlatform {
  const lower = ua.toLowerCase();
  if (lower.includes("windows")) return "android";
  if (lower.includes("macintosh") || lower.includes("mac os")) return "ios";
  return "ios";
}

function resolveStorePlatform(
  platform: Platform,
  ua: string,
  storeHint: StorePlatform | null,
): StorePlatform {
  if (platform === "ios") return "ios";
  if (platform === "android") return "android";
  return storeHint || pickDesktopStorePlatform(ua);
}

function pickTargetUrl(
  storePlatform: StorePlatform,
  code: string,
  iosCppPpid?: string | null,
): string {
  const appStoreUrl = (Deno.env.get("APPSTORE_URL") || "").trim();
  const playStoreUrl = (Deno.env.get("PLAYSTORE_URL") || "").trim();
  const fallback =
    Deno.env.get("AFFILIATE_REDIRECT_FALLBACK") ||
    appStoreUrl ||
    playStoreUrl ||
    "https://liftbetter.cloud/";

  if (storePlatform === "android" && playStoreUrl) {
    const referrer = encodeURIComponent(`affiliate_code=${code}`);
    const sep = playStoreUrl.includes("?") ? "&" : "?";
    return `${playStoreUrl}${sep}referrer=${referrer}`;
  }

  if (storePlatform === "ios" && appStoreUrl) {
    if (iosCppPpid) {
      const sep = appStoreUrl.includes("?") ? "&" : "?";
      return `${appStoreUrl}${sep}ppid=${encodeURIComponent(iosCppPpid)}`;
    }
    return appStoreUrl;
  }

  return fallback;
}

function extractAffiliateCode(url: URL): string {
  const codeFromQuery = (url.searchParams.get("code") || "").trim();
  if (codeFromQuery) {
    return codeFromQuery.toLowerCase();
  }

  const pathSlug = url.pathname.replace(/^\/+|\/+$/g, "").split("/").pop() || "";
  if (/^[a-z0-9]{4,16}$/i.test(pathSlug)) {
    return pathSlug.toLowerCase();
  }

  return "";
}

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }

  const url = new URL(req.url);
  const ua = req.headers.get("user-agent") || "";
  const platform = detectPlatform(req);
  const storeHint = parseStoreHint(url.searchParams.get("store"));
  const storePlatform = resolveStorePlatform(platform, ua, storeHint);
  const code = extractAffiliateCode(url);

  let iosCppPpid: string | null = null;
  let targetUrl = pickTargetUrl(storePlatform, code || "", null);

  try {
    if (!code) {
      return Response.redirect(targetUrl, 302);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return Response.redirect(targetUrl, 302);
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { data: affiliate, error: affError } = await supabase
      .from("affiliates")
      .select("id, ios_cpp_ppid")
      .ilike("affiliate_code", code)
      .single();

    if (affError || !affiliate) {
      if (affError) {
        console.error("affiliate-redirect: affiliate lookup error:", affError.message);
      }
      return Response.redirect(targetUrl, 302);
    }

    iosCppPpid = typeof affiliate.ios_cpp_ppid === "string"
      ? affiliate.ios_cpp_ppid.trim()
      : null;
    targetUrl = pickTargetUrl(storePlatform, code, iosCppPpid);

    const { data: stats, error: statsError } = await supabase
      .from("affiliate_stats")
      .select("clicks, clicks_ios, clicks_android")
      .eq("affiliate_id", affiliate.id)
      .single();

    if (statsError && statsError.code !== "PGRST116") {
      console.error("affiliate-redirect: stats lookup error:", statsError.message);
    }

    const incIos = storePlatform === "ios" ? 1 : 0;
    const incAndroid = storePlatform === "android" ? 1 : 0;

    if (!stats) {
      const { error: insertError } = await supabase.from("affiliate_stats").insert({
        affiliate_id: affiliate.id,
        clicks: 1,
        clicks_ios: incIos,
        clicks_android: incAndroid,
        updated_at: new Date().toISOString(),
      });
      if (insertError) {
        console.error("affiliate-redirect: stats insert error:", insertError.message);
      }
    } else {
      const currentTotal = Number((stats as { clicks?: number }).clicks ?? 0);
      const currentIos = Number((stats as { clicks_ios?: number }).clicks_ios ?? 0);
      const currentAndroid = Number((stats as { clicks_android?: number }).clicks_android ?? 0);

      const { error: updateError } = await supabase
        .from("affiliate_stats")
        .update({
          clicks: currentTotal + 1,
          clicks_ios: currentIos + incIos,
          clicks_android: currentAndroid + incAndroid,
          updated_at: new Date().toISOString(),
        })
        .eq("affiliate_id", affiliate.id);

      if (updateError) {
        console.error("affiliate-redirect: stats update error:", updateError.message);
      }
    }

    try {
      await supabase.from("affiliate_click_events").insert({
        affiliate_id: affiliate.id,
        platform,
        occurred_at: new Date().toISOString(),
      });
    } catch (e) {
      console.error("affiliate-redirect: click_events insert error:", e);
    }
  } catch (e) {
    console.error("affiliate-redirect: unexpected error:", e);
  }

  return new Response(null, {
    status: 302,
    headers: {
      Location: targetUrl,
      "Cache-Control": "no-store, no-cache, must-revalidate, max-age=0",
      Pragma: "no-cache",
    },
  });
});
