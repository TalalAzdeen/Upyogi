import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProviderDemoPlan {
  const ProviderDemoPlan(this.id, this.name, this.price, this.services, this.photos, this.radiusKm);
  final String id;
  final String name;
  final int price;
  final int services;
  final int photos;
  final int radiusKm;
}

class ProviderDemoBooking {
  const ProviderDemoBooking({required this.id, required this.title, required this.customer,
    required this.appointment, required this.amount, required this.status});
  final int id;
  final String title;
  final String customer;
  final DateTime appointment;
  final int amount;
  final String status;
  ProviderDemoBooking withStatus(String value) => ProviderDemoBooking(id:id,title:title,
    customer:customer,appointment:appointment,amount:amount,status:value);
  Map<String,dynamic> toJson() => {'id':id,'title':title,'customer':customer,
    'appointment':appointment.toIso8601String(),'amount':amount,'status':status};
  factory ProviderDemoBooking.fromJson(Map<String,dynamic> value) => ProviderDemoBooking(
    id:value['id'] as int,title:value['title'] as String,customer:value['customer'] as String,
    appointment:DateTime.parse(value['appointment'] as String),amount:value['amount'] as int,status:value['status'] as String);
}

/// A local simulation only. Never writes authentication keys or calls an API.
class ProviderDemoStore {
  ProviderDemoStore._(this._prefs);
  static const key = 'sulh_provider_demo_v1';
  static const plans = [
    ProviderDemoPlan('start','Start',100,3,6,15),
    ProviderDemoPlan('growth','Growth',200,10,20,30),
    ProviderDemoPlan('pro','Professional',300,25,50,60),
  ];
  final SharedPreferences _prefs;
  bool active = false;
  String stage = 'welcome';
  String name = '';
  String specialty = 'Plumber';
  bool acknowledged = false;
  DateTime? acknowledgedAt;
  String? planId;
  DateTime? subscriptionUntil;
  bool available = false;
  DateTime? locationUpdatedAt;
  int locationStep = 0;
  List<ProviderDemoBooking> bookings = [];
  List<String> notices = [];
  ProviderDemoPlan? get plan {
    for (final p in plans) { if (p.id == planId) return p; }
    return null;
  }

