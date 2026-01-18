# Error Handling Guide

This document describes the error handling patterns for the PropertyWebBuilder API.

---

## Current Error Format

```json
{
  "error": "Error message here"
}
```

## Recommended Error Format

```json
{
  "error": {
    "code": "PROPERTY_NOT_FOUND",
    "message": "Property with slug 'xyz' not found",
    "status": 404,
    "details": {
      "requested_slug": "xyz",
      "suggestion": "Check the slug spelling or use /properties to list available properties"
    }
  }
}
```

---

## Error Codes Reference

### 4xx Client Errors

| Code | HTTP Status | Description | Resolution |
|------|-------------|-------------|------------|
| `VALIDATION_FAILED` | 400 | Invalid request parameters | Check parameter types and values |
| `INVALID_LOCALE` | 400 | Unsupported locale code | Use `/locales` to get supported locales |
| `INVALID_SORT` | 400 | Unknown sort parameter | Use: `price-asc`, `price-desc`, `newest` |
| `NOT_FOUND` | 404 | Generic resource not found | Check URL path |
| `PROPERTY_NOT_FOUND` | 404 | Property doesn't exist | Verify slug or ID |
| `PAGE_NOT_FOUND` | 404 | CMS page doesn't exist | Check page slug |
| `THEME_NOT_FOUND` | 404 | Theme doesn't exist | Use `/all-themes` to list themes |
| `CLIENT_RENDERING_DISABLED` | 403 | Website uses Rails rendering | Contact admin to enable client rendering |
| `RATE_LIMITED` | 429 | Too many requests | Wait and retry after `Retry-After` seconds |

### 5xx Server Errors

| Code | HTTP Status | Description | Resolution |
|------|-------------|-------------|------------|
| `INTERNAL_ERROR` | 500 | Unexpected server error | Retry later, report if persistent |
| `DATABASE_ERROR` | 500 | Database connection issue | Retry later |
| `TIMEOUT` | 504 | Request timed out | Retry with smaller page size |

---

## HTTP Status Codes

| Status | Meaning | When Used |
|--------|---------|-----------|
| 200 | OK | Successful GET, POST |
| 201 | Created | Successful resource creation |
| 204 | No Content | Successful DELETE |
| 304 | Not Modified | ETag match (conditional GET) |
| 400 | Bad Request | Invalid parameters |
| 403 | Forbidden | Not authorized for resource |
| 404 | Not Found | Resource doesn't exist |
| 422 | Unprocessable Entity | Validation errors |
| 429 | Too Many Requests | Rate limited |
| 500 | Internal Server Error | Server-side error |
| 502 | Bad Gateway | Upstream service error |
| 504 | Gateway Timeout | Request timeout |

---

## Error Response Headers

| Header | Description |
|--------|-------------|
| `X-Request-Id` | Unique request ID for debugging |
| `Retry-After` | Seconds to wait (for 429 responses) |
| `X-RateLimit-Limit` | Request limit per window |
| `X-RateLimit-Remaining` | Requests remaining |
| `X-RateLimit-Reset` | Unix timestamp when limit resets |

---

## Frontend Error Handling

### Axios Error Handler

```typescript
const handleApiError = (error: unknown): never => {
  if (axios.isAxiosError(error)) {
    const status = error.response?.status;
    const data = error.response?.data;
    
    // Extract error details
    const errorInfo = data?.error || {};
    const code = errorInfo.code || 'UNKNOWN_ERROR';
    const message = errorInfo.message || error.message;
    
    // Log for debugging
    console.error(`[API Error] ${code}: ${message}`, {
      status,
      url: error.config?.url,
      details: errorInfo.details
    });
    
    throw new ApiError(code, message, status);
  }
  
  throw new Error('Unknown error occurred');
};
```

### Custom Error Class

```typescript
export class ApiError extends Error {
  constructor(
    public readonly code: string,
    message: string,
    public readonly status?: number,
    public readonly details?: Record<string, unknown>
  ) {
    super(message);
    this.name = 'ApiError';
  }
  
  get isNotFound(): boolean {
    return this.status === 404;
  }
  
  get isRateLimited(): boolean {
    return this.status === 429;
  }
  
  get isServerError(): boolean {
    return this.status !== undefined && this.status >= 500;
  }
}
```

### Graceful Degradation

```typescript
export async function getSiteDetails(): Promise<SiteDetails> {
  try {
    return await client.get('/site_details');
  } catch (error) {
    if (error instanceof ApiError && error.isNotFound) {
      console.warn('Site details not found, using defaults');
      return DEFAULT_SITE_DETAILS;
    }
    throw error;
  }
}
```

---

## Partial Failure Handling

When using `include=` parameter, some sections may fail while others succeed:

```json
{
  "data": {
    "rendering_mode": "client",
    "theme": { ... },
    "links": [...],
    "translations": { ... }
  },
  "_errors": [
    {
      "section": "homepage",
      "message": "Page not found"
    }
  ]
}
```

### Frontend Handling

```typescript
const response = await client.get('/en/client-config', {
  params: { include: 'links,homepage,translations' }
});

const { data, _errors } = response;

// Log partial failures
if (_errors?.length) {
  _errors.forEach(err => {
    console.warn(`Failed to load ${err.section}: ${err.message}`);
  });
}

// Use available data, provide fallbacks for missing sections
const links = data.links || [];
const homepage = data.homepage || null;
```

---

## Retry Strategy

### Exponential Backoff

```typescript
async function fetchWithRetry<T>(
  fn: () => Promise<T>,
  maxRetries = 3,
  baseDelay = 1000
): Promise<T> {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (error instanceof ApiError) {
        // Don't retry client errors (except rate limiting)
        if (error.status && error.status < 500 && error.status !== 429) {
          throw error;
        }
      }
      
      if (attempt === maxRetries - 1) throw error;
      
      const delay = baseDelay * Math.pow(2, attempt);
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
  throw new Error('Max retries exceeded');
}
```

---

## Debugging Tips

1. **Check Request ID**: Look for `X-Request-Id` header in error responses
2. **Enable Debug Mode**: Set `PUBLIC_DEBUG_API=true` for request logging
3. **Inspect Network**: Use browser DevTools Network tab
4. **Check Wrangler Logs**: For Cloudflare Workers, use `wrangler tail`
