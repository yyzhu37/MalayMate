package com.malaymate;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;

class OpenAIClient {
    AIEnrichment enrich(String apiKey, String model, String term, String userMeaning, String note) throws Exception {
        JSONObject body = new JSONObject();
        body.put("model", model);
        JSONArray input = new JSONArray();
        input.put(new JSONObject()
                .put("role", "system")
                .put("content", "Return strict JSON for a Malay vocabulary learning card for a Chinese-speaking learner. Keep Malay examples simple and natural."));
        input.put(new JSONObject()
                .put("role", "user")
                .put("content", "Malay term: " + term + "\nKnown Chinese meaning: " + userMeaning + "\nUser note: " + (note == null ? "" : note)));
        body.put("input", input);
        body.put("max_output_tokens", 800);
        body.put("text", new JSONObject().put("format", schema()));

        HttpURLConnection connection = (HttpURLConnection) new URL("https://api.openai.com/v1/responses").openConnection();
        try {
            connection.setConnectTimeout(15_000);
            connection.setReadTimeout(45_000);
            connection.setRequestMethod("POST");
            connection.setRequestProperty("Authorization", "Bearer " + apiKey);
            connection.setRequestProperty("Content-Type", "application/json");
            connection.setDoOutput(true);
            byte[] payload = body.toString().getBytes(StandardCharsets.UTF_8);
            connection.setFixedLengthStreamingMode(payload.length);
            try (OutputStream output = connection.getOutputStream()) {
                output.write(payload);
            }

            int code = connection.getResponseCode();
            InputStream inputStream = code >= 200 && code < 300 ? connection.getInputStream() : connection.getErrorStream();
            String response = readAll(inputStream);
            if (code < 200 || code >= 300) throw new IllegalStateException("OpenAI HTTP " + code + ": " + response);
            return parse(response);
        } finally {
            connection.disconnect();
        }
    }

    private AIEnrichment parse(String responseText) throws Exception {
        JSONObject response = new JSONObject(responseText);
        String outputText = response.optString("output_text", "");
        if (outputText.isEmpty()) {
            JSONArray output = response.optJSONArray("output");
            if (output != null) {
                for (int i = 0; i < output.length() && outputText.isEmpty(); i++) {
                    JSONArray content = output.getJSONObject(i).optJSONArray("content");
                    if (content == null) continue;
                    for (int j = 0; j < content.length(); j++) {
                        String text = content.getJSONObject(j).optString("text", "");
                        if (!text.isEmpty()) {
                            outputText = text;
                            break;
                        }
                    }
                }
            }
        }
        if (outputText.isEmpty()) throw new IllegalStateException("OpenAI response did not contain output text.");
        JSONObject payload = new JSONObject(outputText);
        AIEnrichment enrichment = new AIEnrichment();
        enrichment.chineseMeaning = payload.optString("chineseMeaning", "");
        enrichment.partOfSpeech = payload.optString("partOfSpeech", "unknown");
        enrichment.pronunciationNotes = payload.optString("pronunciationNotes", "");
        JSONArray syllables = payload.optJSONArray("syllables");
        enrichment.syllables = new ArrayList<>();
        if (syllables != null) for (int i = 0; i < syllables.length(); i++) enrichment.syllables.add(syllables.getString(i));
        JSONArray examples = payload.optJSONArray("examples");
        enrichment.examplesJson = examples == null ? "[]" : examples.toString();
        JSONArray prompts = payload.optJSONArray("practicePrompts");
        if (prompts != null) for (int i = 0; i < prompts.length(); i++) enrichment.practicePrompts.add(prompts.getString(i));
        return enrichment;
    }

    private JSONObject schema() throws Exception {
        JSONObject fields = new JSONObject()
                .put("chineseMeaning", new JSONObject().put("type", "string"))
                .put("partOfSpeech", new JSONObject().put("type", "string"))
                .put("pronunciationNotes", new JSONObject().put("type", "string"))
                .put("syllables", new JSONObject().put("type", "array").put("items", new JSONObject().put("type", "string")))
                .put("examples", new JSONObject().put("type", "array").put("items", new JSONObject()
                        .put("type", "object")
                        .put("additionalProperties", false)
                        .put("properties", new JSONObject()
                                .put("id", new JSONObject().put("type", "string"))
                                .put("malay", new JSONObject().put("type", "string"))
                                .put("chinese", new JSONObject().put("type", "string"))
                                .put("sourceRefs", new JSONObject().put("type", "array").put("items", new JSONObject()
                                        .put("type", "object")
                                        .put("additionalProperties", false)
                                        .put("properties", new JSONObject()
                                                .put("field", new JSONObject().put("type", "string"))
                                                .put("sourceName", new JSONObject().put("type", "string"))
                                                .put("sourceUrl", new JSONObject().put("type", "string"))
                                                .put("license", new JSONObject().put("type", "string"))
                                                .put("attribution", new JSONObject().put("type", "string"))
                                                .put("retrievedAt", new JSONObject().put("type", "string"))
                                                .put("reviewStatus", new JSONObject().put("type", "string")))
                                        .put("required", new JSONArray().put("field").put("sourceName").put("sourceUrl").put("license").put("attribution").put("retrievedAt").put("reviewStatus")))))
                        .put("required", new JSONArray().put("id").put("malay").put("chinese").put("sourceRefs"))))
                .put("practicePrompts", new JSONObject().put("type", "array").put("items", new JSONObject().put("type", "string")));
        JSONObject schema = new JSONObject()
                .put("type", "object")
                .put("additionalProperties", false)
                .put("properties", fields)
                .put("required", new JSONArray().put("chineseMeaning").put("partOfSpeech").put("pronunciationNotes").put("syllables").put("examples").put("practicePrompts"));
        return new JSONObject()
                .put("type", "json_schema")
                .put("name", "malay_vocab_enrichment")
                .put("strict", true)
                .put("schema", schema);
    }

    private static String readAll(InputStream input) throws Exception {
        if (input == null) return "";
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
            StringBuilder builder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) builder.append(line);
            return builder.toString();
        }
    }
}
