from prometheus_client import Counter, Histogram

REQUESTS = Counter("platform_requests_total", "Platform requests", ["operation", "outcome"])
POLICY_DENIALS = Counter("platform_policy_denials_total", "Policy denials", ["reason"])
DURATION = Histogram(
    "platform_request_duration_seconds", "Control plane request duration", ["operation"]
)
