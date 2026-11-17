# Model weights

The trained weights are not stored in git (`*.pth` is ignored). Copy them here
before running the server or building the Docker image:

| File | Needed for |
|---|---|
| `zsi_wildlife_model.pth` | `/predict` (required — the server will not start without it) |
| `ensemble/model_efficientnet_b0_v3.pth` | `/predict-ensemble` (optional) |
| `ensemble/model_resnet50_v3.pth` | ensemble, optional |
| `ensemble/model_mobilenet_v3_v3.pth` | ensemble, optional |

Without the ensemble files the server answers `/predict-ensemble` with 503 and
the app automatically uses `/predict`.

To run from elsewhere, set `ZSI_MODEL_PATH` and `ZSI_ENSEMBLE_DIR` instead.
