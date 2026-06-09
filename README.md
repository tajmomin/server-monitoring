# 🖥️ Server Monitoring System

A full-stack remote server monitoring application built with Node.js, Express, PostgreSQL, and Nodemailer. Tracks real-time server metrics (CPU, memory, disk), evaluates alert rules, and automatically dispatches HTML email notifications to administrators when thresholds are breached.

---

## Features

- **Metric ingestion** — POST endpoint to record CPU, memory, and disk readings per server
- **Live dashboard** — Served single-page frontend showing all servers with their latest metrics
- **Automated alerting** — On each new metric, checks alert rules and fires emails for any unnotified breaches
- **Email notifications** — Styled HTML alert emails sent via Gmail/Nodemailer to assigned server admins
- **Alert & email history** — REST endpoints for querying recent alert events and email dispatch logs

---

## Tech Stack

| Layer | Technology |
|---|---|
| Runtime | Node.js |
| Framework | Express 4 |
| Database | PostgreSQL (`pg`) |
| Email | Nodemailer (Gmail SMTP) |
| Config | dotenv |
| Dev server | nodemon |

---

## Project Structure

```
server-monitoring-main/
├── index.js        # Express app, routes, alert dispatch logic
├── db.js           # PostgreSQL connection pool
├── mailer.js       # Nodemailer transporter & sendAlertEmail()
├── public/
│   └── index.html  # Frontend dashboard (served statically)
├── .env            # Environment variables (not committed)
└── package.json
```

---

## Getting Started

### Prerequisites

- Node.js v16+
- PostgreSQL database with the expected schema (see [Database Schema](#database-schema))
- A Gmail account with an [App Password](https://support.google.com/accounts/answer/185833) enabled

### Installation

```bash
git clone https://github.com/your-username/server-monitoring.git
cd server-monitoring
npm install
```

### Configuration

Create a `.env` file in the project root:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=server_monitoring
DB_USER=postgres
DB_PASSWORD=your_db_password

GMAIL_USER=you@gmail.com
GMAIL_APP_PASSWORD=your_app_password

PORT=3000
```

> ⚠️ Never commit your `.env` file. It is already listed in `.gitignore`.

### Running the App

```bash
# Production
npm start

# Development (auto-restarts on file changes)
npm run dev
```

The server will start at `http://localhost:3000`.

---

## API Reference

### `POST /api/metrics`
Record a new metric reading. Triggers alert evaluation automatically.

**Request body:**
```json
{
  "metric_id": "M_001",
  "server_id": "S_001",
  "metric_type": "cpu_usage",
  "value": 87.5,
  "unit": "percent"
}
```

**Response:** `201 Created`

---

### `GET /api/servers`
Returns all servers with their most recent CPU, memory, and disk values.

---

### `GET /api/metrics/:server_id`
Returns the 50 most recent metric readings for a given server.

---

### `GET /api/alerts`
Returns the 20 most recent alert events, joined with rule and server info.

---

### `GET /api/emaillog`
Returns the 20 most recent email dispatch records with status (`sent` / `failed`).

---

## Database Schema

The application expects the following tables in PostgreSQL:

| Table | Description |
|---|---|
| `Servers` | Registered servers (`server_id`, `hostname`, `ip_address`, `environment`, `status`) |
| `Personnel` | Users/admins (`person_id`, `name`, `email`, `role`) |
| `Server_Personnel` | Many-to-many: server ↔ admin assignment |
| `Metrics` | Time-series metric readings (`cpu_usage`, `memory_usage`, `disk_usage`, `network_usage`) |
| `Alert_Rules` | Threshold rules per server/metric type with severity and cooldown |
| `Alert_Events` | Triggered alert instances, linked to a rule and metric reading |
| `Email_Log` | Record of all alert emails sent (`sent` / `failed` / `pending`) |

### Setup

Run the provided SQL script to create all tables, indexes, views, stored procedures, and triggers, and load sample data:

```bash
psql -U postgres -d server_monitoring -f serversql.sql
```

Or paste it directly into psql:

```bash
psql -U postgres -d server_monitoring
```

### Trigger

An `AFTER INSERT` trigger on the `Metrics` table (`trg_after_metric_insert`) automatically evaluates all active alert rules for the incoming server/metric combination. If a threshold is breached and the rule's cooldown has elapsed, a new `Alert_Events` row is inserted — which the Node.js `dispatchPendingAlerts()` function then picks up to send emails.

### Views

| View | Description |
|---|---|
| `vw_server_health` | Latest metric reading per metric type per server |
| `vw_admin_alert_dashboard` | All alert events with email dispatch status, visible to admins only |

### Stored Procedures

| Procedure | Description |
|---|---|
| `insert_metric(...)` | Bulk-safe wrapper to insert a metric reading |
| `dispatch_alert_email(...)` | Inserts an `Email_Log` entry with cooldown deduplication |

---

## How Alerting Works

1. A metric is POSTed to `/api/metrics` and inserted into the `Metrics` table.
2. `dispatchPendingAlerts()` queries for any `Alert_Events` linked to that metric that have **not yet appeared** in `Email_Log`.
3. For each unnotified event, all admins assigned to that server are looked up.
4. A styled HTML email is sent to each admin via Gmail.
5. The result (`sent` or `failed`) is recorded in `Email_Log` to prevent duplicate sends.

---

## License

MIT
