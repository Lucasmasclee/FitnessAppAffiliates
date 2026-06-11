(function () {
  "use strict";

  var STORAGE_KEY = "join_analytics_admin_key";

  function getConfig() {
    return window.AFFILIATE_CONFIG || {};
  }

  function statsUrl() {
    var base = (getConfig().supabaseUrl || "").replace(/\/+$/, "");
    if (!base) return "";
    return base + "/functions/v1/join-analytics-stats";
  }

  function el(id) {
    return document.getElementById(id);
  }

  function showError(msg) {
    var node = el("analytics-gate-error");
    if (!node) return;
    node.textContent = msg;
    node.hidden = !msg;
  }

  function renderStats(data) {
    el("stat-page-views").textContent = String(data.page_views_total ?? 0);
    el("stat-cta-clicks").textContent = String(data.cta_clicks_total ?? 0);
    el("stat-conversion").textContent = (data.conversion_rate ?? 0) + "%";

    var dailyBody = el("analytics-daily-table").querySelector("tbody");
    dailyBody.innerHTML = "";
    (data.daily || []).slice().reverse().forEach(function (row) {
      var tr = document.createElement("tr");
      tr.innerHTML =
        "<td>" + row.date + "</td>" +
        "<td>" + row.page_views + "</td>" +
        "<td>" + row.cta_clicks + "</td>";
      dailyBody.appendChild(tr);
    });

    var codeBody = el("analytics-code-table").querySelector("tbody");
    codeBody.innerHTML = "";
    (data.by_code || []).forEach(function (row) {
      var tr = document.createElement("tr");
      tr.innerHTML =
        "<td><code>" + row.affiliate_code + "</code></td>" +
        "<td>" + row.page_views + "</td>" +
        "<td>" + row.cta_clicks + "</td>" +
        "<td>" + row.conversion_rate + "%</td>";
      codeBody.appendChild(tr);
    });
  }

  function loadStats(key) {
    var url = statsUrl();
    if (!url) {
      showError("Missing Supabase config (js/config.js).");
      return Promise.reject();
    }

    return fetch(url, {
      headers: { "x-analytics-key": key },
    })
      .then(function (res) {
        if (!res.ok) throw new Error(res.status === 401 ? "Invalid analytics key." : "Failed to load stats.");
        return res.json();
      })
      .then(function (data) {
        renderStats(data);
        el("analytics-gate").hidden = true;
        el("analytics-content").hidden = false;
        showError("");
      });
  }

  function init() {
    var submitBtn = el("analytics-key-submit");
    var input = el("analytics-key-input");
    var logoutBtn = el("analytics-logout");
    var refreshBtn = el("analytics-refresh");

    function tryKey(key) {
      if (!key) {
        showError("Enter your analytics key.");
        return;
      }
      loadStats(key).catch(function (err) {
        showError(err.message || "Could not load stats.");
      });
    }

    submitBtn.addEventListener("click", function () {
      var key = (input.value || "").trim();
      try {
        sessionStorage.setItem(STORAGE_KEY, key);
      } catch (_e) { /* ignore */ }
      tryKey(key);
    });

    input.addEventListener("keydown", function (e) {
      if (e.key === "Enter") submitBtn.click();
    });

    logoutBtn.addEventListener("click", function () {
      try {
        sessionStorage.removeItem(STORAGE_KEY);
      } catch (_e) { /* ignore */ }
      input.value = "";
      el("analytics-gate").hidden = false;
      el("analytics-content").hidden = true;
      showError("");
    });

    refreshBtn.addEventListener("click", function () {
      var key = "";
      try {
        key = sessionStorage.getItem(STORAGE_KEY) || "";
      } catch (_e) { /* ignore */ }
      if (!key) key = (input.value || "").trim();
      tryKey(key);
    });

    var saved = "";
    try {
      saved = sessionStorage.getItem(STORAGE_KEY) || "";
    } catch (_e) { /* ignore */ }
    if (saved) {
      input.value = saved;
      tryKey(saved);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
