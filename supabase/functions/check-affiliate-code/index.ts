import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

const RESERVED_CODES = new Set([
  "admin",
  "support",
  "help",
  "api",
  "www",
  "app",
  "dashboard",
  "login",
  "signup",
  "subscribe",
  "pricing",
  "terms",
  "privacy",
  "liftbetter",
  "null",
  "undefined",
]);

function normalize(input: unknown): string {
  return String(input ?? "").trim().toLowerCase();
}

function validate(code: string): { ok: true } | { ok: false; error: string } {
  if (!code) return { ok: false, error: "Affiliate code is required" };
  if (code.length < 4 || code.length > 10) return { ok: false, error: "Code must be 4–10 characters" };
  if (!/^[a-z0-9]+$/.test(code)) return { ok: false, error: "Only letters and numbers allowed" };
  if (RESERVED_CODES.has(code)) return { ok: false, error: "This code is not allowed" };
  return { ok: true };
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

  let body: { affiliate_code?: string };
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const code = normalize(body.affiliate_code);
  const v = validate(code);
  if (!v.ok) {
    return new Response(JSON.stringify({ ok: false, error: v.error, available: false }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("check-affiliate-code: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ ok: false, error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  const { data, error } = await supabase
    .from("affiliates")
    .select("id")
    .eq("affiliate_code", code)
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error("check-affiliate-code: lookup error:", error.message);
    return new Response(JSON.stringify({ ok: false, error: "Server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (data?.id) {
    return new Response(JSON.stringify({ ok: true, available: false, error: "Code is already taken" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true, available: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});

