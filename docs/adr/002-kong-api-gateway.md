# ADR-002: Kong as API Gateway

## Status
Accepted

## Context

We need an API Gateway to:
- Provide authentication and authorization
- Rate limit API consumers
- Add observability (logging, metrics)
- Enable easy consumer onboarding

## Decision

We will use Kong Gateway (OSS) as our API Gateway.

## Consequences

### Positive
- **Plugin Ecosystem**: Rich set of plugins for auth, rate limiting, logging
- **Declarative Config**: Configuration as code (GitOps friendly)
- **Performance**: High-performance Nginx-based proxy
- **Flexibility**: Supports multiple auth methods (API key, OAuth, JWT)
- **Admin API**: Easy programmatic configuration

### Negative
- **Complexity**: Another component to manage
- **Database Dependency**: Requires PostgreSQL for configuration storage
- **Learning Curve**: Kong-specific concepts and configuration

## Implementation Notes

### Authentication
Using API Key authentication for simplicity:
```yaml
plugins:
  - name: key-auth
    config:
      key_names: [apikey, X-API-Key]
```

### Rate Limiting
Per-service rate limits:
```yaml
plugins:
  - name: rate-limiting
    config:
      minute: 100
      policy: local
```

### Correlation ID
Automatic correlation ID generation:
```yaml
plugins:
  - name: correlation-id
    config:
      header_name: X-Correlation-ID
      generator: uuid
```

### Consumer Management
```bash
# Create consumer
curl -X POST http://localhost:8001/consumers \
  --data username=new-team

# Create API key
curl -X POST http://localhost:8001/consumers/new-team/key-auth \
  --data key=secret-key-2024
```

## Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| AWS API Gateway | Fully managed, AWS native | Vendor lock-in, limited customization |
| Traefik | Simple, Docker native | Fewer enterprise features |
| Nginx | Proven, performant | Manual configuration, no admin API |
| Envoy | Modern, powerful | Complex configuration |

## References

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
