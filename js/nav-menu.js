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

  function getContactKey(path) {
    if (path.indexOf("/progress-guarantee") === 0 || path.indexOf("/90-day-progress-guarantee") === 0) return "guarantee";
    if (path === "/contact" || path.indexOf("/contact.html") === 0) return "contact";
    return null;
  }

  function applyActiveStates() {
    var path = normalizePath(location.pathname);
    var liftBetterLink = document.querySelector('[data-nav-id="liftbetter"]');
    var affiliateTrigger = document.querySelector('[data-nav-id="affiliate"]');
    var contactTrigger = document.querySelector('[data-nav-id="contact"]');
    var affiliateKey = getAffiliateKey(path);
    var contactKey = getContactKey(path);

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
      var affiliateSubLink = document.querySelector('[data-nav-affiliate="' + affiliateKey + '"]');
      if (affiliateSubLink) affiliateSubLink.classList.add("active");
      return;
    }

    if (contactKey && contactTrigger) {
      contactTrigger.classList.add("active");
      var contactSubLink = document.querySelector('[data-nav-contact="' + contactKey + '"]');
      if (contactSubLink) contactSubLink.classList.add("active");
    }
  }

  function initNavMenu() {
    var toggle = document.querySelector(".nav-menu-toggle");
    var menu = document.getElementById("nav-menu");
    var dropdowns = Array.prototype.slice.call(document.querySelectorAll(".nav-item-dropdown"));

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
      closeAllDropdowns();
    }

    function isMobileMenuOpen() {
      return menu && !menu.hidden;
    }

    function openDropdown(dropdown) {
      if (!dropdown) return;
      var trigger = dropdown.querySelector(".nav-dropdown-trigger");
      var panel = dropdown.querySelector(".nav-submenu");
      if (!trigger || !panel) return;
      dropdown.classList.add("nav-dropdown-open");
      trigger.setAttribute("aria-expanded", "true");
      panel.hidden = false;
    }

    function closeDropdown(dropdown) {
      if (!dropdown) return;
      var trigger = dropdown.querySelector(".nav-dropdown-trigger");
      var panel = dropdown.querySelector(".nav-submenu");
      if (!trigger || !panel) return;
      dropdown.classList.remove("nav-dropdown-open");
      trigger.setAttribute("aria-expanded", "false");
      panel.hidden = true;
    }

    function closeAllDropdowns() {
      dropdowns.forEach(closeDropdown);
    }

    function isAnyDropdownOpen() {
      return dropdowns.some(function (dropdown) {
        return dropdown.classList.contains("nav-dropdown-open");
      });
    }

    function getOpenDropdown() {
      return dropdowns.find(function (dropdown) {
        return dropdown.classList.contains("nav-dropdown-open");
      });
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

    dropdowns.forEach(function (dropdown) {
      var trigger = dropdown.querySelector(".nav-dropdown-trigger");
      var panel = dropdown.querySelector(".nav-submenu");
      if (!trigger || !panel) return;

      trigger.addEventListener("click", function (e) {
        e.stopPropagation();
        var isOpen = dropdown.classList.contains("nav-dropdown-open");
        closeAllDropdowns();
        if (!isOpen) {
          openDropdown(dropdown);
        }
      });

      dropdown.addEventListener("mouseenter", function () {
        if (window.matchMedia("(min-width: 880px)").matches) {
          closeAllDropdowns();
          openDropdown(dropdown);
        }
      });

      dropdown.addEventListener("mouseleave", function () {
        if (window.matchMedia("(min-width: 880px)").matches) {
          closeDropdown(dropdown);
        }
      });
    });

    document.addEventListener("click", function (e) {
      if (isMobileMenuOpen() && menu && toggle) {
        if (e.target === toggle || toggle.contains(e.target)) return;
        if (menu.contains(e.target)) return;
        closeMobileMenu();
      }

      if (isAnyDropdownOpen()) {
        var openDropdownEl = getOpenDropdown();
        if (openDropdownEl && !openDropdownEl.contains(e.target)) {
          closeAllDropdowns();
        }
      }
    });

    document.addEventListener("keydown", function (e) {
      if (e.key !== "Escape" && e.key !== "Esc") return;
      if (isMobileMenuOpen()) {
        closeMobileMenu();
        if (toggle) toggle.focus();
      }
      if (isAnyDropdownOpen()) {
        var openDropdownEl = getOpenDropdown();
        closeAllDropdowns();
        if (openDropdownEl) {
          var openTrigger = openDropdownEl.querySelector(".nav-dropdown-trigger");
          if (openTrigger) openTrigger.focus();
        }
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
          closeAllDropdowns();
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
