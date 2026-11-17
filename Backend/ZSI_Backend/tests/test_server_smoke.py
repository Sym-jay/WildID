"""
End-to-end smoke test of the API server (api_extended:app) with a randomly
initialised model of the real shape. Checks wiring, auth and contracts, not
identification accuracy.

Needs the server dependencies (pip install -r requirements-server.txt);
skipped automatically when torch is not installed.
"""

import importlib
import io
import os
import sys
import tempfile
import unittest

try:
    import torch
    import torch.nn as nn
    from PIL import Image
    from torchvision import models
except ImportError:  # pragma: no cover - lightweight environments
    torch = None

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API_KEY = 'test-api-key-0123456789'


@unittest.skipIf(torch is None, 'server dependencies not installed')
class ServerSmokeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()

        # Same architecture as api.ZSIWildlifeClassifier, random weights.
        class Classifier(nn.Module):
            def __init__(self, num_classes):
                super().__init__()
                self.backbone = models.efficientnet_b0(weights=None)
                n = self.backbone.classifier[1].in_features
                self.backbone.classifier = nn.Sequential(nn.Dropout(0.4), nn.Linear(n, num_classes))

        weights = os.path.join(cls.tmp.name, 'zsi_wildlife_model.pth')
        torch.save(Classifier(66).state_dict(), weights)

        os.environ.update({
            'ZSI_API_KEY': API_KEY,
            'ZSI_OTP_SECRET': 'otp-secret-for-tests-0123456789',
            'ZSI_OTP_DEV_ECHO': '1',
            'ZSI_MODEL_PATH': weights,
            'ZSI_ENSEMBLE_DIR': os.path.join(cls.tmp.name, 'no-ensemble'),
        })
        sys.path.insert(0, HERE)
        for name in ('api_extended', 'api'):
            sys.modules.pop(name, None)
        cls.server = importlib.import_module('api_extended')
        cls.client = cls.server.app.test_client()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def _jpeg(self):
        buf = io.BytesIO()
        Image.new('RGB', (320, 240), (40, 90, 120)).save(buf, format='JPEG')
        buf.seek(0)
        return buf

    def _post_photo(self, path, key=API_KEY, name='photo.jpg', data=None):
        headers = {'X-API-Key': key} if key is not None else {}
        return self.client.post(
            path,
            headers=headers,
            data={'file': (data or self._jpeg(), name)},
            content_type='multipart/form-data',
        )

    def test_health_is_public(self):
        r = self.client.get('/health')
        self.assertEqual(r.status_code, 200)
        body = r.get_json()
        self.assertEqual(body['species_count'], 66)
        self.assertFalse(body['ensemble_available'])

    def test_predict_requires_the_key(self):
        self.assertEqual(self._post_photo('/predict', key=None).status_code, 401)
        self.assertEqual(self._post_photo('/predict', key='wrong').status_code, 401)

    def test_predict_returns_labels_and_confidence(self):
        r = self._post_photo('/predict')
        self.assertEqual(r.status_code, 200)
        body = r.get_json()
        # The app's PredictionParser reads {"predictions": [...]} (or a bare list).
        results = body['predictions'] if isinstance(body, dict) else body
        self.assertGreaterEqual(len(results), 1)
        for item in results:
            self.assertIsInstance(item['label'], str)
            self.assertTrue(0.0 <= float(item['confidence']) <= 1.0)

    def test_predict_rejects_non_images(self):
        r = self._post_photo('/predict', name='notes.txt', data=io.BytesIO(b'hello'))
        self.assertEqual(r.status_code, 400)

    def test_missing_ensemble_answers_503_so_the_app_falls_back(self):
        self.assertEqual(self._post_photo('/predict-ensemble').status_code, 503)

    def test_otp_round_trip(self):
        h = {'X-API-Key': API_KEY}
        r = self.client.post('/api/auth/otp/request', headers=h, json={'phone': '98765 43210'})
        self.assertEqual(r.status_code, 200)
        body = r.get_json()
        token, code = body['otp_token'], body['dev_otp']
        self.assertNotIn(code, token)

        wrong = '000000' if code != '000000' else '111111'
        bad = self.client.post('/api/auth/otp/verify', headers=h,
                               json={'phone': '9876543210', 'otp': wrong, 'otp_token': token})
        self.assertEqual(bad.status_code, 401)

        ok = self.client.post('/api/auth/otp/verify', headers=h,
                              json={'phone': '+91 98765 43210', 'otp': code, 'otp_token': token})
        self.assertEqual(ok.status_code, 200)
        self.assertTrue(ok.get_json()['verified'])

        again = self.client.post('/api/auth/otp/verify', headers=h,
                                 json={'phone': '9876543210', 'otp': code, 'otp_token': token})
        self.assertEqual(again.status_code, 401, 'codes are single use')

    def test_otp_rejects_bad_numbers(self):
        r = self.client.post('/api/auth/otp/request', headers={'X-API-Key': API_KEY},
                             json={'phone': '12345'})
        self.assertEqual(r.status_code, 400)


if __name__ == '__main__':
    unittest.main()
