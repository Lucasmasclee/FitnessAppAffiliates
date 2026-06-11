import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, apikey, authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

type EventType = "page_view" | "cta_click";

interface AnalyticsBody {
  event_type?: string;
  affiliate_code?: string;
  page_path?: string;
}

function normalizeCode(raw: string | undefined | null): string | null {
  const code = (raw || "").trim().toLowerCase();
  if (!code) return null;
  if (!/^[a-z0-9]{4,10}$/i.test(code)) return null;
  return code;
}

async function incrementLandingTotals(
  supabase: ReturnType<typeof createClient>,
  eventType: EventType,
) {
  const column = eventType === "page_view" ? "page_views" : "cta_clicks";

  const { data: row, error: readError } = await supabase
    .from("join_landing_totals")
    .select(column)
    .eq("id", 1)
    .single();

  if (readError && readError.code !== "PGRST116") {
    console.error("join-analytics: totals read error:", readError.message);
    return;
  }

  const current = Number((row as Record<string, unknown> | null)?.[column] ?? 0);

  const { error: writeError } = await supabase
    .from("join_landing_totals")
    .upsert({
      id: 1,
      [column]: current + 1,
      updated_at: new Date().toISOString(),
    });

  if (writeError) {
    console.error("join-analytics: totals write error:", writeError.message);
  }
}

async function incrementAffiliateJoinStats(
  supabase: ReturnType<typeof createClient>,
  affiliateCode: string,
  eventType: EventType,
) {
  const column = eventType === "page_view" ? "join_page_views" : "join_cta_clicks";

  const { data: affiliate, error: affError } = await supabase
    .from("affiliates")
    .select("id")
    .eq("affiliate_code", affiliateCode)
    .single();

  if (affError || !affiliate) return;

  const { data: stats, error: statsError } = await supabase
    .from("affiliate_stats")
    .select(column)
    .eq("affiliate_id", affiliate.id)
    .single();

  if (statsError && statsError.code !== "PGRST116") {
    console.error("join-analytics: affiliate stats read error:", statsError.message);
    return;
  }

  const current = Number((stats as Record<string, unknown> | null)?.[column] ?? 0);

  if (!stats) {
    const { error: insertError } = await supabase.from("affiliate_stats").insert({
      affiliate_id: affiliate.id,
      [column]: 1,
      updated_at: new Date().toISOString(),
    });
    if (insertError) {
      console.error("join-analytics: affiliate stats insert error:", insertError.message);
    }
    return;
  }

  const { error: updateError } = await supabase
    .from("affiliate_stats")
    .update({
      [column]: current + 1,
      updated_at: new Date().toISOString(),
    })
    .eq("affiliate_id", affiliate.id);

  if (updateError) {
    console.error("join-analytics: affiliate stats update error:", updateError.message);
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: AnalyticsBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const eventType = (body.event_type || "").trim() as EventType;
  if (eventType !== "page_view" && eventType !== "cta_click") {
    return new Response(JSON.stringify({ error: "Invalid event_type" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("join-analytics: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const affiliateCode = normalizeCode(body.affiliate_code);

  const { error } = await supabase.from("join_page_events").insert({
    event_type: eventType,
    affiliate_code: affiliateCode,
    page_path: (body.page_path || "").trim().slice(0, 500) || null,
    occurred_at: new Date().toISOString(),
  });

  if (error) {
    console.error("join-analytics: insert error:", error.message);
    return new Response(JSON.stringify({ error: "Failed to record event" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  await incrementLandingTotals(supabase, eventType);

  if (affiliateCode) {
    await incrementAffiliateJoinStats(supabase, affiliateCode, eventType);
  }

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
