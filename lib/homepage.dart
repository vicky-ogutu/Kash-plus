import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Try extends StatefulWidget {
  const Try({super.key});

  @override
  State<Try> createState() => _TryState();
}

class _TryState extends State<Try> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: try2(),
    );
  }
}


class try2 extends StatelessWidget {
  const try2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(

      ),
    );
  }
}

// Widget text2(){
//   return Container(){
//
//   }
// }