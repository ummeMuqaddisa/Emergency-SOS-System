import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:resqmob/pages/authentication/signup.dart';
import '../../Class Models/user.dart';
import '../../backend/firebase config/Authentication.dart';
import '../../main.dart';

class login extends StatefulWidget {
  const login({super.key});

  @override
  State<login> createState() => _loginState();
}

class _loginState extends State<login> {
  String btn_text = "Log in";
  bool isloading = false;
  bool loading = false;
  bool _obscurePassword = true;

  // Controllers defined outside build to prevent reset on rebuild
  final TextEditingController email = TextEditingController();
  final TextEditingController password = TextEditingController();



  Future<bool> signin(
      {required String email, required String password,context}) async {
    try{
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      User? user = FirebaseAuth.instance.currentUser;
      print("success");
      print(FirebaseAuth.instance.currentUser);

      //fcm token update
      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(user!.uid)
              .update({
            'fcmToken': fcmToken,
          });
        }
      }

      final data=await FirebaseFirestore.instance.collection("Users").doc(user!.uid).get();
      UserModel cuser=UserModel.fromJson((data).data()!);
      await Future.delayed(Duration(seconds: 1));

      // if(cuser.admin==true)
      //   Navigator.of(context).pushAndRemoveUntil(
      //     MaterialPageRoute(builder: (context) => MyHomePage()), (Route<dynamic> route) => false,);
      //  else
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context)=>MyHomePage(),));

    } on FirebaseAuthException catch (e){
      if(e.code=='user-not-found'){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( e.code.toString())) );
        return false;
      }
      else if(e.code=='wrong-password'){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( e.code.toString())) );
        return false;
      }
      else if(e.code=='invalid-email'){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( e.code.toString())) );
        return false;
      }
      else{
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( e.code.toString())) );
        return false;
      }



    }
    catch(e){
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text( e.toString())) );
      return false;
    }
    return true;
  }
  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 80,
                width: 80,
                child: CircularProgressIndicator(
                  color: Color(0xff093125),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 24),
              Text(
                "Logging in...",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff093125),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // SizedBox(height: 40),
                  // // Logo container
                  // Container(
                  //   height: 120,
                  //   width: 120,
                  //   decoration: BoxDecoration(
                  //
                  //     borderRadius: BorderRadius.circular(20),
                  //     boxShadow: [
                  //       BoxShadow(
                  //         color: Colors.black.withOpacity(0.1),
                  //         blurRadius: 10,
                  //         offset: Offset(0, 4),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  SizedBox(height: 40),
                  // Welcome text
                  Text(
                    "Welcome Back",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    "Sign in to continue",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 40),
                  // Email field
                  TextField(
                    controller: email,
                    decoration: InputDecoration(
                      labelText: "Username",
                      hintText: "Enter Username",
                      prefixIcon: Icon(Icons.person_outline, color: Colors.black,),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      floatingLabelStyle: TextStyle(color: Colors.black,),
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Password field
                  TextField(
                    controller: password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: "Password",
                      hintText: "Enter Password",
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.black,),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.black, width: 2),
                      ),
                      floatingLabelStyle: TextStyle(color: Colors.black,),
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  // SizedBox(height: 16),
                  // // Forgot password
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //   child: TextButton(
                  //     onPressed: () {
                  //       // Forgot password functionality can be added here
                  //     },
                  //     child: Text(
                  //       "Forgot Password?",
                  //       style: TextStyle(
                  //         color: Color(0xff093125),
                  //         fontWeight: FontWeight.w500,
                  //       ),
                  //     ),
                  //   ),
                  // ),
                  SizedBox(height: 24),
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        setState(() {
                          loading = true;
                          btn_text = "Logging in...";
                        });

                        isloading = await signin(
                            email: email.text.trim(),
                            password: password.text,
                            context: context
                        );

                        if (!isloading) {
                          Timer(Duration(milliseconds: 50), () {
                            setState(() {
                              loading = false;
                              btn_text = "Log in";
                            });
                          });
                        }
                      },
                      child: Text(
                        btn_text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 30),
                  // Sign up row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      TextButton(
                        onPressed: () {

                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => signup()),
                          );

                        },
                        child: Text(
                          "Sign Up",
                          style: TextStyle(
                            color: Color(0xff093125),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}
