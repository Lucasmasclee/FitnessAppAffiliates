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

  const { error } = await supabase.from("join_page_events").insert({
    event_type: eventType,
    affiliate_code: normalizeCode(body.affiliate_code),
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

  return new Response(JSON.stringify({ success: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
