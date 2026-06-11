import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-analytics-key, apikey",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

type Row = {
  event_type: string;
  affiliate_code: string | null;
  occurred_at: string;
};

function dayKey(iso: string): string {
  return iso.slice(0, 10);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const adminKey = Deno.env.get("ANALYTICS_ADMIN_KEY") || "";
  const providedKey = req.headers.get("x-analytics-key") || "";

  if (!adminKey || providedKey !== adminKey) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const since30d = new Date();
  since30d.setDate(since30d.getDate() - 30);

  const { data, error } = await supabase
    .from("join_page_events")
    .select("event_type, affiliate_code, occurred_at")
    .gte("occurred_at", since30d.toISOString())
    .order("occurred_at", { ascending: false })
    .limit(50000);

  if (error) {
    console.error("join-analytics-stats: query error:", error.message);
    return new Response(JSON.stringify({ error: "Failed to load stats" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const rows = (data || []) as Row[];

  let pageViewsTotal = 0;
  let ctaClicksTotal = 0;
  const byCodeMap = new Map<string, { page_views: number; cta_clicks: number }>();
  const dailyMap = new Map<string, { page_views: number; cta_clicks: number }>();

  for (const row of rows) {
    const code = row.affiliate_code || "(no code)";
    if (!byCodeMap.has(code)) {
      byCodeMap.set(code, { page_views: 0, cta_clicks: 0 });
    }
    const codeStats = byCodeMap.get(code)!;

    const day = dayKey(row.occurred_at);
    if (!dailyMap.has(day)) {
      dailyMap.set(day, { page_views: 0, cta_clicks: 0 });
    }
    const dayStats = dailyMap.get(day)!;

    if (row.event_type === "page_view") {
      pageViewsTotal += 1;
      codeStats.page_views += 1;
      dayStats.page_views += 1;
    } else if (row.event_type === "cta_click") {
      ctaClicksTotal += 1;
      codeStats.cta_clicks += 1;
      dayStats.cta_clicks += 1;
    }
  }

  const byCode = Array.from(byCodeMap.entries())
    .map(([affiliate_code, stats]) => ({
      affiliate_code,
      page_views: stats.page_views,
      cta_clicks: stats.cta_clicks,
      conversion_rate: stats.page_views > 0
        ? Math.round((stats.cta_clicks / stats.page_views) * 1000) / 10
        : 0,
    }))
    .sort((a, b) => b.page_views - a.page_views);

  const last30Days = Array.from(dailyMap.entries())
    .map(([date, stats]) => ({
      date,
      page_views: stats.page_views,
      cta_clicks: stats.cta_clicks,
    }))
    .sort((a, b) => a.date.localeCompare(b.date));

  const conversionRate = pageViewsTotal > 0
    ? Math.round((ctaClicksTotal / pageViewsTotal) * 1000) / 10
    : 0;

  return new Response(
    JSON.stringify({
      page_views_total: pageViewsTotal,
      cta_clicks_total: ctaClicksTotal,
      conversion_rate: conversionRate,
      period_days: 30,
      by_code: byCode,
      daily: last30Days,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});
