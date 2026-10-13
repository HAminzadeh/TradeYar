package com.tradeyar.app.users;

import java.util.Map;
import java.util.concurrent.atomic.AtomicReference;
import org.springframework.web.bind.annotation.*;

/** Demo-only preferences; deliberately no identity/authentication claims. */
@RestController
@RequestMapping("/api/preferences")
public class PreferencesController {
  public record Preferences(String locale, String theme) { }
  private final AtomicReference<Preferences> preferences = new AtomicReference<>(new Preferences("fa-IR","dark"));
  @GetMapping public Map<String,Object> get() {
    return Map.of("preferences",preferences.get(),"persistence","MEMORY_ONLY","authentication","NOT_IMPLEMENTED");
  }
  @PutMapping public Preferences update(@RequestBody Preferences requested) {
    if (requested == null || !("fa-IR".equals(requested.locale()) || "en-US".equals(requested.locale())))
      throw new IllegalArgumentException("locale must be fa-IR or en-US");
    if (!("dark".equals(requested.theme()) || "light".equals(requested.theme())))
      throw new IllegalArgumentException("theme must be dark or light");
    preferences.set(requested);
    return requested;
  }
}