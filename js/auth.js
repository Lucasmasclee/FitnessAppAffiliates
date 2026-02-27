(function () {
  if (typeof window.AFFILIATE_CONFIG === "undefined" || !window.AFFILIATE_CONFIG.supabaseUrl) {
    window.__affiliateAuthReady = true;
    window.__affiliateUser = null;
    return;
  }

  var supabaseClient = window.supabase.createClient(
    window.AFFILIATE_CONFIG.supabaseUrl,
    window.AFFILIATE_CONFIG.supabaseAnonKey
  );

  window.__affiliateSupabase = supabaseClient;
  window.__affiliateUser = null;
  window.__affiliateAuthReady = false;

  supabaseClient.auth.getSession().then(function (result) {
    window.__affiliateUser = result.data.session?.user ?? null;
    window.__affiliateAuthReady = true;
    if (window.__affiliateAuthListener) window.__affiliateAuthListener(window.__affiliateUser);
  });

  if (typeof window !== "undefined" && window.location && window.location.hash && window.location.hash.indexOf("access_token") !== -1) {
    setTimeout(function () {
      supabaseClient.auth.getSession().then(function (result) {
        var user = result.data.session?.user ?? null;
        if (user) {
          window.__affiliateUser = user;
          if (window.__affiliateAuthListener) window.__affiliateAuthListener(user);
        }
      });
    }, 100);
  }

  supabaseClient.auth.onAuthStateChange(function (event, session) {
    window.__affiliateUser = session?.user ?? null;
    if (window.__affiliateAuthListener) window.__affiliateAuthListener(window.__affiliateUser);
  });

  window.affiliateAuth = {
    get user() {
      return window.__affiliateUser;
    },
    get ready() {
      return window.__affiliateAuthReady;
    },
    onReady: function (fn) {
      if (window.__affiliateAuthReady) {
        fn(window.__affiliateUser);
        return;
      }
      var check = setInterval(function () {
        if (window.__affiliateAuthReady) {
          clearInterval(check);
          fn(window.__affiliateUser);
        }
      }, 50);
    },
    onAuthChange: function (fn) {
      window.__affiliateAuthListener = fn;
      if (window.__affiliateAuthReady) fn(window.__affiliateUser);
    },
    signInWithGoogle: function (redirectTo) {
      var next =
        redirectTo ||
        (window.location.pathname + window.location.search + window.location.hash);
      var callbackUrl =
        window.location.origin +
        "/auth-callback.html?next=" +
        encodeURIComponent(next);
      return supabaseClient.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: callbackUrl },
      });
    },
    signInWithGooglePopup: function () {
      var self = this;
      return new Promise(function (resolve, reject) {
        var next =
          window.location.pathname +
          window.location.search +
          window.location.hash;
        var redirectTo =
          window.location.origin +
          "/auth-callback.html?next=" +
          encodeURIComponent(next);
        supabaseClient.auth.signInWithOAuth({
          provider: "google",
          options: { redirectTo: redirectTo },
        }).then(function (result) {
          if (result.error) {
            if (typeof window.affiliateDebugLog === "function") window.affiliateDebugLog("OAuth error", result.error);
            reject(result.error);
            return;
          }
          if (!result.data || !result.data.url) {
            var err = new Error("No URL");
            if (typeof window.affiliateDebugLog === "function") window.affiliateDebugLog("OAuth", err);
            reject(err);
            return;
          }
          var popup = window.open(result.data.url, "supabase-oauth", "width=500,height=600,scrollbars=yes");
          if (!popup) {
            var err = new Error("Popup blocked. Allow popups for this site and try again.");
            if (typeof window.affiliateDebugLog === "function") window.affiliateDebugLog("Popup", err);
            reject(err);
            return;
          }
          window.__affiliateAuthFinishCalled = false;
          function finish() {
            if (window.__affiliateAuthFinishCalled) return;
            window.__affiliateAuthFinishCalled = true;
            clearInterval(interval);
            window.removeEventListener("message", onMessage);
            try { localStorage.removeItem("affiliate-auth-done"); } catch (e) {}
            function tryResolve(attempt) {
              supabaseClient.auth.getSession().then(function (r) {
                var user = r.data.session?.user ?? null;
                if (user) {
                  window.__affiliateUser = user;
                  if (typeof console !== "undefined" && console.log) {
                    console.log("[Auth] Popup closed, session: user " + (user.email || user.id));
                  }
                  if (window.__affiliateAuthListener) window.__affiliateAuthListener(user);
                  resolve(user);
                  return;
                }
                if (attempt < 12) {
                  setTimeout(function () { tryResolve(attempt + 1); }, 250);
                } else {
                  if (typeof window.affiliateDebugLog === "function") window.affiliateDebugLog("Auth", "No session after popup (session not in localStorage?)");
                  if (window.__affiliateAuthListener) window.__affiliateAuthListener(null);
                  resolve(null);
                }
              });
            }
            setTimeout(function () { tryResolve(0); }, 200);
          }
          var onMessage = function (e) {
            if (e.data !== "supabase-auth-done" || e.origin !== window.location.origin) return;
            finish();
          };
          var interval = setInterval(function () {
            if (popup.closed) {
              finish();
              return;
            }
            try {
              var t = localStorage.getItem("affiliate-auth-done");
              if (t && Date.now() - parseInt(t, 10) < 15000) finish();
            } catch (e) {}
          }, 200);
          window.addEventListener("message", onMessage);
        }).catch(function (err) {
          if (typeof window.affiliateDebugLog === "function") window.affiliateDebugLog("Auth promise", err);
          reject(err);
        });
      });
    },
    signOut: function () {
      return supabaseClient.auth.signOut();
    },
    getSession: function () {
      return supabaseClient.auth.getSession();
    },
    refreshSession: function () {
      return supabaseClient.auth.refreshSession();
    },
  };
})();
