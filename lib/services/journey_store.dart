import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journey_models.dart';
export '../models/journey_models.dart';

/// Local, explicitly labelled simulation. Never calls Auth, payments, GPS or an API.
class JourneyStore {
  JourneyStore._(this._prefs,this._clock);
  static const key='sulh_connected_journey_v1';
  static const categories=['Plumber','Electrician','AC Repair','Cleaning','Carpenter','Painter','Appliance Repair','Pest Control'];
  static const cities=['Riyadh','Jeddah','Dammam'];
  // Bind serialization to the persistence instance, rather than retaining an
  // asynchronous zone from a replaced storage instance (e.g. a new test host).
  static final _queues=Expando<_JourneyWriteQueue>();
  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  List<JourneyService> _services=[];
  List<JourneyBooking> _bookings=[];
  List<JourneyNotice> _notices=[];
  Set<int> _favorites={};
  Set<String> _reminded={};
  String customerName='';
  String? activeRole;
  int _nextId=1000;
  List<JourneyService> get services=>List.unmodifiable(_services);
  List<JourneyBooking> get bookings=>List.unmodifiable(_bookings);
  List<JourneyNotice> get notices=>List.unmodifiable(_notices);
  bool isFavorite(int id)=>_favorites.contains(id);
  static Future<JourneyStore> load({DateTime Function()? clock})async{
    final s=JourneyStore._(await SharedPreferences.getInstance(),clock??DateTime.now);s._read();return s;
  }
  void _seed(){
    customerName='';activeRole=null;_bookings=[];_notices=[];_favorites={};_reminded={};_nextId=1000;
    const titles=['Kitchen tap repair','Electrical maintenance','AC maintenance','Home cleaning','Furniture repair','Room painting','Appliance inspection','Pest treatment'];
    _services=[for(var c=0;c<3;c++)for(var n=0;n<8;n++)JourneyService(id:c*8+n+1,
      title:titles[n],category:categories[n],city:cities[c],price:(75+n*20+c*10).toDouble())];
  }
  void _read(){
    _seed();
    try{
      final raw=_prefs.getString(key);if(raw==null)return;
      final j=jsonDecode(raw) as Map<String,dynamic>;
      if(j['version']!=1)throw const FormatException('Unknown simulation version');
      _services=(j['services'] as List).map((v)=>JourneyService.fromJson(Map<String,dynamic>.from(v))).toList();
      _bookings=(j['bookings'] as List).map((v)=>JourneyBooking.fromJson(Map<String,dynamic>.from(v))).toList();
      _notices=(j['notices'] as List).map((v)=>JourneyNotice.fromJson(Map<String,dynamic>.from(v))).toList();
      _favorites=Set<int>.from(j['favorites'] as List);_reminded=Set<String>.from(j['reminded'] as List);
      customerName=j['customerName'] as String;activeRole=j['activeRole'] as String?;_nextId=j['nextId'] as int;
      if(activeRole!=null&&!['Customer','Provider'].contains(activeRole))activeRole=null;
    }catch(_){_seed();}
  }
  Map<String,dynamic> _json()=>{'version':1,'services':_services.map((s)=>s.toJson()).toList(),
    'bookings':_bookings.map((b)=>b.toJson()).toList(),'notices':_notices.map((n)=>n.toJson()).toList(),
    'favorites':_favorites.toList(),'reminded':_reminded.toList(),'customerName':customerName,'activeRole':activeRole,'nextId':_nextId};
  Future<T> _write<T>(T Function() action){
    final result=Completer<T>();
    final queue=_queues[_prefs]??(_queues[_prefs]=_JourneyWriteQueue());
    queue.tail=queue.tail.then((_)async{
      _read();
      try{final value=action();if(!await _prefs.setString(key,jsonEncode(_json())))throw StateError('Unable to save demo progress. Try again.');result.complete(value);}
      catch(e,st){_read();result.completeError(e,st);}
    });return result.future;
  }
  static String _norm(String s)=>s.toLowerCase().replaceAll(RegExp(r'[\u064b-\u065f\u0670\u0640]'),'')
    .replaceAll(RegExp('[أإآ]'),'ا').replaceAll('ى','ي').replaceAll('ة','ه').trim();
  List<JourneyService> search({String query='',String city='All',String category='All',String sort='default',bool favoritesOnly=false}){
    const aliases={'Plumber':'سباكة سباك','Electrician':'كهربائي كهرباء','AC Repair':'تكييف مكيف','Cleaning':'تنظيف نظافة',
      'Carpenter':'نجارة نجار','Painter':'دهان صباغ','Appliance Repair':'اصلاح اجهزة','Pest Control':'مكافحة حشرات',
      'Riyadh':'الرياض','Jeddah':'جدة','Dammam':'الدمام'};
    final q=_norm(query);final list=_services.where((s)=>s.active&&(city=='All'||s.city==city)&&(category=='All'||s.category==category)&&
      (!favoritesOnly||_favorites.contains(s.id))&&_norm('${s.title} ${s.category} ${s.city} ${aliases[s.category]??''} ${aliases[s.city]??''}').contains(q)).toList();
    if(sort=='price')list.sort((a,b)=>a.price.compareTo(b.price));
    if(sort=='rating')list.sort((a,b)=>ratingFor(b.id).compareTo(ratingFor(a.id)));
    return list;
  }
  double ratingFor(int serviceId){final rated=_bookings.where((b)=>b.serviceId==serviceId&&b.rating!=null).toList();
    return rated.isEmpty?0:rated.fold<int>(0,(n,b)=>n+b.rating!)/rated.length;}
  Future<void> registerCustomer(String name)=>_write((){if(name.trim().isEmpty||name.trim().length>80)throw ArgumentError('Please enter your name');customerName=name.trim();activeRole='Customer';});
  Future<void> selectRole(String role)=>_write((){if(!['Customer','Provider'].contains(role))throw ArgumentError('Invalid role');activeRole=role;});
  Future<void> leave()=>_write(()=>activeRole=null);
  Future<void> toggleFavorite(int id)=>_write((){service(id);if(!_favorites.remove(id))_favorites.add(id);});
  JourneyService service(int id)=>_services.firstWhere((s)=>s.id==id,orElse:()=>throw StateError('Service not found'));
  JourneyBooking booking(int id)=>_bookings.firstWhere((b)=>b.id==id,orElse:()=>throw StateError('Booking not found'));
  void _future(DateTime date){if(!date.isAfter(_clock())||date.isAfter(_clock().add(const Duration(days:365))))throw ArgumentError('Choose a future appointment within one year.');}
  void _slot(String city,DateTime date,{int? exclude}){if(_bookings.any((b)=>b.id!=exclude&&!b.terminal&&b.city==city&&b.appointment.difference(date).inMinutes.abs()<60))throw StateError('This demo appointment is already reserved. Choose another time.');}
  Future<JourneyBooking> book({required int serviceId,required DateTime appointment,required String address,required String phone,required String notes})=>_write((){
    _future(appointment);if(customerName.isEmpty||address.trim().length<5||address.length>240||notes.length>500||!RegExp(r'^(?:0|\+?966)?5\d{8}$').hasMatch(phone.trim()))throw ArgumentError('Enter a name, address and valid Saudi mobile number.');
    final s=service(serviceId);if(!s.active)throw StateError('This service is unavailable.');_slot(s.city,appointment);
    final b=JourneyBooking(id:_nextId++,serviceId:s.id,title:s.title,category:s.category,city:s.city,customer:customerName,
      address:address.trim(),phone:phone.trim(),notes:notes.trim(),appointment:appointment,amount:s.price,
      history:[{'status':'Requested','at':_clock().toIso8601String()}]);
    _bookings.insert(0,b);_notify(b.id,'New demo booking');return b;
  });
  void _replace(JourneyBooking b,Map<String,dynamic> patch){final i=_bookings.indexWhere((v)=>v.id==b.id);_bookings[i]=JourneyBooking.fromJson({...b.toJson(),...patch});}
  void _notify(int id,String title,{String kind='booking'}){for(final role in ['Customer','Provider'])_notices.insert(0,JourneyNotice(id:_nextId++,role:role,title:title,kind:kind,bookingId:id,at:_clock()));}
  Future<void> transition(int id,{required String expected,required String next,required String actor})=>_write((){
    final b=booking(id);if(b.status!=expected)throw StateError('This booking changed. Refresh and try again.');
    const allowed={'Requested':['Accepted','Rejected'],'Accepted':['OnTheWay'],'OnTheWay':['InProgress'],'InProgress':['Completed']};
    final valid=actor=='Customer'?next=='Cancelled'&&['Requested','Accepted'].contains(b.status):actor=='Provider'&&(allowed[b.status]?.contains(next)??false);
    if(!valid)throw StateError('This action is unavailable for the current booking status.');
    _replace(b,{'status':next,'history':[...b.history,{'status':next,'at':_clock().toIso8601String()}]});
    _notify(id,{'Accepted':'Demo booking accepted','Rejected':'Demo booking rejected','Cancelled':'Demo booking cancelled',
      'OnTheWay':'Demo technician is on the way','InProgress':'Demo work started','Completed':'Demo service completed'}[next]!);
  });
  Future<void> reschedule(int id,DateTime at)=>_write((){final b=booking(id);if(b.status!='Requested')throw StateError('Only new requests can be rescheduled.');
    _future(at);_slot(b.city,at,exclude:id);_replace(b,{'appointment':at.toIso8601String()});_notify(id,'Demo appointment rescheduled');});
  Future<void> settle(int id,String payment)=>_write((){final b=booking(id);if(b.status!='Completed'||b.payment!='Awaiting'||!['Skipped','CashSimulated'].contains(payment))throw StateError('Complete the service before reviewing payment.');
    _replace(b,{'payment':payment});_notify(id,payment=='Skipped'?'Demo payment skipped':'Demo cash receipt recorded');});
  Future<void> rate(int id,int rating,String review)=>_write((){final b=booking(id);if(b.status!='Completed'||b.payment=='Awaiting'||b.rating!=null)throw StateError('Review is available once, after completion and payment review.');
    if(rating<1||rating>5||review.length>500)throw ArgumentError('Choose a rating from 1 to 5.');_replace(b,{'rating':rating,'review':review.trim()});_notify(id,'New demo customer review');});
  Future<void> moveLocation(int id)=>_write((){final b=booking(id);if(b.status!='OnTheWay')throw StateError('Location preview is available while travelling.');
    _replace(b,{'trackingStep':b.trackingStep>=10?10:b.trackingStep+1});});
  Future<void> saveService({int? id,required String title,required String category,required String city,required double price,required int limit})=>_write((){
    if(title.trim().isEmpty||title.length>100||!categories.contains(category)||!cities.contains(city)||!price.isFinite||price<=0||price>100000||![3,10,25].contains(limit))throw ArgumentError('Enter valid service details.');
    if(id==null){if(_services.where((s)=>s.owned&&s.active).length>=limit)throw StateError('Your demo package service limit has been reached.');
      _services.add(JourneyService(id:_nextId++,title:title.trim(),category:category,city:city,price:price,owned:true));
    }else{final old=service(id);if(!old.owned)throw StateError('Only your own demo services can be edited.');
      final i=_services.indexWhere((s)=>s.id==id);_services[i]=JourneyService(id:id,title:title.trim(),category:category,city:city,price:price,owned:true,active:old.active);}
  });
  Future<void> setServiceActive(int id,bool active,{int? limit})=>_write((){final s=service(id);if(!s.owned)throw StateError('Only your own demo services can be edited.');
    if(active&&!s.active&&(limit==null||_services.where((v)=>v.owned&&v.active).length>=limit))throw StateError('Your demo package service limit has been reached.');
    _services[_services.indexWhere((v)=>v.id==id)]=JourneyService.fromJson({...s.toJson(),'active':active});});
  List<JourneyNotice> noticesFor(String role)=>_notices.where((n)=>n.role==role).toList();
  Future<void> markRead(String role)=>_write((){_notices=_notices.map((n)=>n.role==role?JourneyNotice.fromJson({...n.toJson(),'read':true}):n).toList();});
  Future<void> dueReminders()=>_write((){for(final b in _bookings){final minutes=b.appointment.difference(_clock()).inSeconds;
    final stamp='${b.id}:${b.appointment.toIso8601String()}';if(['Accepted','OnTheWay'].contains(b.status)&&minutes>0&&minutes<=1800&&!_reminded.contains(stamp)){
      _reminded.add(stamp);_notify(b.id,'Demo appointment starts within 30 minutes',kind:'reminder');}}});
}

class _JourneyWriteQueue { Future<void> tail=Future.value(); }
