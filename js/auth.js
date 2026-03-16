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

  function isInAppBrowserBlockedForGoogle() {
    try {
      if (typeof navigator === "undefined") return false;
      var ua = navigator.userAgent || "";
      // Common in-app browsers (Instagram, Facebook, TikTok, etc.) where Google blocks OAuth in embedded webviews
      return /Instagram|FBAN|FBAV|FB_IAB|FBIOS|Messenger|WhatsApp|TikTok|Twitter|Snapchat/i.test(
        ua
      );
    } catch (e) {
      return false;
    }
  }

  function buildCallbackUrl(redirectTo) {
    var next =
      redirectTo ||
      (window.location.pathname + window.location.search + window.location.hash);
    return (
      window.location.origin +
      "/auth-callback.html?next=" +
      encodeURIComponent(next)
    );
  }

  supabaseClient.auth.getSession().then(function (result) {
    window.__affiliateUser = result.data.session?.user ?? null;
    window.__affiliateAuthReady = true;
    if (window.__affiliateAuthListener) window.__affiliateAuthListener(window.__affiliateUser);
  });

  if (
    typeof window !== "undefined" &&
    window.location &&
    window.location.hash &&
    window.location.hash.indexOf("access_token") !== -1
  ) {
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
    get isInAppBrowser() {
      return isInAppBrowserBlockedForGoogle();
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

    // --- OAuth providers ---

    signInWithGoogle: function (redirectTo) {
      if (isInAppBrowserBlockedForGoogle()) {
        // Google blijft geblokkeerd in in-app browsers; UI vangt dit op.
        return Promise.reject(
          new Error(
            "Google sign-in is not available inside this in-app browser. Please use email, Apple, or open this page in your normal browser."
          )
        );
      }

      var callbackUrl = buildCallbackUrl(redirectTo);
      return supabaseClient.auth.signInWithOAuth({
        provider: "google",
        options: { redirectTo: callbackUrl },
      });
    },

    // Backwards-compatible alias: previously opened a popup; now just uses redirect-based flow.
    signInWithGooglePopup: function (redirectTo) {
      return this.signInWithGoogle(redirectTo);
    },

    signInWithApple: function (redirectTo) {
      var callbackUrl = buildCallbackUrl(redirectTo);
      return supabaseClient.auth.signInWithOAuth({
        provider: "apple",
        options: { redirectTo: callbackUrl },
      });
    },

    // --- Email flows ---

    signUpWithEmail: function (email, password) {
      return supabaseClient.auth.signUp({
        email: email,
        password: password,
      });
    },

    signInWithEmail: function (email, password) {
      return supabaseClient.auth.signInWithPassword({
        email: email,
        password: password,
      });
    },

    // Optional magic-link fallback (e.g. for embedded browsers)
    signInWithMagicLink: function (email, redirectTo) {
      var callbackUrl = buildCallbackUrl(redirectTo);
      return supabaseClient.auth.signInWithOtp({
        email: email,
        options: {
          emailRedirectTo: callbackUrl,
        },
      });
    },

    // --- Session helpers / logout ---

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
