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
    // Backwards-compatible alias: previously opened a popup; now just uses redirect-based flow.
    signInWithGooglePopup: function () {
      return this.signInWithGoogle();
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
