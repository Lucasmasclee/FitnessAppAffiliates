import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

type SubscriptionType = "monthly" | "yearly";

interface SubscriptionBody {
  affiliate_code?: string;
  branch_link_alias?: string;
  subscription_type?: SubscriptionType;
  gross_amount?: number;
  commission_amount?: number;
  currency?: string;
  event_date?: string;
}

function computeCommission(
  subscriptionType: SubscriptionType,
  grossAmount: number | null | undefined,
  explicitCommission?: number
): number {
  if (typeof explicitCommission === "number" && !Number.isNaN(explicitCommission)) {
    return explicitCommission;
  }
  if (grossAmount == null || Number.isNaN(grossAmount)) {
    return 0;
  }
  const monthlyPct = 0.94;
  const yearlyPct = 0.39;
  const pct = subscriptionType === "monthly" ? monthlyPct : yearlyPct;
  return Math.round((grossAmount * pct) * 100) / 100;
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

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("affiliate-subscription: missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
    return new Response(JSON.stringify({ error: "Server configuration error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  let body: SubscriptionBody;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const affiliateCode = (body.affiliate_code || "").trim();
  const branchAlias = (body.branch_link_alias || "").trim();
  const subscriptionType = body.subscription_type;

  if (!affiliateCode && !branchAlias) {
    return new Response(JSON.stringify({ error: "affiliate_code or branch_link_alias is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (subscriptionType !== "monthly" && subscriptionType !== "yearly") {
    return new Response(JSON.stringify({ error: "subscription_type must be 'monthly' or 'yearly'" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  // Zoek juiste affiliate
  let affiliateId: string | null = null;
  try {
    let query = supabase
      .from("affiliates")
      .select("id")
      .limit(1);

    if (affiliateCode) {
      query = query.eq("affiliate_code", affiliateCode);
    } else {
      query = query.eq("branch_link_alias", branchAlias);
    }

    const { data: affiliate, error: affError } = await query.single();
    if (affError || !affiliate) {
      if (affError) {
        console.error("affiliate-subscription: affiliate lookup error:", affError.message);
      }
      return new Response(JSON.stringify({ error: "Unknown affiliate" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    affiliateId = (affiliate as any).id as string;
  } catch (e) {
    console.error("affiliate-subscription: unexpected error resolving affiliate:", e);
    return new Response(JSON.stringify({ error: "Failed to resolve affiliate" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const eventDate = body.event_date && !Number.isNaN(Date.parse(body.event_date))
    ? new Date(body.event_date)
    : new Date();

  const grossAmount =
    typeof body.gross_amount === "number" && !Number.isNaN(body.gross_amount)
      ? body.gross_amount
      : null;
  const commissionAmount = computeCommission(
    subscriptionType,
    grossAmount,
    body.commission_amount
  );

  // 60-dagen hold-periode vanaf eventDate
  const holdUntil = new Date(eventDate.getTime() + 60 * 24 * 60 * 60 * 1000);

  try {
    const { error: insertError } = await supabase
      .from("affiliate_transactions")
      .insert({
        affiliate_id: affiliateId,
        event_type: "subscription",
        subscription_type: subscriptionType,
        event_date: eventDate.toISOString(),
        gross_amount: grossAmount,
        commission_amount: commissionAmount,
        currency: (body.currency || "EUR").toUpperCase(),
        status: "pending",
        payout_status: "pending",
        hold_until: holdUntil.toISOString(),
      });

    if (insertError) {
      console.error("affiliate-subscription: insert transaction error:", insertError.message);
      return new Response(JSON.stringify({ error: "Failed to record subscription" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Houd aggregate counters in affiliate_stats in sync (voor backwards compatibility)
    const { data: stats, error: statsError } = await supabase
      .from("affiliate_stats")
      .select("monthly_subs, yearly_subs")
      .eq("affiliate_id", affiliateId)
      .single();

    if (statsError && statsError.code !== "PGRST116") {
      console.error("affiliate-subscription: stats lookup error:", statsError.message);
    }

    const isYearly = subscriptionType === "yearly";
    const currentMonthly = Number((stats as any)?.monthly_subs ?? 0);
    const currentYearly = Number((stats as any)?.yearly_subs ?? 0);

    if (!stats) {
      const { error: insertStatsError } = await supabase.from("affiliate_stats").insert({
        affiliate_id: affiliateId,
        monthly_subs: isYearly ? 0 : 1,
        yearly_subs: isYearly ? 1 : 0,
        updated_at: new Date().toISOString(),
      });
      if (insertStatsError) {
        console.error(
          "affiliate-subscription: stats insert error:",
          insertStatsError.message,
        );
      }
    } else {
      const { error: updateError } = await supabase
        .from("affiliate_stats")
        .update({
          monthly_subs: isYearly ? currentMonthly : currentMonthly + 1,
          yearly_subs: isYearly ? currentYearly + 1 : currentYearly,
          updated_at: new Date().toISOString(),
        })
        .eq("affiliate_id", affiliateId);
      if (updateError) {
        console.error("affiliate-subscription: stats update error:", updateError.message);
      }
    }
  } catch (e) {
    console.error("affiliate-subscription: unexpected error inserting transaction:", e);
    return new Response(JSON.stringify({ error: "Server error" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({
      success: true,
      affiliate_id: affiliateId,
      subscription_type: subscriptionType,
      commission_amount: commissionAmount,
    }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
});

