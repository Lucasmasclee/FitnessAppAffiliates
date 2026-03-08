;(function () {
  function initNavAuth() {
    var loginBtn = document.querySelector("[data-nav-login]");
    var logoutBtn = document.querySelector("[data-nav-logout]");
    var emailEl = document.querySelector("[data-nav-email]");

    if (!loginBtn && !logoutBtn) return;

    function setState(user) {
      if (!window.affiliateAuth || !window.affiliateAuth.ready) {
        if (loginBtn) loginBtn.style.display = "none";
        if (logoutBtn) logoutBtn.style.display = "none";
        if (emailEl) {
          emailEl.textContent = "";
          emailEl.style.display = "none";
        }
        return;
      }

      if (user) {
        if (loginBtn) loginBtn.style.display = "none";
        if (logoutBtn) logoutBtn.style.display = "inline-flex";
        if (emailEl) {
          emailEl.textContent = user.email || "";
          emailEl.style.display = user.email ? "inline-flex" : "none";
        }
      } else {
        if (loginBtn) {
          loginBtn.style.display = "inline-flex";
          loginBtn.disabled = false;
        }
        if (logoutBtn) {
          logoutBtn.style.display = "none";
          logoutBtn.disabled = false;
        }
        if (emailEl) {
          emailEl.textContent = "";
          emailEl.style.display = "none";
        }
      }
    }

    if (loginBtn) {
      loginBtn.addEventListener("click", function (e) {
        e.preventDefault();
        if (!window.affiliateAuth || !window.affiliateAuth.signInWithGooglePopup) return;
        loginBtn.disabled = true;
        window.affiliateAuth
          .signInWithGooglePopup()
          .catch(function (err) {
            if (typeof alert === "function") {
              alert(
                (err && (err.message || err.error_description || err.error)) ||
                  "Sign-in failed. Try again."
              );
            }
          })
          .finally(function () {
            loginBtn.disabled = false;
          });
      });
    }

    if (logoutBtn) {
      logoutBtn.addEventListener("click", function (e) {
        e.preventDefault();
        if (!window.affiliateAuth || !window.affiliateAuth.signOut) return;
        logoutBtn.disabled = true;
        window.affiliateAuth
          .signOut()
          .then(function () {
            if (typeof location !== "undefined" && location.reload) {
              location.reload();
            }
          })
          .catch(function () {
            // keep UI consistent; session listener will clean up
          })
          .finally(function () {
            logoutBtn.disabled = false;
          });
      });
    }

    if (window.affiliateAuth && typeof window.affiliateAuth.onReady === "function") {
      window.affiliateAuth.onReady(function (user) {
        setState(user || null);
      });
    }

    if (window.affiliateAuth && typeof window.affiliateAuth.onAuthChange === "function") {
      window.affiliateAuth.onAuthChange(function (user) {
        setState(user || null);
      });
    }

    // Initial state before auth is ready or when auth is not configured
    try {
      var initialUser =
        window.affiliateAuth && typeof window.affiliateAuth.user !== "undefined"
          ? window.affiliateAuth.user
          : null;
      setState(initialUser || null);
    } catch (e) {
      setState(null);
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initNavAuth);
  } else {
    initNavAuth();
  }
})();

