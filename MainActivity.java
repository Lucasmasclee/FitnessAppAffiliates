package com.example.app;

import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;
import android.os.Bundle;
import androidx.appcompat.app.AppCompatActivity;

public class MainActivity extends AppCompatActivity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Haal de referrer op (bevat de tracking code)
        String referrer = getReferrerFromIntent();
        if (referrer != null && !referrer.isEmpty()) {
            // Extraheer de tracking code
            String trackingCode = extractTrackingCode(referrer);
            
            // Sla de tracking code op in SharedPreferences
            SharedPreferences sharedPrefs = getSharedPreferences("app_prefs", Context.MODE_PRIVATE);
            SharedPreferences.Editor editor = sharedPrefs.edit();
            editor.putString("tracking_code", trackingCode);
            editor.apply();
        }
    }

    private String getReferrerFromIntent() {
        Intent intent = getIntent();
        Uri data = intent.getData();
        
        if (data != null) {
            return data.getQueryParameter("referrer");
        }
        return null;
    }

    private String extractTrackingCode(String referrer) {
        // Voorbeeld: "tracking_code=abc123"
        if (referrer.contains("tracking_code=")) {
            return referrer.split("tracking_code=")[1];
        }
        return "";
    }
} 