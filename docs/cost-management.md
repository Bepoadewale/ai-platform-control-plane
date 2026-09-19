# Cost management

Each request carries owner, team/tenant, cost center, environment type, created time, and optional expiry. The planner reports a transparent indicative monthly and TTL cost estimate. TTL cleanup only destroys non-production environments; production uses an explicit approval path. AWS resources must inherit these tags and production deployments should integrate OpenCost/AWS CUR for actual allocation.
