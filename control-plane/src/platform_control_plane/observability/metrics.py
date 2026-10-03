from prometheus_client import Counter, Gauge, Histogram

REQUESTS = Counter("platform_requests_total", "Platform requests", ["operation", "outcome"])
HTTP_REQUESTS = Counter(
    "platform_http_requests_total",
    "HTTP requests observed at the control-plane boundary",
    ["method", "route", "status_code"],
)
HTTP_DURATION = Histogram(
    "platform_http_request_duration_seconds",
    "HTTP request duration at the control-plane boundary",
    ["method", "route"],
)
POLICY_DENIALS = Counter("platform_policy_denials_total", "Policy denials", ["reason"])
DURATION = Histogram(
    "platform_request_duration_seconds", "Control plane request duration", ["operation"]
)
RECONCILIATION_JOBS = Counter(
    "platform_reconciliation_jobs_total",
    "Durable reconciliation job outcomes",
    ["action", "outcome"],
)
RECONCILIATION_QUEUE_DEPTH = Gauge(
    "platform_reconciliation_queue_depth",
    "Pending durable reconciliation jobs",
)
