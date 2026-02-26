;(function () {
  function initNavMenu() {
    var toggle = document.querySelector(".nav-menu-toggle");
    var panel = document.getElementById("nav-menu");
    if (!toggle || !panel) return;

    function openMenu() {
      panel.hidden = false;
      panel.classList.add("nav-menu-open");
      toggle.setAttribute("aria-expanded", "true");
    }

    function closeMenu() {
      panel.hidden = true;
      panel.classList.remove("nav-menu-open");
      toggle.setAttribute("aria-expanded", "false");
    }

    function isOpen() {
      return !panel.hidden;
    }

    toggle.addEventListener("click", function () {
      if (isOpen()) {
        closeMenu();
      } else {
        openMenu();
      }
    });

    document.addEventListener("click", function (e) {
      if (!isOpen()) return;
      if (e.target === toggle || toggle.contains(e.target)) return;
      if (panel.contains(e.target)) return;
      closeMenu();
    });

    document.addEventListener("keydown", function (e) {
      if (!isOpen()) return;
      if (e.key === "Escape" || e.key === "Esc") {
        closeMenu();
        toggle.focus();
      }
    });

    // Close menu when a link inside is clicked (for single-page nav experience)
    panel.addEventListener("click", function (e) {
      var el = e.target;
      if (el.matches && (el.matches("a.nav-menu-link") || el.matches("button.nav-menu-link-button"))) {
        // Do not prevent default navigation, just close the menu
        closeMenu();
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initNavMenu);
  } else {
    initNavMenu();
  }
})();

