import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_language.dart';
import '../services/journey_store.dart';
import '../services/role_provider.dart';
import 'provider_demo_screen.dart';
import 'journey_ui.dart';

class JourneyBookingScreen extends ConsumerStatefulWidget{
  const JourneyBookingScreen({super.key,this.bookingId,this.serviceId,this.technician=false})
    :assert(bookingId!=null||serviceId!=null);
  final int? bookingId,serviceId;
  final bool technician;
  @override ConsumerState<JourneyBookingScreen> createState()=>_JourneyBookingScreenState();
}
class _JourneyBookingScreenState extends ConsumerState<JourneyBookingScreen>{
  JourneyStore? _store;
  int? _id;
  bool _busy=false;
  String? _error;
  final _form=GlobalKey<FormState>();
  final _address=TextEditingController(),_phone=TextEditingController(),_notes=TextEditingController(),_review=TextEditingController();
  DateTime _appointment=DateTime.now().add(const Duration(days:1));
  int _rating=0;
  @override void initState(){super.initState();_id=widget.bookingId;_load();}
  Future<void> _load()async{try{final s=await JourneyStore.load();if(!mounted)return;setState(()=>_store=s);}catch(_){if(mounted)setState(()=>_error='Unable to load demo progress. Try again.');}}
  @override void dispose(){_address.dispose();_phone.dispose();_notes.dispose();_review.dispose();super.dispose();}
  Future<bool> _run(Future<void> Function() action)async{
    if(_busy)return false;setState((){_busy=true;_error=null;});
    try{await action();if(mounted)setState((){});return true;}
    catch(e){if(mounted)setState(()=>_error=e is StateError?'${e.message}':e is ArgumentError?'${e.message}':'Unable to save demo progress. Try again.');return false;}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<DateTime?> _pick(DateTime initial)async{
    final now=DateTime.now();final first=DateTime(now.year,now.month,now.day);
    final day=await showDatePicker(context:context,initialDate:initial.isBefore(first)?first:initial,
      firstDate:first,lastDate:now.add(const Duration(days:365)));
    if(day==null||!mounted)return null;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(initial));
    return time==null?null:DateTime(day.year,day.month,day.day,time.hour,time.minute);
  }
  Future<void> _submit()async{
    if(_form.currentState?.validate()!=true)return;
    await _run(()async{final b=await _store!.book(serviceId:widget.serviceId!,appointment:_appointment,address:_address.text,phone:_phone.text,notes:_notes.text);_id=b.id;});
  }
  Future<void> _cancel(JourneyBooking b)async{
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const LText('Cancel this demo booking?'),
      content:const LText('The request will remain in your history.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const LText('Back')),
        FilledButton(onPressed:()=>Navigator.pop(c,true),child:const LText('Cancel Booking'))]));
    if(yes==true)await _run(()=>_store!.transition(b.id,expected:b.status,next:'Cancelled',actor:'Customer'));
  }
  Future<void> _provider()async{
    await _store!.selectRole('Provider');if(!mounted)return;ref.read(selectedRoleProvider.notifier).state='Provider';
    Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>const ProviderDemoScreen()),(_)=>false);
  }
  @override Widget build(BuildContext context){
    final s=_store;
    return Scaffold(backgroundColor:const Color(0xFFF6F5FB),appBar:AppBar(title:LText(_id==null?'Service details and booking':'Demo booking details'),actions:[const LanguageButton(),
      IconButton(tooltip:tr(context,'Refresh'),onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),
      body:s==null?Center(child:_error==null?const CircularProgressIndicator():TextButton(onPressed:_load,child:const LText('Retry'))):
      SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:760),
        child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const JourneyBanner(),
          if(_busy)const LinearProgressIndicator(),if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:LText(_error!,style:const TextStyle(color:Colors.red))),
          if(_id==null)..._formWidgets(s) else ..._details(s,s.booking(_id!)),const SizedBox(height:40),
        ]))))));
  }
  List<Widget> _formWidgets(JourneyStore s){final service=s.service(widget.serviceId!);return[
    journeyCard([Icon(journeyIcon(service.category),size:54,color:journeyPurple),const SizedBox(height:12),
      LText(service.title,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),LText('${service.category} • ${service.city}'),
      const SizedBox(height:12),LText('SAR ${service.price.toStringAsFixed(2)}',style:const TextStyle(fontSize:24,color:journeyPurple,fontWeight:FontWeight.bold)),
      const SizedBox(height:10),const LText('Demo home visit, approximately 60 minutes. This is a sample service, not a verified professional listing.'),
      const LText('The displayed demo price is fixed for this booking. No charge is collected.'),
    ]),journeyHeading('Schedule your demo visit'),
    OutlinedButton.icon(key:const Key('fill-journey-booking'),onPressed:_busy?null:()=>setState((){
      _address.text=tr(context,'Demo street, building 12');_phone.text='0500000000';_notes.text=tr(context,'Please inspect the issue before starting.');
      final d=DateTime.now().add(const Duration(days:1));_appointment=DateTime(d.year,d.month,d.day,10);
    }),icon:const Icon(Icons.auto_fix_high),label:const LText('Fill fictional booking details')),
    journeyCard([Form(key:_form,child:Column(children:[
      TextFormField(key:const Key('journey-address'),controller:_address,maxLength:240,decoration:InputDecoration(labelText:tr(context,'Service address')),
        validator:(v)=>(v??'').trim().length<5?tr(context,'Enter a complete address'):null),
      TextFormField(controller:_phone,maxLength:13,keyboardType:TextInputType.phone,textDirection:TextDirection.ltr,
        decoration:InputDecoration(labelText:tr(context,'Mobile number')),validator:(v)=>!RegExp(r'^(?:0|\+?966)?5\d{8}$').hasMatch((v??'').trim())?tr(context,'Enter a valid Saudi mobile number'):null),
      TextFormField(controller:_notes,maxLength:500,maxLines:2,decoration:InputDecoration(labelText:tr(context,'Notes (optional)'))),
      const SizedBox(height:12),Text(journeyDate(_appointment)),
      OutlinedButton.icon(onPressed:_busy?null:()async{final at=await _pick(_appointment);if(at!=null&&mounted)setState(()=>_appointment=at);},
        icon:const Icon(Icons.event),label:const LText('Choose date and time')),
    ]))]),
    FilledButton(key:const Key('confirm-journey-booking'),onPressed:_busy?null:_submit,
      child:const Padding(padding:EdgeInsets.all(14),child:LText('Confirm demo booking'))),
  ];}
  List<Widget> _details(JourneyStore s,JourneyBooking b){
    const phases=['Requested','Accepted','OnTheWay','InProgress','Completed'];
    final progress=phases.indexOf(b.status);
    return[
      journeyCard([Text('#${b.id}',style:const TextStyle(color:Colors.grey)),LText(b.title,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
        Wrap(spacing:8,children:[Chip(label:LText(b.status)),Chip(label:LText(b.city))]),Text(journeyDate(b.appointment)),
        const Divider(),LText('Customer: ${b.customer}'),Text(b.address),Text(b.phone,textDirection:TextDirection.ltr),
        if(b.notes.isNotEmpty)Text(b.notes),LText('SAR ${b.amount.toStringAsFixed(2)}',style:const TextStyle(fontSize:25,color:journeyPurple,fontWeight:FontWeight.bold)),
      ]),journeyHeading('Booking timeline'),
      journeyCard([for(var i=0;i<phases.length;i++)ListTile(contentPadding:EdgeInsets.zero,
        leading:Icon(i<=progress?Icons.check_circle:Icons.radio_button_unchecked,color:i<=progress?journeyTeal:Colors.grey),
        title:LText(phases[i]),subtitle:b.history.any((h)=>h['status']==phases[i])?Text(journeyDate(DateTime.parse(b.history.firstWhere((h)=>h['status']==phases[i])['at']!))):null),
        if(['Rejected','Cancelled'].contains(b.status))LText(b.status,style:const TextStyle(color:Colors.red,fontWeight:FontWeight.bold)),
      ]),
      if(b.status=='OnTheWay')...[
        journeyHeading('Simulated route progress'),journeyCard([
          const LText('Fictional route. No device location is accessed or transmitted.'),const SizedBox(height:12),
          LinearProgressIndicator(value:b.trackingStep/10,minHeight:10,borderRadius:BorderRadius.circular(8)),
          Text('${b.trackingStep*10}%'),
          if(widget.technician)OutlinedButton.icon(onPressed:_busy?null:()=>_run(()=>s.moveLocation(b.id)),
            icon:const Icon(Icons.near_me_outlined),label:const LText('Move demo technician')),
        ]),
      ],
      if(widget.technician&&!b.terminal)...[
        journeyHeading('Manage this request'),
        for(final next in (const {'Requested':['Accepted','Rejected'],'Accepted':['OnTheWay'],'OnTheWay':['InProgress'],'InProgress':['Completed']}[b.status]??<String>[]))
          Padding(padding:const EdgeInsets.only(bottom:10),child:FilledButton(key:Key('transition-$next'),
            onPressed:_busy?null:()=>_run(()=>s.transition(b.id,expected:b.status,next:next,actor:'Provider')),
            child:Padding(padding:const EdgeInsets.all(12),child:LText({'Accepted':'Accept demo request','Rejected':'Reject demo request',
              'OnTheWay':'Start demo journey','InProgress':'Start demo work','Completed':'Complete demo service'}[next]!)))),
      ],
      if(!widget.technician&&['Requested','Accepted'].contains(b.status))...[
        if(b.status=='Requested')OutlinedButton.icon(onPressed:_busy?null:()async{final at=await _pick(b.appointment);if(at!=null)await _run(()=>s.reschedule(b.id,at));},
          icon:const Icon(Icons.edit_calendar),label:const LText('Reschedule demo appointment')),
        TextButton(onPressed:_busy?null:()=>_cancel(b),child:const LText('Cancel Booking')),
      ],
      if(!widget.technician&&!b.terminal)OutlinedButton.icon(onPressed:_busy?null:_provider,icon:const Icon(Icons.swap_horiz),label:const LText('Switch to technician to respond')),
      if(b.status=='Completed')...[
        journeyHeading('Demo payment and receipt'),
        journeyCard([LText('SAR ${b.amount.toStringAsFixed(2)}',style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold)),
          LText({'Awaiting':'Awaiting demo payment review','Skipped':'Demo payment skipped','CashSimulated':'Demo cash receipt recorded'}[b.payment]!),
          const LText('No money was transferred. This receipt is a simulation, not a tax invoice.'),
          if(!widget.technician&&b.payment=='Awaiting')...[
            const SizedBox(height:12),FilledButton(key:const Key('settle-skipped'),onPressed:_busy?null:()=>_run(()=>s.settle(b.id,'Skipped')),child:const LText('Skip payment and continue')),
            OutlinedButton(key:const Key('settle-cash'),onPressed:_busy?null:()=>_run(()=>s.settle(b.id,'CashSimulated')),child:const LText('Simulate cash payment')),
          ],
          if(b.payment!='Awaiting')TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:
            '${tr(context,'Demo receipt')} #${b.id}\n${tr(context,b.title)}\n${journeyDate(b.appointment)}\nSAR ${b.amount.toStringAsFixed(2)}\n${tr(context,b.payment=='Skipped'?'Demo payment skipped':'Demo cash receipt recorded')}\n${tr(context,'No money was transferred.')}'));
            if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:LText('Demo receipt copied')));},icon:const Icon(Icons.copy),label:const LText('Copy demo receipt')),
        ]),
        if(b.payment!='Awaiting')...[
          journeyHeading('Your demo review'),
          if(b.rating!=null)journeyCard([Text('${b.rating} / 5',style:const TextStyle(fontSize:24,color:Colors.amber)),Text(b.review),const LText('Saved demo review')])
          else if(!widget.technician)journeyCard([
            Wrap(alignment:WrapAlignment.center,children:[for(var n=1;n<=5;n++)IconButton(key:Key('review-star-$n'),tooltip:'${tr(context,'Rating')} $n',
              onPressed:_busy?null:()=>setState(()=>_rating=n),icon:Icon(n<=_rating?Icons.star:Icons.star_border,color:Colors.amber,size:32))]),
            TextField(controller:_review,maxLength:500,maxLines:2,decoration:InputDecoration(labelText:tr(context,'Review (optional)'))),
            FilledButton(key:const Key('submit-journey-review'),onPressed:_busy||_rating==0?null:()=>_run(()=>s.rate(b.id,_rating,_review.text)),child:const LText('Save demo review')),
          ]),
        ],
      ],
    ];
  }
}
