"""Integration checks for isolated, confirmed fixture users; never charges a card."""
import os, json, urllib.request, urllib.error
from datetime import datetime, timedelta, timezone
BASE = os.getenv('UPYOGI_TEST_API', 'https://prsyiadiplvumfjesfdf.supabase.co/functions/v1/upyogi-api')
PASSWORD = os.environ['UPYOGI_TEST_PASSWORD']
count = 0

def call(path, method='GET', data=None, token=None, expected=200):
    global count
    headers = {'Content-Type': 'application/json'}
    if token: headers['Authorization'] = 'Bearer ' + token
    req = urllib.request.Request(BASE + path, data=None if data is None else json.dumps(data).encode(), headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=45) as r: status, body = r.status, json.load(r)
    except urllib.error.HTTPError as e: status, body = e.code, json.loads(e.read())
    assert status == expected, (path, status, body)
    count += 1
    print('PASS', count, method, path, status, flush=True)
    return body

call('/health')
call('/api/Auth/register', 'POST', {'fullName':'','email':'invalid','password':'x','role':'Admin'}, expected=400)
call('/api/Auth/login', 'POST', {'email':'upyogi-e2e-customer@example.invalid','password':'incorrect'}, expected=401)
tokens = {}
for role in ('customer','provider','outsider'):
    data = call('/api/Auth/login', 'POST', {'email':f'upyogi-e2e-{role}@example.invalid','password':PASSWORD})
    tokens[role] = data['token']
    assert data['user']['role'] == ('Provider' if role == 'provider' else 'Customer')
    if role == 'customer':
        renewed = call('/api/Auth/refresh','POST',{'refreshToken':data['refreshToken']})
        tokens[role] = renewed['token']
c, p, o = (tokens[k] for k in ('customer','provider','outsider'))
call('/api/Auth/me', token=c)
call('/api/Wallet', expected=401)
w = call('/api/Wallet', token=c)
assert w['currency'] == 'sar' and w['balanceMinor'] == 0
call('/api/Wallet/topup','POST',{'amountMinor':-1,'requestId':'invalid'},c,400)
call('/api/Wallet/topup','POST',{'amountMinor':1000,'requestId':'00000000-0000-4000-8000-000000000001'},c,503)
call('/api/Service','POST',{'title':'Forbidden','startingPrice':10},c,403)
s = call('/api/Service','POST',{'title':'E2E test service','category':'Test','startingPrice':25,'providerName':'Test Provider'},p)
sid = s['id']
call(f'/api/Service/{sid}')
call(f'/api/Service/{sid}', 'PUT', {'title':'Hijack','startingPrice':1},o,403)
appointment = (datetime.now(timezone.utc)+timedelta(days=1)).isoformat()
b = call('/api/Booking','POST',{'serviceId':sid,'appointmentDate':appointment,'appointmentTime':'10:00','serviceAddress':'Test address','customerPhone':'0000000000'},c)
bid = b['id']
assert b['amount'] == 25 and b['paymentStatus'] == 'Pending'
call(f'/api/Booking/{bid}/accept','PUT',{},o,404)
call(f'/api/Payment/confirm/{bid}','POST',{},o,404)
call(f'/api/Payment/confirm/{bid}','POST',{},c,409)
assert call('/api/Booking/customer',token=o) == []
call(f'/api/Booking/{bid}/accept','PUT',{},p)
call(f'/api/Booking/{bid}/complete','PUT',{},p,409)
call(f'/api/Booking/{bid}/accept','PUT',{},p,409)
assert any(n['relatedId'] == bid for n in call('/api/Notification',token=p))
call('/api/Notification/mark-all-read','PUT',{},p)
assert call('/api/Notification/unread-count',token=p)['count'] == 0
call('/api/Review','POST',{'bookingId':bid,'rating':5},c,400)
call('/stripe-webhook','POST',{},expected=503)
print(f'{count} live checks passed; no payment attempted.', flush=True)
