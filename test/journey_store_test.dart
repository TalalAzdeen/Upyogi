import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:service_app/services/journey_store.dart';

void main() {
  final now = DateTime(2030, 1, 10, 9);
  Future<JourneyStore> load() => JourneyStore.load(clock: () => now);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<int> request(JourneyStore s, {int serviceId = 1, DateTime? at}) async {
    await s.registerCustomer('Test customer');
    return (await s.book(serviceId: serviceId, appointment: at ?? now.add(const Duration(days: 1)),
      address: 'Demo street 12', phone: '0500000000', notes: 'Test note')).id;
  }
  test('catalog has 24 services; Arabic, city, category, favorites and sort work offline', () async {
    final s = await load();
    expect(s.search().length, 24);
    expect(s.search(query: 'سِبَاكَة').length, 3);
    expect(s.search(city: 'Jeddah').length, 8);
    expect(s.search(category: 'Electrician', city: 'Riyadh').length, 1);
    final sorted = s.search(sort: 'price');
    expect(sorted.first.price <= sorted.last.price, true);
    await s.toggleFavorite(1);
    expect((await load()).search(favoritesOnly: true).single.id, 1);
    expect(s.search(query: 'nonexistent'), isEmpty);
  });
  test('complete cross-role lifecycle persists payment and one review without real auth', () async {
    final s = await load(); final id = await request(s);
    for (final pair in [('Requested','Accepted'),('Accepted','OnTheWay'),('OnTheWay','InProgress'),('InProgress','Completed')]) {
      await s.transition(id, expected: pair.$1, next: pair.$2, actor: 'Provider');
    }
    await s.settle(id, 'Skipped');
    await s.rate(id, 5, 'Excellent demo');
    final restored = await load(); final b = restored.booking(id);
    expect(b.status, 'Completed'); expect(b.payment, 'Skipped'); expect(b.rating, 5);
    expect(b.history.length, 5); expect(restored.noticesFor('Provider').isNotEmpty, true);
    await expectLater(s.rate(id, 3, ''), throwsStateError);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), isNull); expect(prefs.getString('role'), isNull);
  });
  test('stale transitions, unauthorized actor, early payment and duplicate slot are rejected', () async {
    final s = await load(); final id = await request(s); final stale = await load();
    await expectLater(s.settle(id, 'CashSimulated'), throwsStateError);
    await expectLater(s.rate(id, 5, ''), throwsStateError);
    await expectLater(s.transition(id,expected:'Requested',next:'Accepted',actor:'Customer'),throwsStateError);
    await s.transition(id,expected:'Requested',next:'Accepted',actor:'Provider');
    await expectLater(stale.transition(id,expected:'Requested',next:'Rejected',actor:'Provider'),throwsStateError);
    await expectLater(request(stale), throwsStateError);
    expect((await load()).booking(id).status, 'Accepted');
  });
  test('reschedule then cancel frees slot and retains immutable price snapshot', () async {
    final s = await load(); final id = await request(s); final oldPrice = s.booking(id).amount;
    await s.reschedule(id, now.add(const Duration(days: 2)));
    expect(s.booking(id).appointment.day, 12);
    await s.transition(id,expected:'Requested',next:'Cancelled',actor:'Customer');
    expect((await request(s)).isNegative, false);
    expect(s.booking(id).amount, oldPrice);
    await expectLater(s.reschedule(id,now.add(const Duration(days: 3))),throwsStateError);
    await expectLater(s.book(serviceId:1,appointment:now,address:'x',phone:'x',notes:''),throwsArgumentError);
  });
  test('package service limit, validation, availability and past history are enforced', () async {
    final s = await load();
    for (var i=0;i<3;i++) { await s.saveService(title:'My repair $i', category:'Plumber', city:'Riyadh', price:100, limit:3); }
    await expectLater(s.saveService(title:'Fourth',category:'Plumber',city:'Riyadh',price:100,limit:3),throwsStateError);
    final owned = s.services.where((e)=>e.owned).first;
    final id = await request(s,serviceId:owned.id); final oldPrice = s.booking(id).amount;
    await s.saveService(id:owned.id,title:'Changed',category:'Plumber',city:'Riyadh',price:200,limit:3);
    await s.setServiceActive(owned.id,false);
    expect(s.search().any((e)=>e.id==owned.id), false); expect(s.booking(id).amount,oldPrice);
    await expectLater(request(s,serviceId:owned.id,at:now.add(const Duration(days:3))),throwsStateError);
    await expectLater(s.saveService(title:'Bad',category:'Plumber',city:'Riyadh',price:double.nan,limit:3),throwsArgumentError);
  });
  test('due reminders are accepted appointments only, never duplicated or late', () async {
    final s = await load(); final id = await request(s,at:now.add(const Duration(minutes:20)));
    await s.dueReminders(); expect(s.notices.where((n)=>n.kind=='reminder'),isEmpty);
    await s.transition(id,expected:'Requested',next:'Accepted',actor:'Provider');
    await s.dueReminders(); await (await load()).dueReminders();
    expect((await load()).notices.where((n)=>n.kind=='reminder').length,2);
    await s.markRead('Customer'); expect(s.noticesFor('Customer').every((n)=>n.read), true);
  });
  test('roles restore locally while leaving and invalid saved data do not mutate auth', () async {
    final s=await load(); await s.registerCustomer('Demo'); await s.selectRole('Customer');
    expect((await load()).activeRole,'Customer');
    await s.leave(); expect((await load()).activeRole,isNull);
    final prefs=await SharedPreferences.getInstance(); await prefs.setString('token','real');
    await prefs.setString(JourneyStore.key,'broken');
    expect((await load()).services.length,24); expect(prefs.getString('token'),'real');
  });
}
