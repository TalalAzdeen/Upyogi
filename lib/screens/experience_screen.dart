import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_language.dart';
import '../services/journey_store.dart';
import '../services/provider_demo_store.dart';
import '../services/role_provider.dart';
import 'auth_screen.dart';
import 'role_select_screen.dart';
import 'provider_demo_screen.dart';
import 'journey_booking_screen.dart';
import 'journey_ui.dart';

class CustomerExperienceScreen extends StatelessWidget{
  const CustomerExperienceScreen({super.key});
  @override Widget build(BuildContext context)=>const _ExperienceShell();
}
class TechnicianWorkspaceScreen extends StatelessWidget{
  const TechnicianWorkspaceScreen({super.key,required this.onPlans,required this.onRealLogin,required this.onExit});
  final Future<void> Function() onPlans,onRealLogin,onExit;
  @override Widget build(BuildContext context)=>_ExperienceShell(technician:true,onPlans:onPlans,onRealLogin:onRealLogin,onExit:onExit);
}
class _ExperienceShell extends ConsumerStatefulWidget{
  const _ExperienceShell({this.technician=false,this.onPlans,this.onRealLogin,this.onExit});
  final bool technician;
  final Future<void> Function()? onPlans,onRealLogin,onExit;
  @override ConsumerState<_ExperienceShell> createState()=>_ExperienceShellState();
}
class _ExperienceShellState extends ConsumerState<_ExperienceShell> with WidgetsBindingObserver{
  JourneyStore? _store;
  ProviderDemoStore? _provider;
  Timer? _timer;
  bool _busy=false,_refreshing=false;
  String? _error;
  int _tab=0;
  bool _notices=false;
  String _city='All',_category='All',_sort='default',_status='All';
  double? _priceCap;
  final _query=TextEditingController(),_name=TextEditingController();
  String get _role=>widget.technician?'Provider':'Customer';
  bool get _expired=>_provider?.subscriptionUntil==null||!_provider!.subscriptionUntil!.isAfter(DateTime.now());
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_load();
    _timer=Timer.periodic(const Duration(seconds:30),(_){if(!_busy)_load();});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_load();}
  @override void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);_query.dispose();_name.dispose();super.dispose();}
  Future<void> _load()async{
    if(_refreshing||_busy)return;_refreshing=true;
    try{final s=await JourneyStore.load();final p=await ProviderDemoStore.load();if(_store==null)await s.selectRole(_role);await s.dueReminders();
      if(mounted)setState((){_store=s;_provider=p;_error=null;});}
    catch(_){if(mounted)setState(()=>_error='Unable to load demo progress. Try again.');}
    finally{_refreshing=false;}
  }
  Future<bool> _run(Future<void> Function() action)async{
    if(_busy)return false;setState((){_busy=true;_error=null;});
    try{await action();if(mounted)setState((){});return true;}
    catch(e){if(mounted)setState(()=>_error=e is StateError?'${e.message}':e is ArgumentError?'${e.message}':'Unable to save demo progress. Try again.');return false;}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _leave({bool real=false})async{
    if(widget.technician){await (real?widget.onRealLogin!:widget.onExit!)();return;}
    if(!await _run(()async{await _store!.leave();await _provider!.exit();}))return;
    if(!mounted)return;ref.read(selectedRoleProvider.notifier).state='Customer';
    Navigator.pushAndRemoveUntil(context,MaterialPageRoute(builder:(_)=>real?const AuthScreen():const RoleSelectScreen()),(_)=>false);
  }
  Future<void> _switch()async{
    final role=widget.technician?'Customer':'Provider';
    if(!await _run(()=>_store!.selectRole(role)))return;
    if(!mounted)return;ref.read(selectedRoleProvider.notifier).state=role;
    Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>widget.technician?const CustomerExperienceScreen():const ProviderDemoScreen()));
  }
  Future<void> _openBooking(int id)async{
    if(widget.technician&&_expired){setState(()=>_error='Demo package expired. Renew to continue.');return;}
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>JourneyBookingScreen(bookingId:id,technician:widget.technician)));
    if(mounted)await _load();
  }
  Future<void> _book(JourneyService s)async{
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>JourneyBookingScreen(serviceId:s.id)));
    if(mounted){await _load();setState(()=>_tab=1);}
  }
  @override Widget build(BuildContext context){
    final s=_store;final welcome=s!=null&&!widget.technician&&s.customerName.isEmpty;
    final unread=s?.noticesFor(_role).where((n)=>!n.read).length??0;
    final title=_notices?'Demo notifications':welcome?'Sulh for customers':widget.technician?'Technician dashboard':'Sulh customer';
    return Scaffold(backgroundColor:const Color(0xFFF6F5FB),
      appBar:AppBar(title:LText(title),actions:[const LanguageButton(),if(!welcome)IconButton(key:const Key('journey-notifications'),
        tooltip:tr(context,'Notifications'),onPressed:()=>setState(()=>_notices=!_notices),
        icon:Badge(isLabelVisible:unread>0,label:Text('$unread'),child:const Icon(Icons.notifications_none))),
        IconButton(tooltip:tr(context,'Exit demo'),onPressed:_busy||s==null?null:()=>_leave(),icon:const Icon(Icons.logout))]),
      body:s==null?Center(child:_error==null?const CircularProgressIndicator():TextButton(onPressed:_load,child:const LText('Retry'))):
      SafeArea(child:RefreshIndicator(onRefresh:_load,child:SingleChildScrollView(key:ValueKey('journey-page-$_tab-$_notices-$welcome'),
        physics:const AlwaysScrollableScrollPhysics(),padding:const EdgeInsets.all(18),child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),
          child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const JourneyBanner(),
            if(_busy)const LinearProgressIndicator(),if(_error!=null)Padding(padding:const EdgeInsets.all(12),child:LText(_error!,style:const TextStyle(color:Colors.red))),
            if(welcome)..._welcome() else if(_notices)..._notifications(s) else if(_tab==1)..._appointments(s)
            else if(_tab==3)..._profile(s) else if(widget.technician)...(_tab==0?_dashboard(s):_services(s))
            else ..._catalog(s,favorites:_tab==2),const SizedBox(height:28),
          ])))))),
      bottomNavigationBar:welcome||s==null?null:NavigationBar(selectedIndex:_tab,onDestinationSelected:(v)=>setState((){_tab=v;_notices=false;}),destinations:[
        NavigationDestination(key:const Key('journey-tab-0'),icon:const Icon(Icons.dashboard_outlined),label:tr(context,widget.technician?'Dashboard':'Explore')),
        NavigationDestination(key:const Key('journey-tab-1'),icon:const Icon(Icons.event_note_outlined),label:tr(context,'Appointments')),
        NavigationDestination(key:const Key('journey-tab-2'),icon:Icon(widget.technician?Icons.handyman_outlined:Icons.favorite_border),label:tr(context,widget.technician?'My Services':'Favorites')),
        NavigationDestination(key:const Key('journey-tab-3'),icon:const Icon(Icons.person_outline),label:tr(context,'Profile')),
      ]));
  }
  Widget _hero(String title,String subtitle,IconData icon)=>Container(padding:const EdgeInsets.all(24),
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[journeyNavy,journeyPurple],begin:Alignment.topRight,end:Alignment.bottomLeft),borderRadius:BorderRadius.circular(26)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:48,color:Colors.white),const SizedBox(height:20),
      LText(title,style:const TextStyle(color:Colors.white,fontSize:28,fontWeight:FontWeight.bold)),const SizedBox(height:12),
      LText(subtitle,style:const TextStyle(color:Colors.white70,height:1.6))]));
  List<Widget> _welcome()=>[
    _hero('A trusted start for every home','Explore, book, follow the work and review your experience.',Icons.home_repair_service_outlined),
    const SizedBox(height:16),journeyCard([
      const LText('Create a customer demo profile',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),
      const LText('Use a fictional name. No password or verification email is needed.'),const SizedBox(height:12),
      TextField(key:const Key('customer-demo-name'),controller:_name,maxLength:80,onChanged:(_)=>setState((){}),decoration:InputDecoration(labelText:tr(context,'Full name'))),
      OutlinedButton.icon(key:const Key('fill-customer-demo'),onPressed:_busy?null:()=>setState(()=>_name.text=tr(context,'Sulh demo customer')),
        icon:const Icon(Icons.auto_fix_high),label:const LText('Fill fictional details')),
      FilledButton(key:const Key('start-customer-demo'),onPressed:_busy||_name.text.trim().isEmpty?null:()=>_run(()=>_store!.registerCustomer(_name.text)),
        child:const Padding(padding:EdgeInsets.all(12),child:LText('Start customer demo'))),
    ]),TextButton(onPressed:_busy?null:()=>_leave(real:true),child:const LText('Use a real account')),
  ];
  Widget _dropdown(String label,String value,List<String> values,ValueChanged<String> change)=>SizedBox(width:200,child:DropdownButtonFormField<String>(
    initialValue:value,decoration:InputDecoration(labelText:tr(context,label),filled:true,fillColor:Colors.white),isExpanded:true,
    items:values.map((v)=>DropdownMenuItem(value:v,child:LText({'default':'Default order','price':'Lowest price','rating':'Highest rating'}[v]??v))).toList(),
    onChanged:_busy?null:(v){if(v!=null)setState(()=>change(v));}));
  List<Widget> _catalog(JourneyStore s,{required bool favorites}){
    final matches=s.search(query:_query.text,city:_city,category:_category,sort:_sort,favoritesOnly:favorites).where((v)=>_priceCap==null||v.price<=_priceCap!).toList();
    return[
      if(!favorites)...[_hero('Your next service, made simple','24 fictional services across three cities. Try the full journey at your own pace.',Icons.search),const SizedBox(height:18)]
      else journeyHeading('Your saved services'),
      TextField(key:const Key('journey-search'),controller:_query,onChanged:(_)=>setState((){}),
        decoration:InputDecoration(hintText:tr(context,'Search by service or city'),prefixIcon:const Icon(Icons.search),
          suffixIcon:_query.text.isEmpty?null:IconButton(onPressed:()=>setState(_query.clear),icon:const Icon(Icons.close)),
          filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(18),borderSide:BorderSide.none))),
      const SizedBox(height:14),Wrap(spacing:12,runSpacing:12,children:[_dropdown('City',_city,['All',...JourneyStore.cities],(v)=>_city=v),
        _dropdown('Category',_category,['All',...JourneyStore.categories],(v)=>_category=v),_dropdown('Sort by',_sort,['default','price','rating'],(v)=>_sort=v)]),
      const SizedBox(height:12),Wrap(spacing:8,children:[for(final cap in <double?>[null,150,300])ChoiceChip(label:LText(cap==null?'All prices':'SAR ${cap.toInt()} or less'),
        selected:_priceCap==cap,onSelected:(_)=>setState(()=>_priceCap=cap))]),
      const SizedBox(height:8),Text('${matches.length} ${tr(context,'services found')}',style:const TextStyle(color:Colors.grey)),
      if(matches.isEmpty)...[journeyEmpty('No services match your filters.',Icons.search_off),TextButton(onPressed:()=>setState((){_query.clear();_city='All';_category='All';_priceCap=null;}),child:const LText('Clear filters'))],
      for(final service in matches)journeyCard([
        Row(children:[Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFF0ECFF),borderRadius:BorderRadius.circular(16)),child:Icon(journeyIcon(service.category),color:journeyPurple,size:32)),
          const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[LText(service.title,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),LText('${service.category} • ${service.city}')])) ,
          IconButton(tooltip:tr(context,'Save service'),onPressed:_busy?null:()=>_run(()=>s.toggleFavorite(service.id)),icon:Icon(s.isFavorite(service.id)?Icons.favorite:Icons.favorite_border,color:journeyPurple))]),
        const SizedBox(height:12),LText('SAR ${service.price.toStringAsFixed(2)}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:journeyPurple)),
        LText(s.ratingFor(service.id)==0?'No demo reviews yet':'${s.ratingFor(service.id).toStringAsFixed(1)} / 5'),
        const SizedBox(height:10),FilledButton(key:Key('book-service-${service.id}'),onPressed:_busy?null:()=>_book(service),child:const LText('View service and book')),
      ]),
    ];
  }
  List<Widget> _appointments(JourneyStore s){final filtered=s.bookings.where((b)=>_status=='All'||b.status==_status).toList();return[
    journeyHeading(widget.technician?'Service Requests':'My demo appointments'),
    Wrap(spacing:8,runSpacing:6,children:['All','Requested','Accepted','OnTheWay','InProgress','Completed','Rejected','Cancelled'].map((v)=>ChoiceChip(label:LText(v),selected:_status==v,onSelected:(_)=>setState(()=>_status=v))).toList()),
    const SizedBox(height:12),if(filtered.isEmpty)journeyEmpty('No demo bookings in this category.',Icons.event_available),
    for(final b in filtered)journeyCard([
      Row(children:[Expanded(child:LText(b.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold))),Text('#${b.id}')]),
      Wrap(spacing:8,children:[Chip(label:LText(b.status)),Chip(label:LText(b.city))]),Text(journeyDate(b.appointment)),
      LText('SAR ${b.amount.toStringAsFixed(2)}'),if(b.rating!=null)Text('★ ${b.rating} / 5'),
      const SizedBox(height:10),FilledButton(key:Key('open-booking-${b.id}'),onPressed:_busy?null:()=>_openBooking(b.id),child:const LText('Open booking')),
    ]),
  ];}
  List<Widget> _notifications(JourneyStore s)=>[
    TextButton.icon(onPressed:_busy?null:()=>_run(()=>s.markRead(_role)),icon:const Icon(Icons.done_all),label:const LText('Mark all as read')),
    const LText('Reminders appear here while the app is open, within 30 minutes before an accepted appointment.'),
    if(s.noticesFor(_role).isEmpty)journeyEmpty('No demo notifications yet.',Icons.notifications_none),
    for(final n in s.noticesFor(_role))journeyCard([ListTile(contentPadding:EdgeInsets.zero,
      leading:Icon(n.read?Icons.notifications_none:Icons.notifications_active,color:journeyPurple),title:LText(n.title),
      subtitle:Text('#${n.bookingId} · ${journeyDate(n.at)}'),onTap:()=>_openBooking(n.bookingId))]),
    TextButton(onPressed:()=>setState(()=>_notices=false),child:const LText('Back')),
  ];
  Widget _metric(String label,String value)=>Container(width:150,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold,color:journeyPurple)),LText(label)]));
  List<Widget> _dashboard(JourneyStore s){
    final p=_provider!,plan=p.plan;
    final completed=s.bookings.where((b)=>b.status=='Completed').toList(),rated=s.bookings.where((b)=>b.rating!=null).toList();
    final cash=completed.where((b)=>b.payment=='CashSimulated').fold<double>(0,(n,b)=>n+b.amount);
    return[
      _hero(p.name,'Your customer requests, services and subscription in one workspace.',Icons.handyman_outlined),const SizedBox(height:16),
      Wrap(spacing:10,runSpacing:10,children:[_metric('New requests','${s.bookings.where((b)=>b.status=='Requested').length}'),
        _metric('Accepted','${s.bookings.where((b)=>['Accepted','OnTheWay','InProgress'].contains(b.status)).length}'),
        _metric('Completed','${completed.length}'),_metric('Cancelled or rejected','${s.bookings.where((b)=>['Cancelled','Rejected'].contains(b.status)).length}')]),
      journeyHeading('My demo subscription'),journeyCard([
        if(plan!=null)...[LText(plan.name,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),LText('SAR ${plan.price}'),
          if(p.subscriptionUntil!=null)Text('${tr(context,'Expires on')}: ${journeyDate(p.subscriptionUntil!)}')],
        if(_expired)const LText('Demo package expired. Renew to continue.',style:TextStyle(color:Colors.red)),
        OutlinedButton(onPressed:_busy||plan==null?null:()=>_run(p.renew),child:const LText('Simulate package renewal')),
        TextButton(onPressed:_busy?null:widget.onPlans,child:const LText('View all packages and change my choice')),
        const LText('No charges or automatic renewal in this demo.'),
      ]),
      journeyHeading('Availability and demo location'),journeyCard([
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const LText('Available for demo requests'),value:p.available,onChanged:_busy?null:(v)=>_run(()=>p.setAvailable(v))),
        const LText('Availability is a local preview. Accepted requests remain visible.'),
        const LText('Open an accepted booking to start a fictional route and update its progress.'),
      ]),
      journeyHeading('Demo business insights'),journeyCard([
        LText('SAR ${completed.fold<double>(0,(n,b)=>n+b.amount).toStringAsFixed(2)}'),const LText('Completed service value'),
        LText('SAR ${cash.toStringAsFixed(2)}'),const LText('Demo cash total — no real revenue'),
        if(rated.isNotEmpty)Text('★ ${(rated.fold<int>(0,(n,b)=>n+b.rating!)/rated.length).toStringAsFixed(1)} / 5'),
        if(plan?.id=='pro')OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:
          '${tr(context,'Demo business report')}\n${tr(context,'Completed')}: ${completed.length}\n${tr(context,'Demo cash total — no real revenue')}: SAR ${cash.toStringAsFixed(2)}'));
          if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:LText('Demo report copied')));},icon:const Icon(Icons.copy),label:const LText('Copy demo report')),
      ]),
      if(rated.isNotEmpty)...[journeyHeading('Customer demo reviews'),for(final b in rated)journeyCard([Text('★ ${b.rating} / 5'),Text(b.customer),Text(b.review),LText(b.title)])],
      FilledButton(onPressed:()=>setState(()=>_tab=1),child:const LText('Manage service requests')),
      const SizedBox(height:12),OutlinedButton.icon(onPressed:_busy?null:_switch,icon:const Icon(Icons.swap_horiz),label:const LText('Switch to customer demo')),
      TextButton(onPressed:_busy?null:()=>_leave(real:true),child:const LText('Use a real account')),
    ];
  }
  Future<void> _editService([JourneyService? service])async{
    final title=TextEditingController(text:service?.title??''),price=TextEditingController(text:service?.price.toStringAsFixed(0)??'');
    var category=service?.category??'Plumber',city=service?.city??'Riyadh';final form=GlobalKey<FormState>();
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(c)=>StatefulBuilder(builder:(c,update)=>AlertDialog(
      title:LText(service==null?'Add demo service':'Edit demo service'),content:SingleChildScrollView(child:Form(key:form,child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextFormField(controller:title,maxLength:100,decoration:InputDecoration(labelText:tr(context,'Service title')),validator:(v)=>(v??'').trim().isEmpty?tr(context,'Enter a service title'):null),
        TextFormField(controller:price,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:tr(context,'Price (SAR)')),validator:(v){final p=double.tryParse(v??'');return p==null||!p.isFinite||p<=0||p>100000?tr(context,'Enter a valid price'):null;}),
        DropdownButtonFormField<String>(initialValue:category,isExpanded:true,items:JourneyStore.categories.map((v)=>DropdownMenuItem(value:v,child:LText(v))).toList(),onChanged:(v)=>update(()=>category=v!)),
        DropdownButtonFormField<String>(initialValue:city,items:JourneyStore.cities.map((v)=>DropdownMenuItem(value:v,child:LText(v))).toList(),onChanged:(v)=>update(()=>city=v!)),
      ]))),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const LText('Cancel')),
        FilledButton(onPressed:(){if(form.currentState?.validate()==true)Navigator.pop(c,{'title':title.text,'price':double.parse(price.text),'category':category,'city':city});},child:const LText('Save'))])));
    Future<void>.delayed(const Duration(milliseconds:400),(){title.dispose();price.dispose();});
    if(result==null||!mounted)return;
    await _run(()=>_store!.saveService(id:service?.id,title:result['title'],price:result['price'],category:result['category'],city:result['city'],limit:_provider!.plan!.services));
  }
  List<Widget> _services(JourneyStore s){final owned=s.services.where((v)=>v.owned).toList();return[
    journeyHeading('Manage your demo services'),
    LText('${owned.where((v)=>v.active).length} / ${_provider?.plan?.services??0} ${tr(context,'active services')}'),
    const LText('Your services appear in the customer demo on this device. Existing bookings retain their original details.'),
    const SizedBox(height:12),FilledButton.icon(onPressed:_busy||_expired?null:()=>_editService(),icon:const Icon(Icons.add),label:const LText('Add demo service')),
    if(owned.isEmpty)journeyEmpty('Add your first demo service.',Icons.handyman_outlined),
    for(final v in owned)journeyCard([
      LText(v.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),LText('${v.category} • ${v.city}'),LText('SAR ${v.price.toStringAsFixed(2)}'),
      SwitchListTile(contentPadding:EdgeInsets.zero,title:const LText('Visible in customer demo'),value:v.active,
        onChanged:_busy||_expired?null:(active)=>_run(()=>s.setServiceActive(v.id,active,limit:_provider!.plan!.services))),
      TextButton.icon(onPressed:_busy||_expired?null:()=>_editService(v),icon:const Icon(Icons.edit_outlined),label:const LText('Edit demo service')),
    ]),
  ];}
  Future<void> _rename()async{
    final c=TextEditingController(text:_store!.customerName);
    final name=await showDialog<String>(context:context,builder:(d)=>AlertDialog(title:const LText('Edit demo profile'),content:TextField(controller:c,maxLength:80,
      decoration:InputDecoration(labelText:tr(context,'Full name'))),actions:[TextButton(onPressed:()=>Navigator.pop(d),child:const LText('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(d,c.text),child:const LText('Save'))]));
    Future<void>.delayed(const Duration(milliseconds:400),c.dispose);if(name!=null&&mounted)await _run(()=>_store!.registerCustomer(name));
  }
  List<Widget> _profile(JourneyStore s)=>[
    journeyCard([const Icon(Icons.account_circle_outlined,size:70,color:journeyPurple),const SizedBox(height:14),
      Text(widget.technician?_provider!.name:s.customerName,textAlign:TextAlign.center,style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),
      LText(_role,textAlign:TextAlign.center),const SizedBox(height:12),const LText('Demo profile is saved locally. No real account or password was created.'),
      if(!widget.technician)OutlinedButton(onPressed:_busy?null:_rename,child:const LText('Edit demo profile')),
      if(widget.technician)LText(_provider!.specialty),
    ]),
    journeyHeading('Try the other side of the booking'),
    OutlinedButton.icon(onPressed:_busy?null:_switch,icon:const Icon(Icons.swap_horiz),label:LText(widget.technician?'Switch to customer demo':'Switch to technician demo')),
    const SizedBox(height:12),const LText('Both roles share this device only. Data is not synchronized to another phone.'),
    const SizedBox(height:18),TextButton(onPressed:_busy?null:()=>_leave(real:true),child:const LText('Use a real account')),
    TextButton.icon(onPressed:()=>showDialog<void>(context:context,builder:(c)=>AlertDialog(title:const LText('Help & Support'),
      content:const LText('For this demo: book as a customer, switch to technician, choose a package, complete the request, then return to the customer to review payment and rate. No support request is sent.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const LText('OK'))])),icon:const Icon(Icons.help_outline),label:const LText('Demo guide')),
    TextButton.icon(onPressed:_busy?null:()=>_leave(),icon:const Icon(Icons.logout),label:const LText('Exit demo')),
  ];
}
