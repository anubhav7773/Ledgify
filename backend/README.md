# Ledgify FastAPI Backend

Modern, high-performance, asynchronous Python backend for **Ledgify — AI-First Indian Fintech Accounting Platform**.

---

## Architecture Overview

```
backend/
├── app/
│   ├── main.py                  # FastAPI entry point, CORS, Lifespan, Exception handlers
│   ├── core/
│   │   ├── config.py            # Pydantic v2 BaseSettings environment configuration
│   │   ├── database.py          # Supabase service role client singleton
│   │   ├── security.py          # JWT Bearer token decoder & authentication
│   │   └── exceptions.py        # Double-entry, DPDP, and standardized HTTP error handlers
│   ├── schemas/
│   │   ├── common.py            # ApiResponse[T] envelope, pagination schemas
│   │   ├── auth.py              # User context, active tenant schemas
│   │   ├── accounting.py        # Balanced double-entry vouchers schemas
│   │   ├── masters.py           # Chart of Accounts, 28 Tally groups, Stock items
│   │   ├── reports.py           # Trial Balance, P&L, Balance Sheet, Day Book
│   │   ├── ai_intake.py         # Gemini OCR, Voice vouchers, RapidFuzz entity matching
│   │   ├── gst.py               # GSTR-1, GSTR-3B, IMS portal, E-Invoice, E-Way Bill
│   │   └── dpdp_billing.py      # DPDP Act 2023 DSR Hub, Google Play billing & RTDN
│   ├── services/
│   │   ├── accounting_service.py
│   │   ├── masters_service.py
│   │   ├── reports_service.py
│   │   ├── ai_service.py
│   │   ├── fuzzy_matching_service.py
│   │   ├── gst_service.py
│   │   └── dpdp_billing_service.py
│   └── api/
│       ├── deps.py              # Multi-tenant scoping (X-Business-Id) and user dependencies
│       └── v1/
│           ├── api.py           # Router aggregation
│           └── endpoints/       # Domain routers (auth, health, vouchers, masters, reports, ai, gst, banking, dpdp, billing)
├── tests/                       # 38 Automated unit & integration tests (pytest)
├── Dockerfile                   # Multi-stage production container
├── docker-compose.yml           # Multi-service stack (FastAPI + Redis)
└── requirements.txt             # Locked dependencies
```

---

## Quick Start

### 1. Local Development
```bash
cd backend
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Interactive API documentation will be available at:
- **Swagger UI:** `http://localhost:8000/api/v1/docs`
- **ReDoc:** `http://localhost:8000/api/v1/redoc`
- **Health Check:** `http://localhost:8000/api/v1/health`

### 2. Run Test Suite
```bash
pytest -v
```

### 3. Docker Deployment
```bash
docker-compose up -d --build
```
