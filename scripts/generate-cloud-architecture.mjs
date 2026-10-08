#!/usr/bin/env node

/**
 * Generates the self-contained AWS pilot architecture SVG used in the README.
 *
 * The checked-in AWS service icons are vendored from the official AWS Architecture
 * Icons package. Keeping generation deterministic makes the diagram reviewable and
 * prevents a documentation renderer from depending on external image hosts.
 */
import { readFile, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const iconDirectory = resolve(root, 'docs/assets/aws-icons');
const output = resolve(root, 'docs/assets/cloud-pilot-architecture.svg');

const icon = async (name) => {
  const source = await readFile(resolve(iconDirectory, `${name}.svg`));
  return `data:image/svg+xml;base64,${source.toString('base64')}`;
};

const [alb, eks, rds, ecr, secrets, iam, s3] = await Promise.all(
  ['alb', 'eks', 'rds', 'ecr', 'secrets-manager', 'iam', 's3'].map(icon),
);

const card = (x, y, width, height, title, subtitle, iconHref, tone = 'blue') => {
  const colors = {
    blue: ['#eff6ff', '#2563eb'],
    orange: ['#fff7ed', '#ea580c'],
    purple: ['#faf5ff', '#7e22ce'],
    green: ['#f0fdf4', '#15803d'],
    gray: ['#f8fafc', '#475569'],
  };
  const [fill, stroke] = colors[tone];
  return `<g>
    <rect x="${x}" y="${y}" width="${width}" height="${height}" rx="12" fill="${fill}" stroke="${stroke}" stroke-width="1.5"/>
    ${iconHref ? `<image href="${iconHref}" x="${x + 14}" y="${y + 18}" width="48" height="48"/>` : ''}
    <text x="${x + (iconHref ? 76 : 18)}" y="${y + 38}" class="card-title">${title}</text>
    <text x="${x + (iconHref ? 76 : 18)}" y="${y + 60}" class="card-subtitle">${subtitle}</text>
  </g>`;
};

const component = (x, y, title, detail, glyph, tone = 'blue') => {
  const colors = {
    blue: ['#dbeafe', '#1d4ed8'],
    purple: ['#f3e8ff', '#7e22ce'],
    green: ['#dcfce7', '#15803d'],
    amber: ['#fef3c7', '#b45309'],
  };
  const [fill, stroke] = colors[tone];
  return `<g>
    <rect x="${x}" y="${y}" width="176" height="72" rx="10" fill="${fill}" stroke="${stroke}" stroke-width="1.25"/>
    <circle cx="${x + 28}" cy="${y + 35}" r="16" fill="#fff" stroke="${stroke}" stroke-width="1.25"/>
    <text x="${x + 28}" y="${y + 41}" text-anchor="middle" class="glyph">${glyph}</text>
    <text x="${x + 56}" y="${y + 31}" class="component-title">${title}</text>
    <text x="${x + 56}" y="${y + 51}" class="component-detail">${detail}</text>
  </g>`;
};

const line = (x1, y1, x2, y2, label = '') => `<g>
  <path d="M ${x1} ${y1} L ${x2} ${y2}" class="arrow" marker-end="url(#arrowhead)"/>
  ${label ? `<text x="${(x1 + x2) / 2}" y="${(y1 + y2) / 2 - 8}" text-anchor="middle" class="edge-label">${label}</text>` : ''}
</g>`;

const svg = `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="1130" viewBox="0 0 1600 1130" role="img" aria-labelledby="title desc">
  <title id="title">AI Platform Control Plane: executed AWS pilot architecture</title>
  <desc id="desc">An icon-based architecture diagram of the Terraform-created AWS pilot: public ALB, private EKS, RDS, ECR, Secrets Manager, GitHub OIDC and GitOps, Keycloak, OPA, operator console, and observability.</desc>
  <defs>
    <marker id="arrowhead" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#64748b"/></marker>
    <style>
      text { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; fill: #0f172a; }
      .title { font-size: 30px; font-weight: 700; } .subtitle { font-size: 16px; fill: #475569; }
      .group { font-size: 16px; font-weight: 700; } .group-sub { font-size: 13px; fill: #475569; }
      .card-title { font-size: 16px; font-weight: 700; } .card-subtitle { font-size: 13px; fill: #475569; }
      .component-title { font-size: 14px; font-weight: 700; } .component-detail { font-size: 12px; fill: #475569; }
      .glyph { font-size: 17px; font-weight: 700; } .edge-label { font-size: 12px; fill: #475569; }
      .arrow { fill: none; stroke: #64748b; stroke-width: 1.6; stroke-linecap: round; }
      .note { font-size: 13px; fill: #475569; } .legend { font-size: 12px; fill: #475569; }
    </style>
  </defs>
  <rect width="1600" height="1130" fill="#ffffff"/>
  <text x="60" y="58" class="title">AI Platform Control Plane — executed AWS pilot</text>
  <text x="60" y="86" class="subtitle">Terraform-created, private EKS reference environment with an optional owner-review ALB. Destroyed after validation.</text>

  <rect x="60" y="120" width="1480" height="150" rx="18" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1.5"/>
  <text x="84" y="150" class="group">People and delivery control boundary</text>
  ${component(92, 170, 'Developer / operator', 'browser, CLI, MCP', 'U', 'green')}
  ${component(300, 170, 'Governed AI agent', 'API / MCP client', 'AI', 'green')}
  ${component(522, 170, 'GitHub Actions', 'manual Terraform workflow', 'GH', 'purple')}
  ${component(722, 170, 'GitHub OIDC', 'short-lived AWS role', 'ID', 'purple')}
  ${component(948, 170, 'GitHub App', 'scoped publication', 'APP', 'purple')}
  ${component(1148, 170, 'Protected GitHub PR', 'desired-state review', 'PR', 'purple')}
  ${line(268, 206, 300, 206)}
  ${line(698, 206, 722, 206)}

  <rect x="60" y="310" width="1480" height="700" rx="18" fill="#fffaf4" stroke="#f59e0b" stroke-width="1.5"/>
  <text x="84" y="342" class="group">AWS account / us-east-1 — pilot resources had required tags and account-guarded teardown</text>
  <text x="84" y="365" class="group-sub">Private by default. The ALB is optional, HTTP-only owner review; metrics, databases, and cluster administration stay private.</text>

  <rect x="90" y="395" width="280" height="570" rx="16" fill="#fff" stroke="#fed7aa" stroke-width="1.25"/>
  <text x="114" y="425" class="group">Terraform foundation</text>
  ${card(112, 450, 236, 82, 'S3 remote state', 'encrypted, versioned', s3, 'orange')}
  ${card(112, 548, 236, 82, 'IAM / IRSA', 'least-privilege roles', iam, 'orange')}
  ${card(112, 646, 236, 82, 'ECR', 'immutable pilot images', ecr, 'orange')}
  ${card(112, 744, 236, 82, 'Secrets Manager', 'GitHub App secret', secrets, 'orange')}
  <rect x="112" y="850" width="236" height="86" rx="12" fill="#fff7ed" stroke="#ea580c" stroke-width="1.5"/>
  <text x="130" y="883" class="card-title">VPC + private subnets</text>
  <text x="130" y="907" class="card-subtitle">NAT, routing, security groups</text>

  <rect x="400" y="395" width="1120" height="570" rx="16" fill="#f8fbff" stroke="#93c5fd" stroke-width="1.25"/>
  <text x="424" y="425" class="group">VPC runtime</text>
  <text x="424" y="448" class="group-sub">Public subnet contains the pilot ALB; application and data services run in private subnets.</text>
  ${card(430, 475, 264, 82, 'Application Load Balancer', 'bounded HTTP owner review', alb, 'blue')}
  <rect x="716" y="475" width="776" height="412" rx="14" fill="#ffffff" stroke="#60a5fa" stroke-width="1.5"/>
  <text x="742" y="505" class="group">Amazon EKS — private worker nodes</text>
  <text x="742" y="528" class="group-sub">Two API, OPA, and worker replicas with PodDisruptionBudgets were exercised.</text>
  ${component(748, 556, 'Operator Console', 'hardened static UI', 'UI', 'blue')}
  ${component(948, 556, 'Keycloak', 'OIDC / JWT / JWKS', 'ID', 'green')}
  ${component(1148, 556, 'Control-plane API ×2', 'tenant + lifecycle API', 'API', 'blue')}
  ${component(1348, 556, 'OPA ×2', 'allow / deny / approve', 'OPA', 'green')}
  ${component(748, 654, 'GitOps worker ×2', 'durable desired state', 'W', 'blue')}
  ${component(948, 654, 'Argo CD', 'ApplicationSet sync', 'CD', 'purple')}
  ${component(1148, 654, 'Golden-path workload', 'tenant namespace', 'APP', 'blue')}
  ${component(1348, 654, 'Status observer', 'Ready / Failed facts', 'OBS', 'blue')}
  ${component(748, 752, 'OTel Collector', 'spans from API', 'OT', 'purple')}
  ${component(948, 752, 'Prometheus', 'metrics + alerts', 'M', 'purple')}
  ${component(1148, 752, 'Tempo', 'trace storage', 'T', 'purple')}
  ${component(1348, 752, 'Grafana', 'operator evidence', 'G', 'purple')}
  ${line(694, 516, 720, 592)}
  ${line(924, 592, 948, 592)}
  ${line(1124, 592, 1148, 592)}
  ${line(1324, 592, 1348, 592)}
  ${line(924, 690, 948, 690)}
  ${line(1124, 690, 1148, 690)}
  ${line(1324, 690, 1348, 690)}

  ${card(1148, 900, 264, 82, 'Amazon RDS PostgreSQL', 'plans, approvals, audit, jobs', rds, 'purple')}

  <rect x="60" y="1040" width="1480" height="52" rx="12" fill="#f8fafc" stroke="#cbd5e1" stroke-width="1"/>
  <circle cx="86" cy="1066" r="7" fill="#16a34a"/><text x="102" y="1071" class="legend">Executed in pilot</text>
  <circle cx="280" cy="1066" r="7" fill="#f59e0b"/><text x="296" y="1071" class="legend">Terraform-managed AWS foundation</text>
  <circle cx="590" cy="1066" r="7" fill="#2563eb"/><text x="606" y="1071" class="legend">Runtime component</text>
  <circle cx="830" cy="1066" r="7" fill="#7e22ce"/><text x="846" y="1071" class="legend">Delivery or observability component</text>
  <text x="1120" y="1071" class="legend">Boundary: no trusted public TLS or enterprise IdP claim.</text>
</svg>`;

await writeFile(output, svg);
console.log(`Wrote ${output}`);
