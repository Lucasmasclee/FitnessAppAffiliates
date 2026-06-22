;(function () {
  function normalizePath(path) {
    var p = (path || "/").replace(/\/+$/, "") || "/";
    if (p.endsWith("/index.html")) {
      p = p.slice(0, -"/index.html".length) || "/";
    }
    return p;
  }

  function getAffiliateKey(path) {
    if (path === "/affiliate-program" || path === "/affiliate-program.html") return "home";
    if (path.indexOf("/become-affiliate") === 0) return "become";
    if (path.indexOf("/affiliate") === 0) return "dashboard";
    if (path.indexOf("/creator-kit") === 0) return "creator-kit";
    if (path.indexOf("/terms") === 0) return "terms";
    return null;
  }

  function applyActiveStates() {
    var path = normalizePath(location.pathname);
    var liftBetterLink = document.querySelector('[data-nav-id="liftbetter"]');
    var affiliateTrigger = document.querySelector('[data-nav-id="affiliate"]');
    var affiliateKey = getAffiliateKey(path);

    document.querySelectorAll(".nav-top-link.active").forEach(function (el) {
      el.classList.remove("active");
    });
    document.querySelectorAll(".nav-submenu-link.active").forEach(function (el) {
      el.classList.remove("active");
    });

    if (path === "/" || path.indexOf("/join") === 0) {
      if (liftBetterLink) liftBetterLink.classList.add("active");
      return;
    }

    if (affiliateKey && affiliateTrigger) {
      affiliateTrigger.classList.add("active");
      var subLink = document.querySelector('[data-nav-affiliate="' + affiliateKey + '"]');
      if (subLink) subLink.classList.add("active");
      return;
    }
  }

  function initNavMenu() {
    var toggle = document.querySelector(".nav-menu-toggle");
    var menu = document.getElementById("nav-menu");
    var dropdown = document.querySelector(".nav-item-dropdown");
    var dropdownTrigger = dropdown ? dropdown.querySelector(".nav-dropdown-trigger") : null;
    var dropdownPanel = document.getElementById("nav-affiliate-submenu");

    applyActiveStates();

    function openMobileMenu() {
      if (!menu || !toggle) return;
      menu.hidden = false;
      menu.classList.add("nav-menu-open");
      toggle.setAttribute("aria-expanded", "true");
    }

    function closeMobileMenu() {
      if (!menu || !toggle) return;
      menu.hidden = true;
      menu.classList.remove("nav-menu-open");
      toggle.setAttribute("aria-expanded", "false");
      closeDropdown();
    }

    function isMobileMenuOpen() {
      return menu && !menu.hidden;
    }

    function openDropdown() {
      if (!dropdown || !dropdownTrigger || !dropdownPanel) return;
      dropdown.classList.add("nav-dropdown-open");
      dropdownTrigger.setAttribute("aria-expanded", "true");
      dropdownPanel.hidden = false;
    }

    function closeDropdown() {
      if (!dropdown || !dropdownTrigger || !dropdownPanel) return;
      dropdown.classList.remove("nav-dropdown-open");
      dropdownTrigger.setAttribute("aria-expanded", "false");
      dropdownPanel.hidden = true;
    }

    function isDropdownOpen() {
      return dropdown && dropdown.classList.contains("nav-dropdown-open");
    }

    if (toggle && menu) {
      toggle.addEventListener("click", function () {
        if (isMobileMenuOpen()) {
          closeMobileMenu();
        } else {
          openMobileMenu();
        }
      });
    }

    if (dropdownTrigger && dropdownPanel) {
      dropdownTrigger.addEventListener("click", function (e) {
        e.stopPropagation();
        if (isDropdownOpen()) {
          closeDropdown();
        } else {
          openDropdown();
        }
      });

      dropdown.addEventListener("mouseenter", function () {
        if (window.matchMedia("(min-width: 880px)").matches) {
          openDropdown();
        }
      });

      dropdown.addEventListener("mouseleave", function () {
        if (window.matchMedia("(min-width: 880px)").matches) {
          closeDropdown();
        }
      });
    }

    document.addEventListener("click", function (e) {
      if (isMobileMenuOpen() && menu && toggle) {
        if (e.target === toggle || toggle.contains(e.target)) return;
        if (menu.contains(e.target)) return;
        closeMobileMenu();
      }

      if (isDropdownOpen() && dropdown && !dropdown.contains(e.target)) {
        closeDropdown();
      }
    });

    document.addEventListener("keydown", function (e) {
      if (e.key !== "Escape" && e.key !== "Esc") return;
      if (isMobileMenuOpen()) {
        closeMobileMenu();
        if (toggle) toggle.focus();
      }
      if (isDropdownOpen()) {
        closeDropdown();
        if (dropdownTrigger) dropdownTrigger.focus();
      }
    });

    if (menu) {
      menu.addEventListener("click", function (e) {
        var el = e.target;
        if (
          el.matches &&
          (el.matches("a.nav-submenu-link") ||
            el.matches("a.nav-top-link") ||
            el.matches("button.nav-submenu-button"))
        ) {
          closeMobileMenu();
          closeDropdown();
        }
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initNavMenu);
  } else {
    initNavMenu();
  }
})();
