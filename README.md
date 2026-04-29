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

## Yandex Smart Home

The backend can work as a Yandex Smart Home provider for a private/test skill. Yandex requires a public HTTPS endpoint and OAuth account linking, so expose the backend through your domain or a tunnel before testing.

Set strong values in `backend/.env`:

```env
MALINOVKA_PUBLIC_BASE_URL=https://your-domain.example
MALINOVKA_YANDEX_OAUTH_CLIENT_ID=malinovka-yandex
MALINOVKA_YANDEX_OAUTH_CLIENT_SECRET=replace-with-long-secret
MALINOVKA_YANDEX_OAUTH_CODE=replace-with-random-code
MALINOVKA_YANDEX_OAUTH_TOKEN=replace-with-random-token
MALINOVKA_YANDEX_USER_ID=your-local-user-id
```

Configure the smart home skill in the [Yandex Dialogs developer console](https://dialogs.yandex.ru/developer/):

- Skill type: smart home.
- Endpoint URL: `https://your-domain.example/v1.0`.
- Authorization URL: `https://your-domain.example/oauth/authorize`.
- Token URL: `https://your-domain.example/oauth/token`.
- Client ID: the value of `MALINOVKA_YANDEX_OAUTH_CLIENT_ID`.
- Client secret: the value of `MALINOVKA_YANDEX_OAUTH_CLIENT_SECRET`.

Current integration exposes each Wi-Fi device as `devices.types.multicooker` with `on_off` control and a temperature property. Alice can query the device state and temperature. The `off` command queues the existing `stop` command for the device; `on` is rejected on purpose because starting an autoclave program should happen only from the Malinovka app with an explicit program choice.

Quick local checks:

```powershell
curl.exe -I http://127.0.0.1:8000/v1.0
curl.exe -H "Authorization: Bearer replace-with-random-token" -H "X-Request-Id: test-1" http://127.0.0.1:8000/v1.0/user/devices
```

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
