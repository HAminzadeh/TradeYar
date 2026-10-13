package com.tradeyar.app.core;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.converter.HttpMessageNotReadableException;

@RestControllerAdvice
public class ApiErrors {
  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String,String>> invalid(IllegalArgumentException error) {
    return ResponseEntity.badRequest().body(Map.of("error",error.getMessage()));
  }
  @ExceptionHandler(HttpMessageNotReadableException.class)
  public ResponseEntity<Map<String,String>> invalidBody(HttpMessageNotReadableException error) {
    return ResponseEntity.badRequest().body(Map.of("error","Invalid JSON request"));
  }
  @ExceptionHandler(ResponseStatusException.class)
  public ResponseEntity<Map<String,String>> responseStatus(ResponseStatusException error) {
    return ResponseEntity.status(error.getStatusCode()).body(Map.of("error",
      error.getReason() == null ? "Request rejected" : error.getReason()));
  }
}