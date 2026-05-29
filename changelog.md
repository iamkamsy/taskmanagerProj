# Task Manager — Changelog

A running log of issues encountered and fixes applied across each phase of the project.

---

## v1.3.0 - ALB, ECS services, and secrets (Part 3)

**Application Load Balancer**
Added `infra/alb.tf` creating `task-manager-prod-alb` (public, HTTP port 80) with two target groups: `task-manager-prod-frontend-tg` (port 80, health check `/`) and `task-manager-prod-backend-tg` (port 8000, health check `/api/health`). An HTTP listener on port 80 uses a path-based rule (`/api/*` → backend, default → frontend).

**Security groups**
Added `infra/security_groups.tf` with three security groups: ALB SG (inbound TCP 80 from `0.0.0.0/0`), frontend ECS SG (inbound TCP 80 from ALB SG only), and backend ECS SG (inbound TCP 8000 from ALB SG only). ECS containers are never reachable directly from the internet despite running in public subnets with public IPs.

**Secrets Manager**
Added `infra/secrets.tf` creating two Secrets Manager secret containers (`task-manager-prod/mongo-uri` and `task-manager-prod/secret-key`). No values are stored in Terraform. Secret values must be populated manually via the AWS CLI or Console before ECS tasks will start.

**ECS task definitions**
Added `infra/task_definitions.tf` with Fargate task definitions for backend (family `task-manager-prod-backend`, Gunicorn on port 8000, MONGO_URI and SECRET_KEY injected from Secrets Manager) and frontend (family `task-manager-prod-frontend`, nginx on port 80). Both use awsvpc networking and write logs to the existing CloudWatch log groups.

**ECS services**
Added `infra/services.tf` with Fargate services for backend and frontend. Both run in public subnets with `assign_public_ip = true`, are attached to their respective ALB target groups, depend on the HTTP listener, and have deployment circuit breaker with rollback enabled.

**IAM — Secrets Manager read policy**
Updated `infra/iam.tf` to add an inline policy on the task execution role granting `secretsmanager:GetSecretValue` scoped to exactly the two secret ARNs. No wildcard permissions.

**Variables**
Added nine new variables to `infra/variables.tf`: `backend_image_tag`, `frontend_image_tag`, `backend_desired_count`, `frontend_desired_count`, `backend_cpu`, `backend_memory`, `frontend_cpu`, `frontend_memory`, `cors_origins`.

**Outputs**
Added eight new outputs to `infra/outputs.tf`: `alb_dns_name`, `alb_url`, `frontend_service_name`, `backend_service_name`, `frontend_target_group_arn`, `backend_target_group_arn`, `mongo_uri_secret_arn`, `secret_key_secret_arn`.

**Documentation**
Added Part 3 deployment section to `documentation.md` covering the new resources, manual pre-deploy steps (secrets, ECR push), apply command, and test instructions. Updated `infra/README.md` to reflect the full Part 3 architecture, file table, variable table, secrets population instructions, ECR push guide, and apply/test commands.

**Deployment doc fix — two-pass Terraform flow**
The original docs said to populate Secrets Manager secrets before `terraform apply`, but the secret containers are created by Terraform and do not exist before the first apply. Fixed by documenting a two-pass deployment: Pass 1 applies with `backend_desired_count=0` and `frontend_desired_count=0` to create all AWS resources (including secret containers and ECR repos) without starting ECS tasks; between passes the user populates secrets and pushes images; Pass 2 applies with real image tags and desired count 1 to start tasks. Also added a note that ECS task public IPs are not stable without a NAT Gateway, and that MongoDB Atlas Network Access may need to allow all IPs temporarily for a practice deployment.

---

## v1.2.0 - Terraform foundation (Part 2)

**Partial S3 backend config (backend.hcl)**
`infra/backend.tf` now uses a partial S3 backend block (`backend "s3" {}`) with no values hard-coded. Real backend values (bucket name, DynamoDB table) live in an untracked `infra/backend.hcl` file that is listed in `.gitignore`. A committed `infra/backend.hcl.example` serves as the template. Initialisation requires `terraform init -backend-config=backend.hcl`. This avoids committing placeholder strings and avoids any risk of accidentally committing account-specific bucket names.

**Bootstrap module (`infra/bootstrap/`)**
Added a standalone Terraform module that creates the S3 bucket (versioning, AES-256 encryption, public access blocked, `prevent_destroy`) and DynamoDB table (`PAY_PER_REQUEST`, `LockID` hash key) used for remote state storage and locking. Bootstrap uses local state and is run once before initialising the main `infra/` module. S3 bucket name is a variable to handle global uniqueness requirements.

**Main Terraform configuration (`infra/`)**
Created all foundation files: `providers.tf`, `backend.tf`, `variables.tf`, `locals.tf`, `outputs.tf`, `networking.tf`, `ecr.tf`, `ecs.tf`, `iam.tf`, `logs.tf`, `README.md`.

