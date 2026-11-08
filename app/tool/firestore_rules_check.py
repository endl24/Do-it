"""로컬 Firestore 에뮬레이터에만 접속해 실제 보안 규칙을 검증한다."""

import base64
import json
import os
import urllib.error
import urllib.request


def encoded(value):
    """에뮬레이터 전용 모의 인증 토큰의 JSON 부분을 인코딩한다."""
    return base64.urlsafe_b64encode(json.dumps(value).encode()).decode().rstrip('=')


def token(uid):
    """실제 Firebase에서는 사용할 수 없는 테스트용 무서명 토큰을 만든다."""
    return encoded({'alg': 'none', 'typ': 'JWT'}) + '.' + encoded({
        'sub': uid, 'user_id': uid, 'aud': 'demo-do-it-rules',
        'iss': 'https://securetoken.google.com/demo-do-it-rules',
        'iat': 0, 'exp': 4102444800,
        'firebase': {'sign_in_provider': 'password'},
    }) + '.'


def request(method, uid, owner='user-a', todo='one', data=None, expected=200):
    """로컬 REST 요청 결과가 허용 또는 거부 예상과 일치하는지 검사한다."""
    url = f'http://{HOST}/v1/projects/demo-do-it-rules/databases/(default)/documents/users/{owner}/todos/{todo}'
    headers = {'Content-Type': 'application/json'}
    if uid is not None:
        headers['Authorization'] = 'Bearer ' + token(uid)
    body = None if data is None else json.dumps({'fields': data}).encode()
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            status = response.status
    except urllib.error.HTTPError as error:
        status = error.code
    assert status == expected, f'{method} {owner}/{todo}: expected {expected}, got {status}'


def active(version=10, restored_from=None):
    """필수 필드가 포함된 서버 문서를 만든다."""
    result = {
        'id': {'stringValue': 'one'},
        'title': {'stringValue': 'test todo'},
        'importance': {'stringValue': 'important'},
        'urgency': {'stringValue': 'notUrgent'},
        'is_completed': {'integerValue': '0'},
        'reminder_enabled': {'integerValue': '0'},
        'source': {'stringValue': 'manual'},
        'deleted': {'booleanValue': False},
        'updatedAt': {'timestampValue': f'2026-11-{version:02d}T00:00:00Z'},
        'operationId': {'stringValue': f'operation-{version}'},
    }
    if restored_from is not None:
        result['restoredFrom'] = {'stringValue': restored_from}
    return result


def run():
    """계정 격리·수정 시각 비교·삭제 우선·명시적 실행 취소를 검증한다."""
    request('PATCH', None, data=active(), expected=403)
    request('PATCH', 'user-b', data=active(), expected=403)
    request('PATCH', 'user-a', data=active())
    request('GET', 'user-a')
    request('GET', 'user-b', expected=403)
    request('GET', None, expected=403)
    request('PATCH', 'user-a', data=active(9), expected=403)
    request('PATCH', 'user-a', data=active(11))
    request('DELETE', 'user-a', expected=403)
    # 더 오래된 시각이어도 삭제가 수정보다 우선한다.
    deletion = {
        'id': {'stringValue': 'one'}, 'deleted': {'booleanValue': True},
        'deleteToken': {'stringValue': 'delete-one'},
        'operationId': {'stringValue': 'delete-one'},
        'updatedAt': {'timestampValue': '2026-11-08T00:00:00Z'},
    }
    request('PATCH', 'user-a', data=deletion)
    request('PATCH', 'user-a', data=active(20), expected=403)
    request('PATCH', 'user-a', data=active(20, 'wrong-token'), expected=403)
    request('PATCH', 'user-a', data=active(20, 'delete-one'))
    invalid = active(21)
    invalid['id'] = {'stringValue': 'wrong-id'}
    request('PATCH', 'user-a', data=invalid, expected=403)
    print('Firestore rules: 14 checks passed (local emulator only).')


HOST = os.environ.get('FIRESTORE_EMULATOR_HOST', '')
if not (HOST.startswith('127.0.0.1:') or HOST.startswith('localhost:')):
    raise SystemExit('FIRESTORE_EMULATOR_HOST must point to the local emulator.')

if __name__ == '__main__':
    run()
