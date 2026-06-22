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

  function getOrigin() {
    return (window.location && window.location.origin) || "https://liftbetter.cloud";
  }

  function buildAffiliateLink(code) {
    return getOrigin() + "/" + encodeURIComponent(code);
  }

  function buildWebsiteLink() {
    return getOrigin() + "/website";
  }

  function applyStoreLinks(url, code) {
    var storeLinks = document.querySelectorAll(".join-mf-store");

    storeLinks.forEach(function (link) {
      link.href = url;
      if (!link.dataset.joinCtaBound) {
        link.dataset.joinCtaBound = "1";
        link.addEventListener("click", function () {
          trackCtaClick(code || null);
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
      applyStoreLinks(buildAffiliateLink(code), code);

      var promoBanner = document.getElementById("join-promo-banner");
      var promoCode = document.getElementById("join-promo-code");
      if (promoBanner && promoCode) {
        promoCode.textContent = "'" + displayCode + "'";
        promoBanner.hidden = false;
      }
    } else {
      applyStoreLinks(buildWebsiteLink(), null);
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