**Networking — public-subnet-only, no NAT Gateway**
Created VPC (`10.0.0.0/16`), two public subnets across `us-east-1a` and `us-east-1b`, Internet Gateway, and a public route table. No NAT Gateway, no private subnets. NAT Gateway is intentionally omitted to avoid ~$32/month recurring cost on a personal practice project. In a later part, ECS Fargate tasks will run in public subnets with `assign_public_ip = true`, locked down to ALB-only inbound via security groups. Private subnets + NAT Gateway (or Atlas PrivateLink) are documented as the preferred hardened production architecture and marked as future work.

**ECR repositories**
Created `task-manager-prod-backend` and `task-manager-prod-frontend` with image scanning on push and `IMMUTABLE` tag mutability.

**ECS cluster**
Created `task-manager-prod-cluster`. No ECS services, task definitions, or ALB in this part.

**CloudWatch log groups**
Created `/ecs/task-manager-prod-backend` and `/ecs/task-manager-prod-frontend` with 7-day retention to limit log storage cost.

**IAM baseline**
Created ECS task execution role (`task-manager-prod-ecs-task-execution`) with the AWS-managed `AmazonECSTaskExecutionRolePolicy` attached. Created ECS task role (`task-manager-prod-ecs-task`) with no inline permissions yet; app-level permissions (Secrets Manager, etc.) will be added in a later part.

**Documentation**
Added Part 2 deployment section to `documentation.md` covering region, environment, NAT Gateway cost rationale, public-subnet trade-off, resource table, and quick start. Added deployment pointer to `README.md`. Added `infra/README.md` with full variable reference, step-by-step setup guide, and table of what is not in this part.

---

## v1.1.0 - Docker foundation

**Backend health endpoint added**
Added `GET /api/health` returning `{"status": "ok"}` with HTTP 200. The endpoint itself requires no authentication and performs no MongoDB query, making it safe for ECS/ALB polling. Backend startup still runs full Flask app initialization (`MongoClient`, unique index setup) regardless of the health endpoint — the container will not reach healthy if `MONGO_URI` is missing or Atlas is unreachable at startup.

**Backend Dockerfile**
Created `backend/Dockerfile` using `python:3.12-slim`. Installs dependencies from `requirements.txt`, copies source, and runs the app with Gunicorn bound to `0.0.0.0:8000`. No `.env` file is copied into the image; all configuration is passed via environment variables at runtime.

**Frontend multi-stage Dockerfile**
Created `frontend/Dockerfile` with a two-stage build: a Node 20 stage runs `npm ci` and `npm run build`, then an nginx Alpine stage serves the built `dist/` directory as static files on port 80. Backend URLs are not baked into the image.

**Frontend nginx config (production)**
Created `frontend/nginx.conf` with a minimal server block, static file serving, and an SPA fallback. No TLS and no `/api` proxy — production `/api` routing will be handled by ALB path routing in a later deployment part.

**Frontend nginx config (local compose)**
Created `frontend/nginx.local.conf` for use with docker-compose only. Proxies `/api/` to `http://backend:8000` with standard proxy headers so browser flows work end-to-end at `http://localhost`. This file is never used inside the frontend Docker image itself; docker-compose mounts it at runtime as a volume override.

**`.dockerignore` files**
Added `backend/.dockerignore` (excludes `venv`, `__pycache__`, `.env`, `*.pyc`, etc.) and `frontend/.dockerignore` (excludes `node_modules`, `dist`, `.env`, etc.) to keep images lean.

**Local smoke-test `docker-compose.yml` — env handling fix**
`docker-compose.yml` previously interpolated `MONGO_URI` and `SECRET_KEY` directly in the `environment` block, which rendered as blank values unless those variables were also set in the shell. Fixed by removing the secret variables from the explicit `environment` block and relying solely on `env_file: ./backend/.env` for secrets. Non-secret compose-specific overrides (`SESSION_COOKIE_SECURE`, `CORS_ORIGINS`, `FLASK_DEBUG`, `TLS_INSECURE`) remain in the `environment` block. The compose header comment now correctly instructs users to copy the root `.env.example` to `backend/.env` (the repo has no `backend/.env.example`).

**Documentation updated**
Added a Docker/Containerization section to `documentation.md` covering build/run commands, env var list, the health endpoint behaviour, and a clear explanation of local vs production nginx routing. Corrected the setup instruction to reference the root `.env.example` rather than a nonexistent `backend/.env.example`.

---

## v1.0.1 — Pre-merge cleanup and hardening

**Frontend README source layout had a false auth.ts reference**
The `api/` directory only contains `tasks.ts`. The README incorrectly listed `auth.ts` as a separate file. Removed the false reference; the description now reads "task fetch helpers and SessionExpiredError".

**Documentation version drift**
`documentation.md` listed TypeScript 5 and Vite 6. Updated to TypeScript 6 and Vite 8 to match `package.json`. React version was already updated to 19 in a prior pass.

