import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Platform = "ios" | "android" | "other";

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

function pickTargetUrl(platform: Platform, code: string): string {
  const appsflyerBase = (Deno.env.get("APPSFLYER_ONELINK_URL") || "").replace(/\?.*$/, "").replace(/\/$/, "");
  if (appsflyerBase && code) {
    return `${appsflyerBase}?af_sub1=${encodeURIComponent(code)}`;
  }

  const appStoreUrl = Deno.env.get("APPSTORE_URL") || "";
  const playStoreUrl = Deno.env.get("PLAYSTORE_URL") || "";
  const fallback =
    Deno.env.get("AFFILIATE_REDIRECT_FALLBACK") ||
    appStoreUrl ||
    playStoreUrl ||
    "https://liftbetter.cloud/";

  if (platform === "android" && playStoreUrl) {
    const referrer = encodeURIComponent(`affiliate_code=${code}`);
    const sep = playStoreUrl.includes("?") ? "&" : "?";
    return `${playStoreUrl}${sep}referrer=${referrer}`;
  }
  if (platform === "ios" && appStoreUrl) return appStoreUrl;
  return fallback;
}

Deno.serve(async (req) => {
  if (req.method !== "GET" && req.method !== "HEAD") {
    return new Response("Method not allowed", { status: 405 });
  }

  const url = new URL(req.url);
  const code = (url.searchParams.get("code") || "").trim();
  const platform = detectPlatform(req);
  const targetUrl = pickTargetUrl(platform, code || "");

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
      .select("id")
      .eq("affiliate_code", code)
      .single();

    if (affError || !affiliate) {
      if (affError) {
        console.error("affiliate-redirect: affiliate lookup error:", affError.message);
      }
      return Response.redirect(targetUrl, 302);
    }

    const { data: stats, error: statsError } = await supabase
      .from("affiliate_stats")
      .select("clicks, clicks_ios, clicks_android")
      .eq("affiliate_id", affiliate.id)
      .single();

    if (statsError && statsError.code !== "PGRST116") {
      // PGRST116 = no rows found; treat as zero clicks
      console.error("affiliate-redirect: stats lookup error:", statsError.message);
    }

    const incIos = platform === "ios" ? 1 : 0;
    const incAndroid = platform === "android" ? 1 : 0;

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
      const currentTotal = Number((stats as any).clicks ?? 0);
      const currentIos = Number((stats as any).clicks_ios ?? 0);
      const currentAndroid = Number((stats as any).clicks_android ?? 0);

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

    // Bewaar ook een event-row voor tijdsanalyses in het dashboard
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
