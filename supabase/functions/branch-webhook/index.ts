import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-webhook-secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

/** Branch webhook POST body (subset we use). */
interface BranchWebhookBody {
  name?: string;
  last_attributed_touch_data?: {
    "~alias"?: string;
    "+url"?: string;
    [k: string]: unknown;
  };
}

/** Extract Branch link alias from last_attributed_touch_data (e.g. join1). */
function getAliasFromTouchData(touch: BranchWebhookBody["last_attributed_touch_data"]): string | null {
  if (!touch || typeof touch !== "object") return null;
  const alias = touch["~alias"];
  if (alias && typeof alias === "string" && alias.trim()) return alias.trim();
  const url = touch["+url"];
  if (url && typeof url === "string") {
    try {
      const path = new URL(url).pathname.replace(/^\/+|\/+$/g, "");
      const segment = path.split("/").filter(Boolean).pop();
      if (segment) return segment;
    } catch {
      // ignore
    }
  }
  return null;
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

  const secret = Deno.env.get("BRANCH_WEBHOOK_SECRET");
  if (!secret) {
    console.error("BRANCH_WEBHOOK_SECRET not set");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const url = new URL(req.url);
  const provided = (req.headers.get("x-webhook-secret") ?? url.searchParams.get("secret") ?? "").trim();
  if (provided !== secret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: BranchWebhookBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (body?.name !== "click") {
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const alias = getAliasFromTouchData(body.last_attributed_touch_data);
  if (!alias) {
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const { error } = await supabase.rpc("increment_clicks_by_branch_alias", { p_alias: alias });
  if (error) {
    console.error("increment_clicks_by_branch_alias error:", error.message);
    return new Response(JSON.stringify({ error: "Failed to record click" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