**React Fast Refresh lint error: button.tsx exported both Button and buttonVariants**
The ESLint `react-refresh/only-export-components` rule requires component files to export only components. Moved `buttonVariants` into a dedicated `frontend/src/components/ui/button-variants.ts` file. `button.tsx` now imports from there and exports only `Button`.

**React Fast Refresh lint error: AuthContext.tsx exported both AuthProvider and useAuth**
Same rule violation. Moved `useAuth` into a new `frontend/src/context/useAuth.ts` file. `AuthContext.tsx` now exports only `AuthProvider` plus the `AuthContext`, `AuthContextType`, and `AuthUser` types needed by the hook. Updated imports in `App.tsx`, `AuthPage.tsx`, and `TasksPage.tsx` to pull `useAuth` from `@/context/useAuth`.

**MongoDB unique index startup note missing from documentation**
Added a callout to `documentation.md` warning that `init_db()` creates unique indexes on `users.email` and `users.username` at startup, and that the app will fail to start if duplicate values already exist in the collection.

---

## Phase 1 — Foundation

**shadcn/ui init failed: Tailwind config not found**
shadcn expects a `tailwind.config.js` file. Tailwind v4 dropped this in favour of `@import "tailwindcss"` in the CSS file. Fixed by adding the CSS import first, then re-running `npx shadcn@latest init`.

**shadcn/ui init failed: import alias not found**
shadcn reads path aliases from the root `tsconfig.json`, but Vite scaffolds them into `tsconfig.app.json`. Fixed by copying `compilerOptions.paths` into the root config and adding `"ignoreDeprecations": "6.0"` for the TypeScript 6.x `baseUrl` deprecation warning.

**MongoDB: no default database name**
The Atlas connection string (`mongodb+srv://.../?appName=...`) has no database in the path, so `client.get_default_database()` threw `ConfigurationError`. Fixed by switching to `client[os.environ.get("DB_NAME", "taskmanager")]` and adding `DB_NAME=taskmanager` to `.env`.

**MongoDB: SSL handshake TLSV1_ALERT_INTERNAL_ERROR**
Looked like a Python 3.14 / OpenSSL 3.0.18 TLS incompatibility. Was actually MongoDB Atlas rejecting the connection because the development machine's IP was not on the Atlas Network Access whitelist — Atlas returns a TLS alert for unrecognised IPs. Fixed by whitelisting the IP in Atlas → Network Access. Network access is currently set to `0.0.0.0/0` (all IPs) for local development — must be locked down before any production deployment.

---

## Phase 3 & 4 — Task API and UI

**`/api/tasks` returning 404 after backend restart**
Six stale Flask debug-mode processes were still bound to port 5000. Flask's reloader spawns a parent+child pair — killing only the child causes the parent to respawn it immediately. Fixed by writing a PowerShell script to find all Python processes with `app.py` in their command line and kill them all at once.

**`taskkill /F` failing from Git Bash**
Git Bash interprets `/F` as a Unix file path, not a Windows flag. Fixed by writing the kill logic as a `.ps1` script and invoking it via `powershell -ExecutionPolicy Bypass -File`.

**Design review fixes**
- `space-y-1` → `space-y-1.5` on label/input wrappers for consistent vertical rhythm.
- Task name `truncate` → `line-clamp-2` to allow two lines before clipping.
- Textarea missing `transition-colors` — added to match shadcn `Input` focus animation.
- Delete button missing `self-start` — it was stretching to the full card height.
- Delete errors were shown via `alert()` — replaced with inline rendered state.

---

## Phase 5 — Task Editing

**Design review fixes**
- Create form used `space-y-1` while edit form used `space-y-1.5`. Normalised both to `space-y-1.5`.
- Edit button had a hover text change but no background change, making it visually asymmetric with the Delete button. Added `hover:bg-accent`.

---

## Phase 6 — Hardening

**Backend accepted any string as a deadline**
`"banana"` was a valid deadline. Added `_DATE_RE` regex (`^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$`) in `_validate_fields()` and a `date.fromisoformat(deadline) < date.today()` past-date check.

**No field length caps**
Unbounded strings could reach MongoDB. Added caps: username 50, email 254, password 6–128, task name 200, description 2000.

**No session expiry handling**
Mid-session 401s returned cryptic error messages. Added `SessionExpiredError` class and `apiFetch()` wrapper in `tasks.ts` — any 401 throws `SessionExpiredError`, which `handleApiError()` catches and routes to `logout()`, redirecting automatically.

---

## Phase 7 — Cloud-Readiness

**MongoClient created per request**
`get_db()` was called inside Flask's `g` (request context), opening a new connection pool on every HTTP request. Under any load this exhausts Atlas free-tier connection limits. Fixed by moving `MongoClient` to an app-level singleton initialised once in `init_db(app)` at startup.

**Hardcoded config values**
`SESSION_COOKIE_SECURE=False`, `CORS origins=["http://localhost:5173"]`, and `debug=True` were all hardcoded. Any accidental deploy would have broken sessions, blocked the frontend, and exposed the debug console. Fixed by reading all three from environment variables with safe local defaults.
