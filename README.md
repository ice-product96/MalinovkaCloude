# Malinovka Smart Home

MVP client-server system for Malinovka smart devices.

## Backend

```powershell
cd backend
py -m pip install -r requirements.txt
py -m uvicorn app.main:app --reload
```

The API seeds the first device type, `Смарт шеф`, on startup and serves the device image from `images/SmartShev.png` at `/static/devices/SmartShev.png`.

Useful endpoints:

- `GET /api/app-config`
- `GET /api/device-types`
- `GET /api/device-types/smart_shev_autoclave/programs`
- `GET /api/rooms`
- `POST /api/devices`
- `POST /api/devices/{id}/commands`
- `POST /api/device/link/{external_id}`

## Server Admin

The admin panel is a separate Django Admin app that works with the same database as the FastAPI backend.

Start the FastAPI backend at least once first, so SQLAlchemy creates and seeds the smart-home tables:

```powershell
cd backend
py -m uvicorn app.main:app --reload
```

Then create Django auth tables and an admin user:

```powershell
cd backend\django_admin
py manage.py migrate
py manage.py createsuperuser
py manage.py runserver 127.0.0.1:8001
```

Open `http://127.0.0.1:8001/admin/`.

## Flutter App

```powershell
cd app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

For Android emulator use `http://10.0.2.2:8000/api` instead of `127.0.0.1`.