  static Future<ProviderDemoStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = ProviderDemoStore._(prefs);
    try {
      final raw = prefs.getString(key);
      if (raw == null) return store;
      final d = jsonDecode(raw) as Map<String,dynamic>;
      store.active=d['active']==true;
      store.stage=d['stage'] as String;
      store.name=d['name'] as String? ?? '';
      store.specialty=d['specialty'] as String? ?? 'Plumber';
      store.acknowledged=d['acknowledged']==true;
      store.acknowledgedAt=DateTime.tryParse(d['acknowledgedAt'] as String? ?? '');
      store.planId=d['planId'] as String?;
      store.subscriptionUntil=DateTime.tryParse(d['subscriptionUntil'] as String? ?? '');
      store.available=d['available']==true;
      store.locationUpdatedAt=DateTime.tryParse(d['locationUpdatedAt'] as String? ?? '');
      store.locationStep=d['locationStep'] as int? ?? 0;
      store.bookings=(d['bookings'] as List? ?? []).map((v)=>ProviderDemoBooking.fromJson(Map<String,dynamic>.from(v))).toList();
      store.notices=List<String>.from(d['notices'] as List? ?? []);
      if (!['welcome','registration','plans','dashboard'].contains(store.stage)) store.stage='welcome';
      if (store.stage=='dashboard' && (store.plan==null || !store.acknowledged)) store.stage='plans';
      return store;
    } catch (_) { return ProviderDemoStore._(prefs); }
  }

  Future<void> _save() async {
    final saved=await _prefs.setString(key,jsonEncode({'version':1,'active':active,'stage':stage,
      'name':name,'specialty':specialty,'acknowledged':acknowledged,'acknowledgedAt':acknowledgedAt?.toIso8601String(),
      'declarationVersion':'demo-v1','planId':planId,'subscriptionUntil':subscriptionUntil?.toIso8601String(),
      'available':available,'locationUpdatedAt':locationUpdatedAt?.toIso8601String(),'locationStep':locationStep,
      'bookings':bookings.map((b)=>b.toJson()).toList(),'notices':notices}));
    if (!saved) throw StateError('Unable to save demo progress.');
  }
  Future<void> begin() async { active=true; stage='registration'; await _save(); }
  Future<void> register({required String name,required String specialty,required bool acknowledged}) async {
    if (!acknowledged) throw StateError('Accept the demo declaration to continue.');
    if (name.trim().isEmpty || !['Plumber','Electrician','AC Repair','Cleaning','Carpenter','Painter'].contains(specialty)) throw ArgumentError('Invalid demo profile');
    this.name=name.trim(); this.specialty=specialty; this.acknowledged=true;
    acknowledgedAt=DateTime.now(); active=true; stage='plans'; planId=null;
    if (bookings.isEmpty) {
      final tomorrow=DateTime.now().add(const Duration(days:1));
      final date=DateTime(tomorrow.year,tomorrow.month,tomorrow.day,10);
      bookings=[
        ProviderDemoBooking(id:101,title:'Kitchen tap repair',customer:'Demo customer 1',appointment:date,amount:120,status:'Requested'),
        ProviderDemoBooking(id:102,title:'Home maintenance',customer:'Demo customer 2',appointment:date.add(const Duration(hours:3)),amount:180,status:'Accepted'),
        ProviderDemoBooking(id:103,title:'Water leak inspection',customer:'Demo customer 3',appointment:date.add(const Duration(days:1)),amount:95,status:'Requested'),
        ProviderDemoBooking(id:104,title:'Completed demo service',customer:'Demo customer 4',appointment:date.subtract(const Duration(days:2)),amount:150,status:'Completed'),
        ProviderDemoBooking(id:105,title:'Rejected demo request',customer:'Demo customer 5',appointment:date.subtract(const Duration(days:1)),amount:100,status:'Rejected'),
      ];
    }
    notices.insert(0,'Demo registration complete. Email verification was skipped.');
    await _save();
  }
  Future<void> chooseAgain() async { stage='plans'; await _save(); }
  Future<void> activatePlan(String id) async {
    if (!plans.any((p)=>p.id==id)) throw ArgumentError('Unknown plan');
    if (!acknowledged || name.isEmpty) throw StateError('Complete demo registration first.');
    planId=id; subscriptionUntil=_nextMonth(DateTime.now()); stage='dashboard'; active=true;
    notices.insert(0,'Demo package activated. No payment was collected.');
    await _save();
  }
  static DateTime _nextMonth(DateTime date) {
    final last=DateTime(date.year,date.month+2,0).day;
    return DateTime(date.year,date.month+1,date.day>last?last:date.day,date.hour,date.minute);
  }
  Future<void> renew() async {
    if (plan==null || subscriptionUntil==null) throw StateError('Choose a package first.');
    final now=DateTime.now();
    subscriptionUntil=_nextMonth(subscriptionUntil!.isAfter(now)?subscriptionUntil!:now);
    notices.insert(0,'Demo subscription renewed. No payment was collected.');await _save();
  }
  Future<void> advanceBooking(int id,String next) async {
    final index=bookings.indexWhere((b)=>b.id==id);
    if(index<0) throw StateError('Unknown demo booking');
    final current=bookings[index].status;
    const allowed={'Requested':['Accepted','Rejected'],'Accepted':['OnTheWay'],'OnTheWay':['InProgress'],'InProgress':['Completed']};
    if(!(allowed[current]?.contains(next) ?? false)) throw StateError('Invalid demo transition');
    bookings[index]=bookings[index].withStatus(next);
    notices.insert(0,'Demo booking status updated.');await _save();
  }
  Future<void> setAvailable(bool value) async { available=value;await _save(); }
  Future<void> simulateLocation() async {
    if(!available) throw StateError('Enable demo availability first.');
    locationStep++;locationUpdatedAt=DateTime.now();await _save();
  }
  Future<void> simulateReminder() async {
    if(!bookings.any((b)=>['Accepted','OnTheWay','InProgress'].contains(b.status))) throw StateError('No accepted demo appointment');
    notices.insert(0,'Demo reminder: your appointment starts in 30 minutes.');await _save();
  }
  Future<void> exit() async { active=false;available=false;await _save(); }
  Future<void> resume() async { active=true;await _save(); }
}
