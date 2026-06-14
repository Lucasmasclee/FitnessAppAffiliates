(function () {
  "use strict";

  var CODE_PATTERN = /^[a-z0-9]{4,10}$/i;

  function getAffiliateCode() {
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
    var fromQuery = (new URLSearchParams(window.location.search).get("code") || "").trim();
    if (CODE_PATTERN.test(fromQuery)) {
      return fromQuery.toLowerCase();
    }
    return "";
  }

  function buildAffiliateLink(code) {
    var origin =
      (window.location && window.location.origin) || "https://liftbetter.cloud";
    if (code) {
      return origin + "/" + encodeURIComponent(code);
    }
    return origin + "/join";
  }

  function applyAffiliateLinks(code) {
    var affiliateLink = buildAffiliateLink(code);
    var ctaSelector = "[data-join-cta], .join-cta-link, #join-appstore, #join-playstore";

    document.querySelectorAll(ctaSelector).forEach(function (link) {
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
    var code = getAffiliateCode();
    var displayCode = code ? code.toUpperCase() : "";

    trackPageView(code);
    applyAffiliateLinks(code);

    var codeText = document.getElementById("join-code-text");
    var codeRow = document.getElementById("join-code-row");
    var copyBtn = document.getElementById("join-copy-code");

    if (code && codeText && codeRow) {
      codeText.textContent = displayCode;
      codeRow.hidden = false;
    }

    if (copyBtn && code) {
      copyBtn.hidden = false;
      copyBtn.addEventListener("click", function () {
        var value = code.toUpperCase();
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(value).then(function () {
            copyBtn.textContent = "Copied";
            setTimeout(function () {
              copyBtn.textContent = "Copy";
            }, 2000);
          });
        } else {
          window.prompt("Copy your code:", value);
        }
      });
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
