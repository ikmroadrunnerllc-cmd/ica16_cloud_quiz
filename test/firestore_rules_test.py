import base64
import json
import os
from pathlib import Path
import time
import unittest
import urllib.error
import urllib.request


PROJECT = 'demo-ica16-local'
HOST = os.environ.get('FIRESTORE_EMULATOR_HOST', '127.0.0.1:8080')
BASE = f'http://{HOST}/v1/projects/{PROJECT}/databases/(default)/documents'


def token(uid):
    def encode(data):
        return base64.urlsafe_b64encode(json.dumps(data).encode()).decode().rstrip('=')
    now = int(time.time())
    claims = {'iss': f'https://securetoken.google.com/{PROJECT}', 'aud': PROJECT,
              'sub': uid, 'user_id': uid, 'iat': now, 'exp': now + 3600,
              'firebase': {'sign_in_provider': 'password'}}
    return encode({'alg': 'none', 'typ': 'JWT'}) + '.' + encode(claims) + '.'


def call(method, path, body=None, uid='alice', admin=False):
    headers = {'Content-Type': 'application/json'}
    if admin:
        headers['Authorization'] = 'Bearer owner'
    elif uid is not None:
        headers['Authorization'] = 'Bearer ' + token(uid)
    request = urllib.request.Request(BASE + path,
                                    data=None if body is None else json.dumps(body).encode(),
                                    headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.loads(error.read())


def fields(score=7):
    return {'schemaVersion': {'integerValue': '1'}, 'variant': {'stringValue': 'A'},
            'categoryId': {'integerValue': '9'}, 'questionCount': {'integerValue': '10'},
            'correctCount': {'integerValue': str(score)}}


def create(round_id, changes=None, uid='alice', owner='alice', admin=False, omit=None):
    data = fields()
    if changes:
        data.update(changes)
    if omit:
        for key in omit:
            data.pop(key, None)
    name = f'projects/{PROJECT}/databases/(default)/documents/users/{owner}/attempts/{round_id}'
    write = {'update': {'name': name, 'fields': data},
             'currentDocument': {'exists': False},
             'updateTransforms': [{'fieldPath': 'submittedAt', 'setToServerValue': 'REQUEST_TIME'}]}
    return call('POST', ':commit', {'writes': [write]}, uid=uid, admin=admin)


class RulesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not os.environ.get('FIRESTORE_EMULATOR_HOST'):
            raise RuntimeError('Run this test through the Firebase Firestore emulator.')
        cls.prefix = str(time.time_ns())

    def name(self, suffix):
        return self.prefix + suffix

    def test_owner_can_read_missing_document_for_transaction(self):
        code, _ = call('GET', '/users/alice/attempts/' + self.name('missing'))
        self.assertEqual(code, 404)

    def test_owner_can_create_then_read_at_a_later_time(self):
        name = self.name('valid')
        self.assertEqual(create(name)[0], 200)
        time.sleep(0.05)
        code, data = call('GET', '/users/alice/attempts/' + name)
        self.assertEqual(code, 200, data)
        self.assertIn('timestampValue', data['fields']['submittedAt'])

    def test_other_user_and_unauthenticated_access_denied(self):
        name = self.name('private')
        self.assertEqual(create(name)[0], 200)
        for uid in ['bob', None]:
            self.assertEqual(call('GET', '/users/alice/attempts/' + name, uid=uid)[0], 403)
            self.assertEqual(create(self.name(str(uid)), uid=uid)[0], 403)
        self.assertEqual(call('GET', '/users/alice/attempts/' + self.name('absent'), uid='bob')[0], 403)

    def test_invalid_fields_types_ranges_and_schema_are_denied(self):
        cases = [
            {'correctCount': {'integerValue': '11'}},
            {'correctCount': {'integerValue': '-1'}},
            {'correctCount': {'stringValue': '7'}},
            {'correctCount': {'doubleValue': 7.5}},
            {'extra': {'booleanValue': True}},
            {'variant': {'stringValue': 'B'}},
            {'categoryId': {'integerValue': '10'}},
            {'questionCount': {'integerValue': '9'}},
            {'schemaVersion': {'integerValue': '2'}},
        ]
        for index, changes in enumerate(cases):
            with self.subTest(changes=changes):
                self.assertEqual(create(self.name('invalid' + str(index)), changes)[0], 403)

    def test_update_and_delete_are_denied(self):
        name = self.name('immutable')
        self.assertEqual(create(name)[0], 200)
        path = '/users/alice/attempts/' + name
        self.assertEqual(call('PATCH', path, {'fields': fields(8)})[0], 403)
        self.assertEqual(call('DELETE', path)[0], 403)

    def test_invalid_admin_seeded_document_cannot_be_read_by_client(self):
        name = self.name('admin-invalid')
        self.assertEqual(create(name, {'correctCount': {'integerValue': '11'}}, admin=True)[0], 200)
        self.assertEqual(call('GET', '/users/alice/attempts/' + name)[0], 403)

    def test_list_and_unknown_paths_are_denied(self):
        self.assertEqual(call('GET', '/users/alice/attempts')[0], 403)
        self.assertEqual(call('GET', '/other/' + self.name('path'))[0], 403)

    def test_missing_fields_and_forged_timestamp_are_denied(self):
        for missing in ['variant', 'correctCount', 'questionCount']:
            self.assertEqual(create(self.name('missing-' + missing), omit=[missing])[0], 403)
        data = fields()
        data['submittedAt'] = {'timestampValue': '2020-01-01T00:00:00Z'}
        self.assertEqual(call('PATCH', '/users/alice/attempts/' + self.name('past'), {'fields': data})[0], 403)


if __name__ == '__main__':
    unittest.main(verbosity=2)
