(function () {
  "use strict";

  var SESSION_KEY = "join_analytics_page_view";

  function getConfig() {
    return window.AFFILIATE_CONFIG || {};
  }

  function analyticsUrl() {
    var base = (getConfig().supabaseUrl || "").replace(/\/+$/, "");
    if (!base) return "";
    return base + "/functions/v1/join-analytics";
  }

  function sendEvent(eventType, affiliateCode) {
    var url = analyticsUrl();
    if (!url) return;

    var cfg = getConfig();
    var payload = JSON.stringify({
      event_type: eventType,
      affiliate_code: affiliateCode || null,
      page_path: window.location.pathname + window.location.search,
    });

    var headers = { "Content-Type": "application/json" };
    if (cfg.supabaseAnonKey) {
      headers.apikey = cfg.supabaseAnonKey;
      headers.Authorization = "Bearer " + cfg.supabaseAnonKey;
    }

    fetch(url, {
      method: "POST",
      headers: headers,
      body: payload,
      keepalive: true,
    }).catch(function () {
      /* non-blocking */
    });
  }

  function trackPageView(affiliateCode) {
    try {
      if (sessionStorage.getItem(SESSION_KEY)) return;
      sessionStorage.setItem(SESSION_KEY, "1");
    } catch (_e) {
      /* private mode – still track */
    }
    sendEvent("page_view", affiliateCode);
  }

  function trackCtaClick(affiliateCode) {
    sendEvent("cta_click", affiliateCode);
  }

  window.JoinAnalytics = {
    trackPageView: trackPageView,
    trackCtaClick: trackCtaClick,
  };
})();
