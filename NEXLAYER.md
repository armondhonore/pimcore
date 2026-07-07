# Nexlayer — pimcore

<!-- nexlayer:meta version=1 analyzed=2026-06-30T13:35:59Z repo=https://github.com/armondhonore/pimcore branch=2026.x -->

> **For AI agents (Claude Code, Cursor, Gemini CLI, Copilot):**
> This file is the **project context** for this Nexlayer deployment — tech stack, env vars, secrets, live URL.
> For full platform detail (nexlayer.yaml schema, Dockerfile rules, CI/CD, task recipes) read **`nexlayer.skills`** in this repo.
>
> **Critical rules (full detail in `nexlayer.skills`):**
> - Inter-pod refs: `${podName:port}` only — never `localhost` or bare hostnames
> - Docker Hub images: prefix with `mirror.gcr.io/library/` — bare tags fail on the cluster
> - Secrets: set in the Nexlayer dashboard — never commit to `nexlayer.yaml` or Dockerfile
>
> **This file:** `agent-managed` sections update automatically. `user-editable` sections (Local Development Setup, Nexlayer Deployment Plan, Build Notes) are yours — preserved across re-analysis.

## Project Summary
<!-- nexlayer:section agent-managed=project_summary -->
Pimcore is an open-core Product Experience Management (PXM) platform combining PIM, MDM, DAM, CDP, and CMS capabilities. It provides an API-driven foundation for managing digital data and delivering it across multiple channels.
<!-- nexlayer:end -->

## Technology Stack
<!-- nexlayer:section agent-managed=tech_stack -->
| Name | Kind | Version | Detected From |
|------|------|---------|---------------|
| PHP | language | 8.2 | Dockerfile |
| Symfony | framework | 7.2 | Dockerfile |
| Apache | infra | latest | Dockerfile |
| MySQL | database | latest | Dockerfile |
| Composer | tool | latest | Dockerfile |
<!-- nexlayer:end -->

## Repository Structure
<!-- nexlayer:section agent-managed=structure_map -->
- bin/ — Executable scripts and binaries
- bundles/ — Custom Pimcore bundles/modules
- config/ — Application configuration files
- public/ — Web root and public assets
- var/ — Cache and logs
<!-- nexlayer:end -->

## External Services Required
<!-- nexlayer:section agent-managed=external_deps -->
Services that must be configured separately (not deployed by Nexlayer):

- MySQL Database
- Redis (recommended for cache/session)
<!-- nexlayer:end -->

## Local Development Setup
<!-- nexlayer:section user-editable=local_setup -->
### Prerequisites

- PHP >= 8.2
- Composer
- MySQL >= 8.0
- Apache/Nginx

### Environment variables

Copy `.env.example` to `.env.local` and fill in:

```
DATABASE_URL=mysql://user:pass@localhost:3306/pimcore
APP_ENV=dev
APP_SECRET=random-string
```

### Steps

1. `composer install` — Install PHP dependencies
2. `bin/console pimcore:install` — Initialize the Pimcore installation
3. `php -S localhost:8000 -t public` — Start local PHP development server

<!-- nexlayer:end -->

## Nexlayer Setup
<!-- nexlayer:section agent-managed=nexlayer_setup -->
### nexlayer.yaml

```yaml
application:
  name: pimcore
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/pimcore:19f16ad8bcd"
      path: /
      servicePorts:
        - 80
      vars: {}
```

<!-- nexlayer:end -->

## Nexlayer Deployment Plan
<!-- nexlayer:section user-editable=deployment_plan -->
### Pod Topology

| Pod | Image | Port | Role |
|-----|-------|------|------|
| pimcore-web | mirror.gcr.io/library/php:8.2-apache | 80 | web |
| mysql-db | mirror.gcr.io/library/mysql:8.0 | 3306 | database |

### Deployment notes

- The web pod connects to the database using mysql-db.pod:3306 following Nexlayer pod naming conventions.
- PHP extensions required for Pimcore (gd, intl, pdo_mysql, etc.) are pre-installed via the provided Dockerfile.

<!-- nexlayer:end -->

## Build Notes
<!-- nexlayer:section user-editable=build_notes -->
<!-- Add notes for future builds here — preserved across re-analysis -->
<!-- nexlayer:end -->

## Nexlayer Configuration
<!-- nexlayer:section agent-managed=nexlayer_config -->
**Last deployed:** 2026-06-30T13:37:50Z  
**Live URL:** https://relaxed-weasel-pimcore.cloud.nexlayer.ai  
**Runtime:** generic · **Port:** 80  
**Deploy branch:** 2026.x  

```yaml
application:
  name: pimcore
  pods:
    - name: app
      image: "registry.nexlayer.io/user_01kece1xyh817dwff7wnarhkxd/pimcore:19f16ad8bcd"
      path: /
      servicePorts:
        - 80
      vars: {}
```
<!-- nexlayer:end -->

## Build History
<!-- nexlayer:section agent-managed=build_history -->
| Date | Status | Notes |
|------|--------|-------|
| 2026-06-30T13:35:59Z | analyzed | initial repo analysis |
| 2026-06-30T13:37:50Z | success | deployed https://relaxed-weasel-pimcore.cloud.nexlayer.ai |
<!-- nexlayer:end -->
