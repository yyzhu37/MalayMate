package com.malaymate;

import android.content.Context;
import android.content.SharedPreferences;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.KeyStore;

import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

class MalayMateSettings {
    private static final String PREFS = "malaymate_settings";
    private static final String KEY_ALIAS = "MalayMateOpenAIKey";
    private final SharedPreferences prefs;

    MalayMateSettings(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    int dailyLimit() {
        return Math.max(0, Math.min(100, prefs.getInt("dailyNewWordLimit", 10)));
    }

    void setDailyLimit(int value) {
        prefs.edit().putInt("dailyNewWordLimit", Math.max(0, Math.min(100, value))).apply();
    }

    String modelName() {
        return prefs.getString("openaiModelName", "gpt-5.4-mini");
    }

    void setModelName(String modelName) {
        String trimmed = modelName == null ? "" : modelName.trim();
        prefs.edit().putString("openaiModelName", trimmed.isEmpty() ? "gpt-5.4-mini" : trimmed).apply();
    }

    boolean hasApiKey() {
        return prefs.contains("apiKeyCiphertext") && prefs.contains("apiKeyIv");
    }

    void saveApiKey(String apiKey) throws Exception {
        if (apiKey == null || apiKey.trim().isEmpty()) {
            throw new IllegalArgumentException("API key is required.");
        }
        SecretKey key = getOrCreateKey();
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] encrypted = cipher.doFinal(apiKey.trim().getBytes(StandardCharsets.UTF_8));
        prefs.edit()
                .putString("apiKeyCiphertext", Base64.encodeToString(encrypted, Base64.NO_WRAP))
                .putString("apiKeyIv", Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP))
                .apply();
    }

    String apiKey() throws Exception {
        if (!hasApiKey()) return null;
        try {
            SecretKey key = getOrCreateKey();
            byte[] encrypted = Base64.decode(prefs.getString("apiKeyCiphertext", ""), Base64.NO_WRAP);
            byte[] iv = Base64.decode(prefs.getString("apiKeyIv", ""), Base64.NO_WRAP);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE, key, new GCMParameterSpec(128, iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (Exception error) {
            clearApiKey();
            throw error;
        }
    }

    void clearApiKey() {
        prefs.edit().remove("apiKeyCiphertext").remove("apiKeyIv").apply();
    }

    private SecretKey getOrCreateKey() throws Exception {
        KeyStore keyStore = KeyStore.getInstance("AndroidKeyStore");
        keyStore.load(null);
        KeyStore.Entry entry = keyStore.getEntry(KEY_ALIAS, null);
        if (entry instanceof KeyStore.SecretKeyEntry) {
            return ((KeyStore.SecretKeyEntry) entry).getSecretKey();
        }
        KeyGenerator generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore");
        generator.init(new KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT
        )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build());
        return generator.generateKey();
    }
}
