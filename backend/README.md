# Residue Backend (FastAPI)

## Run
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
```

## Endpoints
- `GET /health`
- `GET /v1/config`
- `GET /v1/assets/manifest`
- `POST /v1/assets/report`

## Example
```bash
curl "http://127.0.0.1:8080/v1/assets/manifest?platform=ios&app_version=0.1.0&locale=ja-JP"
```
