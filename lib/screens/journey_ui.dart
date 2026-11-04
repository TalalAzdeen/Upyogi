import 'package:flutter/material.dart';
import '../l10n/app_language.dart';

const journeyPurple=Color(0xFF6C5CE7);
const journeyNavy=Color(0xFF191630);
const journeyTeal=Color(0xFF078779);
String journeyDate(DateTime d)=>'${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
Widget journeyCard(List<Widget> children)=>Card(elevation:0,color:Colors.white,
  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(22)),child:Padding(padding:const EdgeInsets.all(18),
    child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children)));
Widget journeyHeading(String title)=>Padding(padding:const EdgeInsets.symmetric(vertical:14),
  child:LText(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold,color:journeyNavy)));
class JourneyBanner extends StatelessWidget{
  const JourneyBanner({super.key});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),margin:const EdgeInsets.only(bottom:16),
    decoration:BoxDecoration(color:const Color(0xFFE5F3EF),borderRadius:BorderRadius.circular(14)),
    child:const Row(children:[Icon(Icons.science_outlined,color:journeyTeal),SizedBox(width:10),Expanded(child:LText(
      'Connected demo on this device only. No real payment, email, GPS or background notification.',style:TextStyle(color:journeyTeal,fontSize:12)))]));
}
IconData journeyIcon(String category)=>switch(category){'Plumber'=>Icons.plumbing,'Electrician'=>Icons.electrical_services,
  'AC Repair'=>Icons.ac_unit,'Cleaning'=>Icons.cleaning_services,'Carpenter'=>Icons.chair_outlined,'Painter'=>Icons.format_paint,
  'Appliance Repair'=>Icons.kitchen_outlined,_=>Icons.pest_control};
Widget journeyEmpty(String title,IconData icon)=>Padding(padding:const EdgeInsets.symmetric(vertical:32),
  child:Column(children:[Icon(icon,size:48,color:journeyPurple),const SizedBox(height:12),LText(title,textAlign:TextAlign.center)]));
