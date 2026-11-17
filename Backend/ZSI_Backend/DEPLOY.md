# Deploying the WildID API to Cloud Run

The app talks to `https://zsi-wildlife-api-173142698667.us-central1.run.app`
(service `zsi-wildlife-api`, region `us-central1`). These steps redeploy that
service with the current code: the single-model `/predict`, the optional
`/predict-ensemble`, and the server-side OTP sign-in.

## 1. Put the model weights in place

The weights are not in git. Copy them into `Backend/ZSI_Backend/models/`
(see `models/README.md`):

```
models/zsi_wildlife_model.pth              required
models/ensemble/model_efficientnet_b0_v3.pth   optional
models/ensemble/model_resnet50_v3.pth          optional
models/ensemble/model_mobilenet_v3_v3.pth      optional
```

If you only have them in the currently deployed image, pull that image and
copy `/app/zsi_wildlife_model.pth` out of it.

## 2. Create the secrets (once)

Use two different long random values. The API key is built into the app; the
OTP secret must never leave the server.

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"   # run twice

printf '%s' '<api key>'    | gcloud secrets create zsi-api-key    --data-file=-
printf '%s' '<otp secret>' | gcloud secrets create zsi-otp-secret --data-file=-
```

Give the Cloud Run service account access to both secrets
(`roles/secretmanager.secretAccessor`).

## 3. Build and deploy

From `Backend/ZSI_Backend`:

```bash
gcloud run deploy zsi-wildlife-api \
  --source . \
  --region us-central1 \
  --memory 2Gi --cpu 2 \
  --concurrency 4 \
  --set-secrets ZSI_API_KEY=zsi-api-key:latest,ZSI_OTP_SECRET=zsi-otp-secret:latest \
  --set-env-vars SMS_PROVIDER=goi
```

Add the SMS gateway credentials as secrets too when you have them
(`SMS_API_KEY`, or `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` /
`TWILIO_PHONE_NUMBER` with `SMS_PROVIDER=twilio`). Without them, OTP requests
return 503 ("Could not send SMS") rather than pretending to send.
Never set `ZSI_OTP_DEV_ECHO` on Cloud Run.

## 4. Check it

```bash
curl https://zsi-wildlife-api-173142698667.us-central1.run.app/health
curl -H "X-API-Key: <api key>" -F "file=@photo.jpg" \
  https://zsi-wildlife-api-173142698667.us-central1.run.app/predict
```

`/health` should report `"species_count": 66` and whether the ensemble loaded.

## 5. Build the app with the key

```bash
cd Frontend/ZSI_Frontend
flutter build apk --release --dart-define=ZSI_API_KEY=<api key>
```

## Run locally

```bash
python -m venv venv && venv/Scripts/activate       # or source venv/bin/activate
pip install -r requirements-server.txt
set ZSI_API_KEY=... & set ZSI_OTP_SECRET=... & set ZSI_OTP_DEV_ECHO=1
python api_extended.py                             # http://localhost:5000
python -m unittest discover -s tests               # includes the server smoke test
```

Point the app at it with `--dart-define=ZSI_API_BASE_URL=http://10.0.2.2:5000`
(Android emulator) and the same `ZSI_API_KEY`.
