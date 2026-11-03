import 'package:flutter/material.dart';
import '../l10n/app_language.dart';
import '../services/provider_demo_store.dart';
import 'auth_screen.dart';
import 'role_select_screen.dart';

const _purple=Color(0xFF6C5CE7);
const _navy=Color(0xFF191630);
const _teal=Color(0xFF078779);

class ProviderDemoScreen extends StatefulWidget {
  const ProviderDemoScreen({super.key});
  @override
  State<ProviderDemoScreen> createState()=>_ProviderDemoScreenState();
}
class _ProviderDemoScreenState extends State<ProviderDemoScreen> {
  ProviderDemoStore? _store;
  final _form=GlobalKey<FormState>();
  final _name=TextEditingController();
  final _email=TextEditingController();
  String _specialty='Plumber';
  String? _selectedPlan;
  bool _agreed=false;
  bool _busy=false;
  String? _error;
  String _filter='All';
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    try {
      final store=await ProviderDemoStore.load();
      if(!mounted)return;
      await store.resume();
      if(!mounted)return;
      _name.text=store.name;
      setState(()=>_store=store);
    } catch (_) { if(mounted)setState(()=>_error='Unable to load demo progress. Try again.'); }
  }
  @override
  void dispose(){_name.dispose();_email.dispose();super.dispose();}
  Future<void> _run(Future<void> Function() action) async {
    if(_busy)return;
    setState((){_busy=true;_error=null;});
    try {await action();}
    catch(_){if(mounted)setState(()=>_error='Unable to save demo progress. Try again.');}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  Future<void> _exit() async {
    if(_busy)return;
    await _run(()=>_store!.exit());
    if(!mounted || _error!=null)return;
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder:(_)=>const RoleSelectScreen()),(_)=>false);
  }
  Future<void> _realLogin() async {
    if(_busy)return;
    await _run(()=>_store!.exit());
    if(!mounted || _error!=null)return;
    Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const AuthScreen()));
  }
  String get _title=>switch(_store?.stage){
    'registration'=>'Demo registration','plans'=>'Choose your demo package','dashboard'=>'Technician dashboard',_=>'Sulh for technicians'};
  @override
  Widget build(BuildContext context){
    final s=_store;
    return Scaffold(backgroundColor:const Color(0xFFF6F5FB),
      appBar:AppBar(title:LText(_title),actions:[const LanguageButton(),if(s!=null)IconButton(
        onPressed:_busy?null:_exit,icon:const Icon(Icons.logout),tooltip:tr(context,'Exit demo'))]),
      body:s==null?Center(child:_error==null?const CircularProgressIndicator():Column(mainAxisSize:MainAxisSize.min,children:[
        LText(_error!),TextButton(onPressed:_load,child:const LText('Retry'))])):
      SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Center(child:ConstrainedBox(
        constraints:const BoxConstraints(maxWidth:700),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFE5F3EF),borderRadius:BorderRadius.circular(14)),
            child:const Row(children:[Icon(Icons.science_outlined,color:_teal),SizedBox(width:10),Expanded(child:LText(
              'Simulation only. No real account, verification email, payment or location sharing.',style:TextStyle(color:_teal,fontSize:13)))])),
          if(_busy)const Padding(padding:EdgeInsets.only(top:12),child:LinearProgressIndicator()),
          if(_error!=null)Padding(padding:const EdgeInsets.symmetric(vertical:12),child:LText(_error!,style:const TextStyle(color:Colors.red))),
          const SizedBox(height:20),
          if(s.stage=='welcome')..._welcome(s),
          if(s.stage=='registration')..._registration(s),
          if(s.stage=='plans')..._plans(s),
          if(s.stage=='dashboard')..._dashboard(s),
          if(s.stage!='welcome')TextButton(onPressed:_busy?null:_realLogin,child:const LText('Use a real account')),
          const SizedBox(height:28),
        ]))))));
  }
  Widget _card(List<Widget> children,{Color? color})=>Card(elevation:0,color:color??Colors.white,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),
    child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children)));
  Widget _heading(String text)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),
    child:LText(text,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:_navy)));
  List<Widget> _welcome(ProviderDemoStore s)=>[
    Container(padding:const EdgeInsets.all(28),decoration:BoxDecoration(
      gradient:const LinearGradient(colors:[_navy,_purple],begin:Alignment.topRight,end:Alignment.bottomLeft),borderRadius:BorderRadius.circular(28)),
      child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(Icons.handyman_outlined,color:Colors.white,size:54),SizedBox(height:28),
        LText('Sulh for technicians',style:TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.bold)),SizedBox(height:10),
        LText('Your skill. More opportunities.',style:TextStyle(color:Colors.white,fontSize:20)),SizedBox(height:12),
        LText('Try registration, choose your package and manage your work in one place.',style:TextStyle(color:Colors.white70,height:1.6)),
      ])),
    const SizedBox(height:18),
    _card([
      _benefit(Icons.person_outline,'Register without email verification'),
      _benefit(Icons.workspace_premium_outlined,'Choose between three monthly packages'),
      _benefit(Icons.calendar_month_outlined,'Try bookings, reminders and your dashboard'),
    ]),
    const SizedBox(height:18),
    FilledButton(key:const Key('start-provider-demo'),onPressed:_busy?null:()=>_run(s.begin),
      child:const Padding(padding:EdgeInsets.all(14),child:LText('Start technician demo'))),
    TextButton(onPressed:_busy?null:_realLogin,child:const LText('Use a real account')),
  ];
  Widget _benefit(IconData icon,String text)=>Padding(padding:const EdgeInsets.symmetric(vertical:10),
    child:Row(children:[Icon(icon,color:_purple),const SizedBox(width:12),Expanded(child:LText(text))]));
  List<Widget> _registration(ProviderDemoStore s)=>[
    _heading('Create your demo profile'),
    const LText('Use fictional details. A real email and password are not required.'),
    const SizedBox(height:12),
    OutlinedButton.icon(key:const Key('fill-provider-demo'),onPressed:_busy?null:(){setState((){
      _name.text=tr(context,'Sulh demo technician');_email.text='technician@sulh.test';
    });},icon:const Icon(Icons.auto_fix_high),label:const LText('Fill fictional details')),
    _card([Form(key:_form,child:Column(children:[
      TextFormField(controller:_name,decoration:InputDecoration(labelText:tr(context,'Full name')),
        validator:(value)=>(value??'').trim().isEmpty?tr(context,'Please enter your name'):null),
      const SizedBox(height:16),
      TextFormField(controller:_email,keyboardType:TextInputType.emailAddress,textDirection:TextDirection.ltr,
        decoration:InputDecoration(labelText:tr(context,'Demo email (optional)'),hintText:'technician@sulh.test')),
      const SizedBox(height:16),
      DropdownButtonFormField<String>(initialValue:_specialty,decoration:InputDecoration(labelText:tr(context,'Specialty')),
        items:['Plumber','Electrician','AC Repair','Cleaning','Carpenter','Painter'].map((v)=>DropdownMenuItem(value:v,child:LText(v))).toList(),
        onChanged:_busy?null:(value)=>setState(()=>_specialty=value!)),
      const SizedBox(height:16),
      CheckboxListTile(contentPadding:EdgeInsets.zero,value:_agreed,onChanged:_busy?null:(v)=>setState(()=>_agreed=v??false),
        title:const LText('I confirm my stated skills and the accuracy of this demo profile.'),
        subtitle:const LText('Self-declaration is separate from platform verification.')),
    ]))]),
    FilledButton(key:const Key('submit-provider-demo'),onPressed:_busy||!_agreed?null:(){
      if(_form.currentState?.validate()!=true)return;
      _run(()=>s.register(name:_name.text,specialty:_specialty,acknowledged:_agreed));
    },child:const Padding(padding:EdgeInsets.all(14),child:LText('Create demo account and skip verification'))),
    TextButton(onPressed:_busy?null:()=>showDialog<void>(context:context,builder:(dialogContext)=>AlertDialog(
      title:const LText('Password recovery preview'),content:const LText('This demo sends no recovery email and stores no password. Real accounts use the real sign-in flow.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(dialogContext),child:const LText('OK'))])),child:const LText('Preview forgot password')),
  ];
  List<Widget> _plans(ProviderDemoStore s)=>[
    _heading('Choose what suits your work'),
    const LText('All packages are shown. Nothing is selected until you choose it.'),
    const SizedBox(height:12),
    for(final plan in ProviderDemoStore.plans)Padding(padding:const EdgeInsets.only(bottom:12),child:InkWell(
      key:Key('provider-plan-${plan.id}'),borderRadius:BorderRadius.circular(22),onTap:_busy?null:()=>setState(()=>_selectedPlan=plan.id),
      child:Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
        color:_selectedPlan==plan.id?const Color(0xFFF0ECFF):Colors.white,
        borderRadius:BorderRadius.circular(22),border:Border.all(color:_selectedPlan==plan.id?_purple:const Color(0xFFE4E0EE),width:2)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Expanded(child:LText(plan.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold,color:_navy))),
            Icon(_selectedPlan==plan.id?Icons.radio_button_checked:Icons.radio_button_unchecked,color:_purple)]),
          const SizedBox(height:8),
          Row(crossAxisAlignment:CrossAxisAlignment.end,children:[LText('SAR ${plan.price}',style:const TextStyle(fontSize:30,fontWeight:FontWeight.bold,color:_purple)),
            const SizedBox(width:8),const Flexible(child:LText('per month'))]),
          const Divider(height:28),
          _feature('Active services','${plan.services}'),_feature('Portfolio photos','${plan.photos}'),_feature('Coverage radius','${plan.radiusKm} ${tr(context,'km')}'),
          const SizedBox(height:8),
          LText(plan.id=='start'?'Basic activity summary':plan.id=='growth'?'Profile views and booking insights':'Detailed insights and report export'),
          if(plan.id=='pro')const Padding(padding:EdgeInsets.only(top:8),child:LText('Labelled featured placement preview')),
          const SizedBox(height:8),const LText('Bookings, reminders and ratings included'),
        ])),
    )),
    const LText('Package features are previews. Demo selection does not change public search or create a paid subscription.'),
    const SizedBox(height:16),
    FilledButton(key:const Key('activate-provider-plan'),onPressed:_busy||_selectedPlan==null?null:()=>_run(()=>s.activatePlan(_selectedPlan!)),
      child:const Padding(padding:EdgeInsets.all(14),child:LText('Continue with my selected package'))),
  ];
  Widget _feature(String label,String value)=>Padding(padding:const EdgeInsets.symmetric(vertical:4),
    child:Row(children:[const Icon(Icons.check_circle_outline,size:18,color:_teal),const SizedBox(width:8),Expanded(child:LText(label)),Text(value,style:const TextStyle(fontWeight:FontWeight.bold))]));
  List<Widget> _dashboard(ProviderDemoStore s){
    final pending=s.bookings.where((b)=>b.status=='Requested').length;
    final completed=s.bookings.where((b)=>b.status=='Completed').length;
    final rejected=s.bookings.where((b)=>b.status=='Rejected').length;
    final accepted=s.bookings.where((b)=>['Accepted','OnTheWay','InProgress'].contains(b.status)).length;
    final filtered=s.bookings.where((b)=>_filter=='All'||b.status==_filter).toList();
    return [
      Text('${tr(context,'Hello')}, ${s.name}',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold,color:_navy)),
      const SizedBox(height:6),
      Wrap(spacing:8,runSpacing:8,children:[Chip(label:LText(s.specialty)),const Chip(avatar:Icon(Icons.info_outline,size:18),label:LText('Demo self-declaration recorded'))]),
      const SizedBox(height:10),
      Wrap(spacing:10,runSpacing:10,children:[_stat('New requests','$pending'),_stat('Accepted','$accepted'),_stat('Completed','$completed'),_stat('Rejected','$rejected')]),
      _heading('My demo subscription'),
      _card([
        Row(children:[const Icon(Icons.workspace_premium,color:_purple,size:34),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          LText(s.plan!.name,style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),LText('SAR ${s.plan!.price}'),
        ])),const Chip(label:LText('Simulated'))]),
        const SizedBox(height:14),
        LText('${tr(context,'Expires on')}: ${_date(s.subscriptionUntil!)}'),
        const SizedBox(height:12),
        OutlinedButton(onPressed:_busy?null:()=>_run(s.renew),child:const LText('Simulate package renewal')),
        TextButton(onPressed:_busy?null:(){setState(()=>_selectedPlan=null);_run(s.chooseAgain);},child:const LText('View all packages and change my choice')),
        const LText('No charges or automatic renewal in this demo.'),
      ]),
      _heading('Availability and demo location'),
      _card([
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const LText('Available for demo requests'),
          value:s.available,onChanged:_busy?null:(v)=>_run(()=>s.setAvailable(v))),
        const LText('Fictional Riyadh location. Your device location is not accessed.'),
        if(s.locationUpdatedAt!=null)...[
          const SizedBox(height:8),Text('${(24.7136+s.locationStep*0.0005).toStringAsFixed(4)}, ${(46.6753+s.locationStep*0.0005).toStringAsFixed(4)}'),
          LText('${tr(context,'Last simulated update')}: ${_time(s.locationUpdatedAt!)}'),
        ],
        OutlinedButton.icon(onPressed:_busy||!s.available?null:()=>_run(s.simulateLocation),
          icon:const Icon(Icons.location_on_outlined),label:const LText('Simulate location update')),
      ]),
      _heading('Bookings and appointments'),
      Wrap(spacing:8,runSpacing:6,children:['All','Requested','Accepted','OnTheWay','InProgress','Completed','Rejected'].map((value)=>ChoiceChip(
        label:LText(value),selected:_filter==value,onSelected:(_)=>setState(()=>_filter=value))).toList()),
      const SizedBox(height:10),
      if(filtered.isEmpty)const Padding(padding:EdgeInsets.all(20),child:LText('No demo bookings in this category.')),
      for(final booking in filtered)_booking(s,booking),
      _heading('Notifications preview'),
      _card([
        OutlinedButton.icon(onPressed:_busy||accepted==0?null:()=>_run(s.simulateReminder),icon:const Icon(Icons.notifications_active_outlined),
          label:const LText('Simulate a reminder 30 minutes before a booking')),
        const LText('This button previews a reminder. It does not schedule a real device notification.'),
        for(final notice in s.notices.take(5))ListTile(contentPadding:EdgeInsets.zero,
          leading:const Icon(Icons.notifications_none,color:_purple),title:LText(notice)),
      ]),
      _heading('Ratings preview'),
      _card([
        const Row(children:[Icon(Icons.star,color:Colors.amber),SizedBox(width:8),LText('4.8 / 5 — fictional sample')]),
        const SizedBox(height:10),const LText('Excellent service and punctual arrival.'),
        const SizedBox(height:6),const LText('Sample review. No real customer submitted this rating.'),
      ]),
      TextButton.icon(onPressed:_busy?null:_exit,icon:const Icon(Icons.logout),label:const LText('Exit demo')),
    ];
  }
  Widget _stat(String title,String value)=>Container(width:145,padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:const TextStyle(fontSize:28,fontWeight:FontWeight.bold,color:_purple)),LText(title)]));
  String _date(DateTime date)=>'${date.day}/${date.month}/${date.year}';
  String _time(DateTime date)=>'${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}';
  Widget _booking(ProviderDemoStore s,ProviderDemoBooking b){
    final next={'Accepted':'OnTheWay','OnTheWay':'InProgress','InProgress':'Completed'}[b.status];
    final action={'Accepted':'Simulate travel','OnTheWay':'Simulate starting work','InProgress':'Simulate service completion'}[b.status];
    return _card([
      Row(children:[Expanded(child:LText(b.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:17))),const SizedBox(width:8),Chip(label:LText(b.status))]),
      LText(b.customer),const SizedBox(height:8),Text('${_date(b.appointment)} • ${_time(b.appointment)}'),
      const SizedBox(height:6),LText('SAR ${b.amount}'),
      if(b.status=='Requested')...[
        const SizedBox(height:12),Row(children:[
          Expanded(child:OutlinedButton(onPressed:_busy?null:()=>_run(()=>s.advanceBooking(b.id,'Rejected')),child:const LText('Reject'))),
          const SizedBox(width:10),Expanded(child:FilledButton(onPressed:_busy?null:()=>_run(()=>s.advanceBooking(b.id,'Accepted')),child:const LText('Accept'))),
        ]),
      ],
      if(next!=null)...[const SizedBox(height:12),FilledButton(onPressed:_busy?null:()=>_run(()=>s.advanceBooking(b.id,next)),child:LText(action!))],
    ]);
  }
}
