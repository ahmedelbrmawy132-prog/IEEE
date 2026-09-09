# Unified JSON Logging & Correlation Tracing Specification

## Correlation Header Standard
- Header Name: `X-Correlation-ID`
- Format: UUIDv4 generated at ingress (Nginx or Go Gateway)
- Propagation: Must be forwarded downstream to the Python ML microservice on all REST/gRPC calls.

## Structured JSON Log Schema
All backend stdout logs must conform to the following schema:

```json
{
  "timestamp": "2026-09-09T04:30:00.000Z",
  "level": "INFO",
  "service": "go-api-gateway",
  "correlation_id": "c7a8b6e2-2f3b-4890-a541-698f121d49e1",
  "caller": "risk_handler.go:42",
  "message": "AI risk assessment evaluated",
  "latency_ms": 320,
  "model_used": "gemini-flash",
  "is_fallback": false,
  "decision_score": 0.82
}