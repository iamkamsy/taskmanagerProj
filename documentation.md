# Task Manager — Project Documentation

## Table of Contents
1. [Tech Stack](#tech-stack)
2. [How It All Connects](#how-it-all-connects)
3. [Running Locally](#running-locally)
4. [Future Improvements](#future-improvements)
5. [Starting From Scratch](#starting-from-scratch)

---

## Tech Stack

### Frontend
| Tool | Version | Purpose |
|------|---------|---------|
| React | 19 | UI component tree and state management |
| TypeScript | 6 | Type safety across all frontend code |
| Vite | 8 | Dev server, hot reload, and production bundler |
| Tailwind CSS | v4 | Utility-first styling via `@import "tailwindcss"` in CSS |
| shadcn/ui | latest | Pre-built accessible components (Button, Input, Label) |

### Backend
| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.14 | Runtime |
| Flask | 3.1.0 | Web framework and routing |
| Flask-CORS | 5.0.0 | Cross-origin request handling between Vite dev server and Flask |
| Flask signed cookie sessions | built-in | Signed cookie sessions for auth state |
| bcrypt | 4.2.1 | Password hashing |
| gunicorn | 23.0.0 | Production WSGI server (replaces Flask dev server) |
| python-dotenv | 1.0.1 | Loads `.env` into `os.environ` at startup |

### Database
| Tool | Purpose |
|------|---------|
| MongoDB Atlas | Cloud-hosted database for users and tasks |
| pymongo | 4.10.1 | Python driver for MongoDB |

> **Unique indexes:** `init_db()` creates unique indexes on `users.email` and `users.username` at startup. Before enabling this against an existing collection, confirm there are no duplicate email or username values — index creation will fail and prevent the app from starting if duplicates exist.

---

## Docker / Containerization

Both services have Dockerfiles. The backend is a single-stage Python/Gunicorn image; the frontend is a multi-stage Node build that ends in an nginx static-file server.

### Backend

The backend image runs Gunicorn on port **8000** inside the container. All configuration is injected via environment variables at runtime — no `.env` file is baked into the image.

**Build:**
```bash
docker build -t task-manager-backend ./backend
```

**Run** (supply all required env vars):
```bash
docker run -p 8000:8000 \
  -e MONGO_URI=<your_atlas_uri> \
  -e DB_NAME=taskmanager \
  -e SECRET_KEY=<long_random_string> \
  -e SESSION_COOKIE_SECURE=true \
  -e CORS_ORIGINS=https://yourdomain.com \
  -e FLASK_DEBUG=false \
  -e TLS_INSECURE=false \
  task-manager-backend
```

**Health check endpoint** (no auth, no DB required):
```
GET /api/health  →  200 { "status": "ok" }
```
This endpoint is suitable for use as an ECS/ALB health check target.

### Frontend

The frontend image is a two-stage build: Node installs dependencies and runs `npm run build`, then nginx serves the resulting `dist/` as static files on port **80**.

**Build:**
```bash
docker build -t task-manager-frontend ./frontend
```

**Run:**
```bash
docker run -p 80:80 task-manager-frontend
```

The frontend image contains only pre-built static assets. No backend URL is baked in. In production, ALB path routing (`/api/*` → backend target group, `/*` → frontend target group) will be added in a later part — nginx does not proxy `/api` requests.

### Local smoke testing with docker-compose

A `docker-compose.yml` at the repo root wires both services together for local end-to-end smoke testing. Copy the root `.env.example` to `backend/.env`, fill in real values, then run:

```bash
docker compose up --build
```

Secrets (`MONGO_URI`, `SECRET_KEY`, `DB_NAME`) are loaded from `backend/.env` via `env_file`. Non-secret compose-specific overrides (`SESSION_COOKIE_SECURE`, `CORS_ORIGINS`, `FLASK_DEBUG`, `TLS_INSECURE`) are set directly in the `environment` block. The frontend will be available at `http://localhost` and the backend directly at `http://localhost:8000`.

This compose file is **local-only** and must never be used for production.

#### Local vs production nginx routing

The production frontend image (`frontend/Dockerfile`) uses `frontend/nginx.conf`, which serves static files only and does **not** proxy `/api` requests. In production, `/api/*` traffic will be routed to the backend target group by ALB path routing, added in a later deployment part.

For local docker-compose, the frontend service mounts `frontend/nginx.local.conf` over the default nginx config at runtime. This local config proxies `/api/` to `http://backend:8000` so browser flows work end-to-end at `http://localhost` without a separate ALB. The `nginx.local.conf` file is never used inside the frontend Docker image itself.

#### Health endpoint behaviour

`GET /api/health` returns `{"status": "ok"}` with HTTP 200 and requires no authentication and performs no MongoDB query. Note that backend startup — regardless of the health check — still runs the full Flask app initialization, including `MongoClient` creation and unique index setup in `init_db()`. The health endpoint is safe for ECS/ALB polling, but the container will not reach a healthy state if `MONGO_URI` is missing or Atlas is unreachable at startup.

---

## How It All Connects

```
Browser
   │
   │  HTTPS (443)
   ▼
nginx  ──── /  ──────────────────► React dist/ (static files)
   │
   │  /api/*  (proxy_pass)
   ▼
gunicorn (127.0.0.1:8000)
   │
   ▼
Flask app
   ├── /api/auth/*  ──► auth blueprint  ──► MongoDB Atlas (users collection)
   └── /api/tasks/* ──► tasks blueprint ──► MongoDB Atlas (tasks collection)
```

### Request lifecycle (example: create task)

1. User fills in the create form in React and clicks **Save Task**.
2. `createTask()` in `frontend/src/api/tasks.ts` sends `POST /api/tasks` with credentials.
3. In dev: the Vite proxy (`vite.config.ts`) forwards the request to `http://localhost:5000`.
   In prod: nginx forwards it to gunicorn at `127.0.0.1:8000`.
4. Flask checks `session["user_id"]` — if missing, returns 401.
5. `_validate_fields()` in `backend/routes/tasks.py` validates name, deadline format, past-date, and length caps.
6. `make_task()` builds the document and `db.tasks.insert_one()` writes it to Atlas.
7. The new document is serialised and returned as JSON.
8. React receives the task, splices it into state, re-sorts by deadline, and renders immediately — no page refresh.

### Auth flow

- Signup/login sets `session["user_id"]` and `session["username"]` in a signed HTTP-only cookie.
- `GET /api/auth/me` is called on every page load — if it returns 401 the user sees the auth page, otherwise the tasks page renders.
- Logout calls `session.clear()` on the backend and sets `user = null` in `AuthContext`.
- Any 401 response from a task route throws `SessionExpiredError`, which triggers `logout()` automatically.

### Data ownership

Every task document in MongoDB stores a `user_id` field (ObjectId). All read, update, and delete queries include `{"user_id": ObjectId(user_id)}` — a user physically cannot access another user's tasks regardless of what they send to the API.

---

## Running Locally

```bash
# Terminal 1 — backend
cd backend && venv/Scripts/activate && py app.py

# Terminal 2 — frontend
cd frontend && npm run dev
```

Open `http://localhost:5173`.

> **MongoDB Atlas Network Access:** During local development, the Atlas cluster's Network Access list is set to allow all IPs (`0.0.0.0/0`). Before deploying to production, remove the open rule and replace it with only the specific IP(s) of your production server. Leaving `0.0.0.0/0` in place on a live deployment is a security risk.

---

## Future Improvements

### Version 2 — Quality of life

| Feature | Notes |
|---------|-------|
| Task status (to-do / in progress / done) | Add a `status` field to the task model; filter/group by status in the UI |
| Overdue indicator | Highlight tasks where `deadline < today` in amber or red |
| Confirm before delete | Replace the instant delete with a confirmation step to prevent accidental loss |
| Pagination or infinite scroll | The current list renders all tasks at once; will degrade with large lists |
| Password reset via email | Requires an email-sending service (SendGrid, AWS SES) |

### Version 3 — Collaboration

| Feature | Notes |
|---------|-------|
| Shared task lists | Tasks belong to a list; lists can have multiple members |
| Role-based access | Owner vs. viewer vs. editor per list |
| Real-time updates | WebSockets or Server-Sent Events so collaborators see changes live |
| Activity feed | Show who created or edited what, and when |

---

## Deployment — Part 2: Terraform Foundation

> **AWS cost warning:** AWS resources created by this Terraform configuration may incur charges even without a NAT Gateway. ECR storage, ECS cluster metadata, CloudWatch log ingestion/storage, S3 state bucket storage, and DynamoDB lock table reads/writes all have cost components. Monitor your AWS billing dashboard.

### Overview

| Setting | Value |
|---|---|
| Region | `us-east-1` |
| Environment | `prod` |
| Remote state | S3 + DynamoDB (bootstrapped separately) |
| NAT Gateway | **Not created** (see cost rationale below) |

### Networking — cost-conscious design

**NAT Gateway is intentionally omitted.** A NAT Gateway costs approximately $0.045/hour (~$32/month) plus data transfer charges. For a personal practice project this recurring cost is not justified.

Instead, in a later deployment part, ECS Fargate tasks will run in **public subnets** with `assign_public_ip = true`. Security groups will restrict inbound container traffic to the ALB security group only, so containers are not directly accessible from the internet despite having public IPs.

**This is acceptable for a practice deployment, but not the preferred hardened production architecture.** For a real production system, the recommended approach is private subnets + NAT Gateway (or VPC endpoints + Atlas PrivateLink) so containers never receive public IPs. This is documented as future work in `infra/networking.tf` and `infra/README.md`.

### Resources created

| Resource | Name |
|---|---|
| VPC | `task-manager-prod-vpc` |
| Public subnets | `task-manager-prod-public-1` (us-east-1a), `task-manager-prod-public-2` (us-east-1b) |
| Internet Gateway | `task-manager-prod-igw` |
| ECR backend | `task-manager-prod-backend` |
| ECR frontend | `task-manager-prod-frontend` |
| ECS cluster | `task-manager-prod-cluster` |
| CloudWatch log groups | `/ecs/task-manager-prod-backend`, `/ecs/task-manager-prod-frontend` (7-day retention) |
| IAM task execution role | `task-manager-prod-ecs-task-execution` |
| IAM task role | `task-manager-prod-ecs-task` |

### Quick start

1. Run bootstrap to create S3 state bucket and DynamoDB lock table — see `infra/bootstrap/README.md`.
2. Copy `infra/backend.hcl.example` to `infra/backend.hcl` (untracked) and fill in bootstrap outputs.
3. Run `terraform init -backend-config=backend.hcl` then `terraform apply` from `infra/`.

Full instructions and variable reference: [`infra/README.md`](infra/README.md).

### Not in this part

ECS services, task definitions, ALB, HTTPS, Route 53, Secrets Manager, and GitHub Actions CI/CD are not created here. They will be added in later deployment parts.

---

## Starting From Scratch

If you were to rebuild this project from zero, follow these steps in order.

### 1. Repository and environment

```bash
# Create repo, add .gitignore (node_modules, venv, .env, dist)
git init taskManagerProj && cd taskManagerProj
```

Create `.env.example` first — document every secret before writing any code.

### 2. Backend scaffold

```bash
mkdir backend && cd backend
py -m venv venv
venv/Scripts/activate      # Windows
pip install flask flask-cors pymongo bcrypt python-dotenv gunicorn certifi
pip freeze > requirements.txt
```

- Create `app.py`, `db.py`, `models/user.py`, `models/task.py`, `routes/auth.py`, `routes/tasks.py`.
- Wire `MongoClient` as an app-level singleton from day one (`init_db(app)` pattern) — do not use `flask.g` for the client.
- Make `SESSION_COOKIE_SECURE`, `CORS_ORIGINS`, and `FLASK_DEBUG` env-var-driven from day one.

### 3. Frontend scaffold

```bash
cd ..
npm create vite@latest frontend -- --template react-ts
cd frontend && npm install
npm install -D @tailwindcss/vite tailwindcss
npx shadcn@latest init
```

Key config points:
- Add `@import "tailwindcss"` to your CSS file before running shadcn init.
- Copy `compilerOptions.paths` from `tsconfig.app.json` into root `tsconfig.json` so shadcn can resolve the `@/` alias.
- Add the Vite dev proxy (`/api → http://localhost:5000`) to `vite.config.ts` before writing any fetch calls.

### 4. Build order (vertical slices)

| Phase | Gate before moving on |
|-------|-----------------------|
| Foundation | Backend starts, frontend starts, Atlas connection confirmed |
| Auth | Signup, login, logout, and route protection all pass Playwright |
| Task API | All three routes return correct data for the right user |
| Task UI | Create, display, delete update state without refresh |
| Task editing | Edit saves, re-sorts, cancel discards — all without refresh |
| Hardening | Input validation, session expiry, isolation, and mobile layout |
| Cloud-readiness | Env-driven config, gunicorn, nginx, certbot, systemd service |
