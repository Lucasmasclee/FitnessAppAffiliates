(function () {
  "use strict";

  var CODE_PATTERN = /^[a-z0-9]{4,16}$/i;

  function getJoinPathAffiliateCode() {
    var parts = window.location.pathname.replace(/\/+$/, "").split("/");
    var joinIdx = -1;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].toLowerCase() === "join") {
        joinIdx = i;
        break;
      }
    }
    if (joinIdx < 0 || !parts[joinIdx + 1]) {
      return "";
    }

    var fromPath = parts[joinIdx + 1].trim();
    if (!fromPath || fromPath.toLowerCase() === "index.html") {
      return "";
    }

    var normalized = fromPath.toLowerCase().replace(/[^a-z0-9]/g, "");
    if (CODE_PATTERN.test(normalized)) {
      return normalized;
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

  function bindPromoCopyButton(code, displayCode) {
    var copyBtn = document.getElementById("join-promo-copy");
    if (!copyBtn || !code) return;

    copyBtn.hidden = false;
    copyBtn.addEventListener("click", function () {
      var value = displayCode;
      function showCopied() {
        copyBtn.textContent = "Copied";
        setTimeout(function () {
          copyBtn.textContent = "Copy";
        }, 2000);
      }

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(value).then(showCopied).catch(function () {
          window.prompt("Copy your code:", value);
        });
      } else {
        window.prompt("Copy your code:", value);
      }
    });
  }

  function initGuaranteeSheet() {
    var openBtn = document.getElementById("join-guarantee-open");
    var sheet = document.getElementById("join-guarantee-sheet");
    var backdrop = document.getElementById("join-guarantee-backdrop");
    var closeBtn = document.getElementById("join-guarantee-close");
    if (!openBtn || !sheet || !backdrop) return;

    function openSheet() {
      sheet.hidden = false;
      backdrop.hidden = false;
      requestAnimationFrame(function () {
        sheet.classList.add("join-guarantee-sheet-open");
        backdrop.classList.add("join-guarantee-backdrop-open");
      });
      document.body.classList.add("join-guarantee-sheet-active");
      if (closeBtn) closeBtn.focus();
    }

    function closeSheet() {
      sheet.classList.remove("join-guarantee-sheet-open");
      backdrop.classList.remove("join-guarantee-backdrop-open");
      document.body.classList.remove("join-guarantee-sheet-active");
      window.setTimeout(function () {
        sheet.hidden = true;
        backdrop.hidden = true;
      }, 320);
      openBtn.focus();
    }

    openBtn.addEventListener("click", openSheet);
    if (closeBtn) closeBtn.addEventListener("click", closeSheet);
    backdrop.addEventListener("click", closeSheet);
    document.addEventListener("keydown", function (e) {
      if ((e.key === "Escape" || e.key === "Esc") && !sheet.hidden) {
        closeSheet();
      }
    });
  }

  function init() {
    var code = getJoinPathAffiliateCode();
    var displayCode = code ? code.toUpperCase() : "";

    trackPageView(code);

    if (code) {
      applyStoreLinks(buildAffiliateLink(code), code);
    } else {
      applyStoreLinks(buildWebsiteLink(), null);
    }

    if (code && code !== "mrgrind") {
      var promoBanner = document.getElementById("join-promo-banner");
      var promoCode = document.getElementById("join-promo-code");
      if (promoBanner && promoCode) {
        promoCode.textContent = "'" + displayCode + "'";
        promoBanner.hidden = false;
        bindPromoCopyButton(code, displayCode);
      }
    }

    if (code === "mrgrind") {
      var giftsSection = document.getElementById("join-mrgrind-gifts");
      if (giftsSection) {
        giftsSection.hidden = false;
      }
    }

    initGuaranteeSheet();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
