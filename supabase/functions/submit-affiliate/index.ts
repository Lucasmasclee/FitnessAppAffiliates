import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function randomCode(): string {
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  let code = "";
  for (let i = 0; i < 10; i++) {
    code += chars[Math.floor(Math.random() * chars.length)];
  }
  return code;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  try {
    let body: {
      email?: string;
      phone?: string;
      social_media?: string;
      preferred_contact_method?: string;
      access_token?: string;
    };
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    let token: string | null =
      (req.headers.get("Authorization") || "").replace(/^Bearer\s+/i, "").trim() || null;
    if (!token && body.access_token && typeof body.access_token === "string") {
      token = body.access_token.trim();
      delete body.access_token;
    }
    if (!token) {
      return new Response(
        JSON.stringify({ error: "Missing authorization header or access_token" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !supabaseServiceKey) {
      console.error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
      return new Response(
        JSON.stringify({ error: "Server configuration error" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let userId: string;
    if (supabaseAnonKey) {
      const authClient = createClient(supabaseUrl, supabaseAnonKey);
      const { data: claimsData, error: claimsError } = await authClient.auth.getClaims(token);
      if (claimsError || !claimsData?.claims?.sub) {
        console.error("getClaims error:", claimsError?.message ?? "no sub in claims");
        return new Response(
          JSON.stringify({ error: "Invalid or expired session" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      userId = claimsData.claims.sub as string;
    } else {
      const authClient = createClient(supabaseUrl, supabaseServiceKey);
      const { data: { user }, error: authError } = await authClient.auth.getUser(token);
      if (authError || !user) {
        console.error("getUser error:", authError?.message ?? "no user");
        return new Response(
          JSON.stringify({ error: "Invalid or expired session" }),
          { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      userId = user.id;
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { email, phone, social_media, preferred_contact_method } = body ?? {};
    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let affiliateCode = randomCode();
    const maxAttempts = 5;
    for (let i = 0; i < maxAttempts; i++) {
      const { data: existing } = await supabase
        .from("affiliates")
        .select("id")
        .eq("affiliate_code", affiliateCode)
        .single();
      if (!existing) break;
      affiliateCode = randomCode();
    }

    const { data: affiliate, error: insertError } = await supabase
      .from("affiliates")
      .upsert(
        {
          user_id: userId,
          email: email ? String(email).trim() : null,
          // Keep phone column non-null even if optional in the UI
          phone: phone ? String(phone).trim() : "",
          social_media: social_media ? String(social_media).trim() : null,
          affiliate_code: affiliateCode,
          updated_at: new Date().toISOString(),
        },
        { onConflict: "user_id" }
      )
      .select("id")
      .single();

    if (insertError) {
      console.error("Insert affiliate error:", insertError);
      return new Response(
        JSON.stringify({ error: "Failed to save affiliate" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (!affiliate?.id) {
      console.error("Upsert succeeded but no affiliate id returned");
      return new Response(
        JSON.stringify({ error: "Failed to save affiliate" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { error: statsError } = await supabase.from("affiliate_stats").upsert(
      { affiliate_id: affiliate.id, updated_at: new Date().toISOString() },
      { onConflict: "affiliate_id" }
    );
    if (statsError) console.error("Stats insert error:", statsError);

    const toNumber = Deno.env.get("AFFILIATE_SMS_TO");
    const twilioSid = Deno.env.get("TWILIO_ACCOUNT_SID");
    const twilioToken = Deno.env.get("TWILIO_AUTH_TOKEN");
    const twilioFrom = Deno.env.get("TWILIO_PHONE_NUMBER");

    if (toNumber && twilioSid && twilioToken && twilioFrom) {
      const smsBody = `New affiliate. Email: ${email || "n/a"}, Phone: ${phone || "n/a"}, Social: ${social_media ? social_media : "n/a"}, Preferred contact method: ${preferred_contact_method || "n/a"}, Code: ${affiliateCode}`;
      const twilioUrl = `https://api.twilio.com/2010-04-01/Accounts/${twilioSid}/Messages.json`;
      const basicAuth = btoa(`${twilioSid}:${twilioToken}`);
      const form = new URLSearchParams({
        To: toNumber,
        From: twilioFrom,
        Body: smsBody,
      });

      const twilioRes = await fetch(twilioUrl, {
        method: "POST",
        headers: {
          "Authorization": `Basic ${basicAuth}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: form.toString(),
      });
      if (!twilioRes.ok) {
        const errText = await twilioRes.text();
        console.error("Twilio SMS error:", twilioRes.status, errText);
      }
    }

    return new Response(
      JSON.stringify({ success: true, affiliate_code: affiliateCode }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error(e);
    return new Response(
      JSON.stringify({ error: "Server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
