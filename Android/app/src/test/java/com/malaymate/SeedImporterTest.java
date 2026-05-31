package com.malaymate;

import org.junit.Test;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.Assert.*;

public class SeedImporterTest {
    @Test
    public void seedImporterDecodesBundledDecksAndCreatesTwoCardsPerWord() throws Exception {
        SeedImporter importer = new SeedImporter();
        SeedImportSummary starter = importer.parseDeckJson(
                new String(Files.readAllBytes(Path.of("../app/src/main/assets/starter_deck.json")), StandardCharsets.UTF_8)
        );
        SeedImportSummary open = importer.parseDeckJson(
                new String(Files.readAllBytes(Path.of("../app/src/main/assets/open_frequency_starter_deck.json")), StandardCharsets.UTF_8)
        );

        assertEquals(2, starter.decks);
        assertEquals(6, starter.words);
        assertEquals(12, starter.cards);
        assertEquals(1, open.decks);
        assertEquals(3000, open.words);
        assertEquals(6000, open.cards);
        assertEquals("00000000-0000-4000-8000-5df23ee8c426", SeedImporter.stableUuid("word-saya"));
    }
}
