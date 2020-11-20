import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:qrscan/qrscan.dart' as scanner;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';

import '../key.dart';

class MainScreen extends StatefulWidget {
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  TextEditingController _nameController = new TextEditingController();
  TextEditingController _jobController = new TextEditingController();

  FocusNode _nameFocusNode = new FocusNode();
  FocusNode _jobFocusNode = new FocusNode();

  String _scanResultString = '';
  bool _isScanned = false;
  bool _isSubmitting = false;

  final String postUrl =
      'https://api.airtable.com/v0/' + airtableTableId + '/Worker%20Tracker';

  Widget centerLoader(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;
    return Container(
      height: height,
      width: width,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.blue),
          strokeWidth: 4.0,
        ),
      ),
    );
  }

  Future<void> _qrScan() async {
    _scanResultString = await scanner.scan();
  }

  Future<bool> _addDataToAirtable(
    String name,
    String jobDescription,
    String qrLocation,
    String phoneLocation,
  ) async {
    bool returnBool = false;
    try {
      Dio dio = new Dio();
      // print("Preparing dio data ...");
      print("Sending dio data ...");
      // var response = await dio.get(
      //     "https://api.airtable.com/v0/appNCRtHPb1vPB7lk/Homiee%20Booking%20Confirmation?maxRecords=3&view=Grid%20view");
      // print("Getting dio data ...");
      // print("http response: " + response.data.toString());
      await dio.post(postUrl,
          options: Options(
            contentType: "application/json",
            headers: {
              "Authorization": "Bearer " + airtableApiKey,
            },
          ),
          data: {
            "records": [
              {
                "fields": {
                  "Name": name,
                  "Job Description": jobDescription,
                  "Phone Location": phoneLocation,
                  "QR Location": qrLocation,
                  "Timestamp": DateTime.now().toIso8601String(),
                }
              }
            ]
          }).then((value) {
        print("Getting dio data ...");
        returnBool = true;
      });
    } catch (e) {
      print(e);
      returnBool = false;
    }

    return returnBool;
  }

  Future<String> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String location = placemarks[0].locality +
          ', ' +
          placemarks[0].postalCode +
          ', ' +
          placemarks[0].country;

      return location;
    } catch (e) {
      print(e);
      return null;
    }
  }

  void _submit() async {
    if (_formKey.currentState.validate()) {
      if (_scanResultString != '') {
        setState(() {
          _isSubmitting = true;
        });
        String phoneLocation = await _getCurrentLocation();
        await _addDataToAirtable(
          _nameController.text,
          _jobController.text,
          _scanResultString,
          phoneLocation,
        ).then((value) {
          if (value) {
            setState(() {
              _isSubmitting = false;
            });
            Fluttertoast.showToast(
              msg: 'Submitted successfully',
              textColor: Colors.white,
              backgroundColor: Colors.green,
            );
          } else {
            setState(() {
              _isSubmitting = false;
            });
            Fluttertoast.showToast(
              msg:
                  'Something went wrong. Please check your internet connection',
              textColor: Colors.white,
              backgroundColor: Colors.red,
            );
          }
        });
      } else {
        Fluttertoast.showToast(
          msg: 'Please scan QR to get location',
          textColor: Colors.white,
          backgroundColor: Colors.red,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;

    return Scaffold(
        body: SafeArea(
      child: SingleChildScrollView(
          child: Stack(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(10),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    height: deviceSize.height / 3,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                          image: AssetImage('assets/images/homiee_logo.png'),
                          fit: BoxFit.contain),
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: TextFormField(
                      controller: _nameController,
                      focusNode: _nameFocusNode,
                      decoration: InputDecoration(labelText: 'Name'),
                      validator: (value) {
                        if (value == '') return 'Name is required';
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: TextFormField(
                      controller: _jobController,
                      focusNode: _jobFocusNode,
                      decoration: InputDecoration(labelText: 'Job'),
                      validator: (value) {
                        if (value == '') return 'Job description is required';
                        return null;
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: _isScanned
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              RichText(
                                  text: TextSpan(
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 18,
                                      ),
                                      children: [
                                    TextSpan(text: 'Location: '),
                                    TextSpan(
                                        text: _scanResultString,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))
                                  ])),
                              IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _scanResultString = '';
                                      _isScanned = false;
                                    });
                                  })
                            ],
                          )
                        : RaisedButton(
                            child: Text('Scan QR'),
                            onPressed: () async {
                              _jobFocusNode.unfocus();
                              _nameFocusNode.unfocus();
                              _qrScan().then((_) {
                                setState(() {
                                  _isScanned = true;
                                });
                              });
                              // Navigator.of(context)
                              //     .pushNamed(QrScanScreen.route)
                              //     .then((value) {
                              //   print('<main_screen.dart> value: ' + value);
                              // });
                            }),
                  ),
                  // SizedBox(height: 20),
                  // Container(
                  //   width: double.infinity,
                  //   padding: EdgeInsets.symmetric(horizontal: 30),
                  //   child: RaisedButton(
                  //     child: Text('Exact Location'),
                  //     onPressed: () async {
                  //       Position position = await Geolocator.getCurrentPosition();
                  //       List<Placemark> placemarks =
                  //           await placemarkFromCoordinates(
                  //               position.latitude, position.longitude);
                  //       print('<main_screen.dart> current area: ' +
                  //           placemarks[0].administrativeArea);
                  //       print('<main_screen.dart> current sub area: ' +
                  //           placemarks[0].subAdministrativeArea);
                  //       print('<main_screen.dart> current locality: ' +
                  //           placemarks[0].locality);
                  //       print('<main_screen.dart> current postal code: ' +
                  //           placemarks[0].postalCode);
                  //       print('<main_screen.dart> current country: ' +
                  //           placemarks[0].country);
                  //       // print('<main_screen.dart> position longitude: ' +
                  //       //     position.longitude.toString());
                  //     },
                  //   ),
                  // ),
                  SizedBox(height: 20),
                  Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(horizontal: 30),
                      child: !_isSubmitting
                          ? RaisedButton(
                              child: Text('Submit'),
                              onPressed: () => _submit(),
                            )
                          : Center(
                              child: CircularProgressIndicator(),
                            )),
                ],
              ),
            ),
          ),
          //  _isSubmitting ? centerLoader(context) : Container()
          // centerLoader(context)
        ],
      )),
    ));
  }
}
