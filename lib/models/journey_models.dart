class JourneyService {
  const JourneyService({required this.id, required this.title, required this.category,
    required this.city, required this.price, this.owned=false, this.active=true});
  final int id;
  final String title, category, city;
  final double price;
  final bool owned, active;
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'city':city,'price':price,'owned':owned,'active':active};
  factory JourneyService.fromJson(Map<String,dynamic> j)=>JourneyService(id:j['id'] as int,title:j['title'] as String,
    category:j['category'] as String,city:j['city'] as String,price:(j['price'] as num).toDouble(),owned:j['owned']==true,active:j['active']!=false);
}

class JourneyBooking {
  JourneyBooking({required this.id,required this.serviceId,required this.title,required this.category,required this.city,
    required this.customer,required this.address,required this.phone,required this.notes,required this.appointment,
    required this.amount,this.status='Requested',this.payment='Awaiting',this.rating,this.review='',this.trackingStep=0,
    required List<Map<String,String>> history}):history=List.unmodifiable(history.map((h)=>Map<String,String>.unmodifiable(h)));
  final int id, serviceId, trackingStep;
  final String title, category, city, customer, address, phone, notes, status, payment, review;
  final DateTime appointment;
  final double amount;
  final int? rating;
  final List<Map<String,String>> history;
  bool get terminal=>['Completed','Rejected','Cancelled'].contains(status);
  Map<String,dynamic> toJson()=>{'id':id,'serviceId':serviceId,'title':title,'category':category,'city':city,
    'customer':customer,'address':address,'phone':phone,'notes':notes,'appointment':appointment.toIso8601String(),
    'amount':amount,'status':status,'payment':payment,'rating':rating,'review':review,'trackingStep':trackingStep,'history':history};
  factory JourneyBooking.fromJson(Map<String,dynamic> j)=>JourneyBooking(id:j['id'] as int,serviceId:j['serviceId'] as int,
    title:j['title'] as String,category:j['category'] as String,city:j['city'] as String,customer:j['customer'] as String,
    address:j['address'] as String,phone:j['phone'] as String,notes:j['notes'] as String,
    appointment:DateTime.parse(j['appointment'] as String),amount:(j['amount'] as num).toDouble(),status:j['status'] as String,
    payment:j['payment'] as String,rating:j['rating'] as int?,review:j['review'] as String? ?? '',trackingStep:j['trackingStep'] as int? ?? 0,
    history:(j['history'] as List).map((h)=>Map<String,String>.from(h)).toList());
}

class JourneyNotice {
  const JourneyNotice({required this.id,required this.role,required this.title,required this.kind,
    required this.bookingId,required this.at,this.read=false});
  final int id, bookingId;
  final String role,title,kind;
  final DateTime at;
  final bool read;
  Map<String,dynamic> toJson()=>{'id':id,'role':role,'title':title,'kind':kind,'bookingId':bookingId,'at':at.toIso8601String(),'read':read};
  factory JourneyNotice.fromJson(Map<String,dynamic> j)=>JourneyNotice(id:j['id'] as int,role:j['role'] as String,
    title:j['title'] as String,kind:j['kind'] as String,bookingId:j['bookingId'] as int,at:DateTime.parse(j['at'] as String),read:j['read']==true);
}
