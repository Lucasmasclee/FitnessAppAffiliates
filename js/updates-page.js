(function () {
  var container = document.getElementById("updates-list");
  var statusEl = document.getElementById("updates-status");
  if (!container) return;

  function formatDate(dateStr) {
    if (!dateStr) return "";
    try {
      var d = new Date(dateStr + "T12:00:00");
      return d.toLocaleDateString(undefined, {
        year: "numeric",
        month: "long",
        day: "numeric",
      });
    } catch (e) {
      return dateStr;
    }
  }

  function showStatus(msg) {
    if (statusEl) statusEl.textContent = msg;
  }

  function renderUpdates(rows) {
    container.innerHTML = "";
    if (!rows || rows.length === 0) {
      showStatus("No updates yet. Check back soon.");
      return;
    }
    showStatus("");

    rows.forEach(function (row) {
      var section = document.createElement("article");
      section.className = "update-entry card";

      var title = document.createElement("h2");
      title.className = "update-entry-title";
      title.textContent = row.title || "";

      var dateEl = document.createElement("time");
      dateEl.className = "update-entry-date";
      dateEl.dateTime = row.date || "";
      dateEl.textContent = formatDate(row.date);

      var explanation = document.createElement("p");
      explanation.className = "update-entry-explanation";
      explanation.textContent = row.explanation || "";

      section.appendChild(title);
      section.appendChild(dateEl);
      section.appendChild(explanation);
      container.appendChild(section);
    });
  }

  function load() {
    if (
      typeof window.AFFILIATE_CONFIG === "undefined" ||
      !window.AFFILIATE_CONFIG.supabaseUrl ||
      !window.supabase
    ) {
      showStatus("Unable to load updates.");
      return;
    }

    var client = window.supabase.createClient(
      window.AFFILIATE_CONFIG.supabaseUrl,
      window.AFFILIATE_CONFIG.supabaseAnonKey
    );

    client
      .from("app_updates_for_website")
      .select("title, date, explanation")
      .order("date", { ascending: false })
      .then(function (result) {
        if (result.error) {
          showStatus("Could not load updates.");
          console.error(result.error);
          return;
        }
        renderUpdates(result.data);
      });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", load);
  } else {
    load();
  }
})();
