(function () {
  "use strict";

  var CODE_PATTERN = /^[a-z0-9]{4,10}$/i;

  function getJoinPathAffiliateCode() {
    var parts = window.location.pathname.replace(/\/+$/, "").split("/");
    var joinIdx = -1;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].toLowerCase() === "join") {
        joinIdx = i;
        break;
      }
    }
    if (joinIdx >= 0 && parts[joinIdx + 1]) {
      var fromPath = parts[joinIdx + 1].trim();
      if (fromPath.toLowerCase() !== "index.html" && CODE_PATTERN.test(fromPath)) {
        return fromPath.toLowerCase();
      }
    }
    return "";
  }

  function buildAffiliateLink(code) {
    var origin =
      (window.location && window.location.origin) || "https://liftbetter.cloud";
    return origin + "/" + encodeURIComponent(code);
  }

  function applyStoreAffiliateLinks(code) {
    var affiliateLink = buildAffiliateLink(code);
    var storeLinks = document.querySelectorAll(".join-mf-store");

    storeLinks.forEach(function (link) {
      link.href = affiliateLink;
      if (!link.dataset.joinCtaBound) {
        link.dataset.joinCtaBound = "1";
        link.addEventListener("click", function () {
          trackCtaClick(code);
        });
      }
    });
  }

  function trackPageView(code) {
    if (window.JoinAnalytics && window.JoinAnalytics.trackPageView) {
      window.JoinAnalytics.trackPageView(code || null);
    }
  }

  function trackCtaClick(code) {
    if (window.JoinAnalytics && window.JoinAnalytics.trackCtaClick) {
      window.JoinAnalytics.trackCtaClick(code || null);
    }
  }

  function init() {
    var code = getJoinPathAffiliateCode();
    var displayCode = code ? code.toUpperCase() : "";

    trackPageView(code);

    if (code && code !== "mrgrind") {
      applyStoreAffiliateLinks(code);

      var promoBanner = document.getElementById("join-promo-banner");
      var promoCode = document.getElementById("join-promo-code");
      if (promoBanner && promoCode) {
        promoCode.textContent = "'" + displayCode + "'";
        promoBanner.hidden = false;
      }
    }

    if (code) {
      document.title = "Lift Better – Personalized Training Plan (" + displayCode + ")";
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
