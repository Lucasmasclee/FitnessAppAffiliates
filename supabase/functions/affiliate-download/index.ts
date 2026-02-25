import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

type Platform = "ios" | "android" | "other";

interface DownloadBody {
  affiliate_code?: string;
  platform?: string;
}

function normalizePlatform(raw: string | undefined | null): Platform {
  if (!raw) return "other";
  const v = String(raw).toLowerCase();
  if (v === "ios") return "ios";
  if (v === "android") return "android";
  return "other";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: DownloadBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const code = (body.affiliate_code || "").trim();
  if (!code) {
    return new Response(JSON.stringify({ error: "affiliate_code is required" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const platform = normalizePlatform(body.platform);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("affiliate-download: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const { data: affiliate, error: affError } = await supabase
    .from("affiliates")
    .select("id")
    .eq("affiliate_code", code)
    .single();

  if (affError || !affiliate) {
    if (affError) {
      console.error("affiliate-download: affiliate lookup error:", affError.message);
    }
    return new Response(JSON.stringify({ error: "Unknown affiliate_code" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { data: stats, error: statsError } = await supabase
    .from("affiliate_stats")
    .select("downloads, downloads_ios, downloads_android")
    .eq("affiliate_id", affiliate.id)
    .single();

  if (statsError && statsError.code !== "PGRST116") {
    // PGRST116 = no rows found; treat as zero
    console.error("affiliate-download: stats lookup error:", statsError.message);
  }

  const incIos = platform === "ios" ? 1 : 0;
  const incAndroid = platform === "android" ? 1 : 0;

  if (!stats) {
    const { error: insertError } = await supabase.from("affiliate_stats").insert({
      affiliate_id: affiliate.id,
      downloads: 1,
      downloads_ios: incIos,
      downloads_android: incAndroid,
      updated_at: new Date().toISOString(),
    });
    if (insertError) {
      console.error("affiliate-download: stats insert error:", insertError.message);
      return new Response(JSON.stringify({ error: "Failed to record download" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  } else {
    const currentTotal = Number((stats as any).downloads ?? 0);
    const currentIos = Number((stats as any).downloads_ios ?? 0);
    const currentAndroid = Number((stats as any).downloads_android ?? 0);

    const { error: updateError } = await supabase
      .from("affiliate_stats")
      .update({
        downloads: currentTotal + 1,
        downloads_ios: currentIos + incIos,
        downloads_android: currentAndroid + incAndroid,
        updated_at: new Date().toISOString(),
      })
      .eq("affiliate_id", affiliate.id);
    if (updateError) {
      console.error("affiliate-download: stats update error:", updateError.message);
      return new Response(JSON.stringify({ error: "Failed to record download" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*",
    },
  });
});

