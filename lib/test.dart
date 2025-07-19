import 'package:flutter/material.dart';
import 'package:resqmob/modules/coordinate%20to%20location.dart';

class test extends StatefulWidget {
  const test({super.key});

  @override
  State<test> createState() => _testState();
}

class _testState extends State<test> {
  late var address="blabla";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View All User'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,),
          body: Column(
            children: [
              Center(
                      child: Text(address),
                  ),
              const SizedBox(height: 10,),
              TextButton(onPressed: ()async{
               address=await getAddressFromLatLng(23.768085636441658, 90.4281498393334);
              }, child: Text("get location"))
            ],
          ),
    );
  }
}
