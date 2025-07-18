import 'package:flutter/material.dart';

class test extends StatelessWidget {
  const test({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View All User'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,),
          body: Center(
        child: Text("hello"),
    ),
    );
  }
}
