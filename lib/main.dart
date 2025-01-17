import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:requests/requests.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:html/parser.dart' show parse;

Uint8List dataFromBase64String(String base64String) {
  return base64Decode(base64String);
}

String base64String(List<int> data) {
  return base64Encode(data);
}

void main() {
  runApp(MyApp());
}

Future<List<String>> getData(user, password) async {
  if (user != "") {
    // (if not refresh)
    await Requests.clearStoredCookies(Requests.getHostname("https://mon-espace.izly.fr/"));
    var get_verif_code = await Requests.get("https://mon-espace.izly.fr/");
    get_verif_code.raiseForStatus();
    var homepage = parse(get_verif_code.content());
    var veriftoken =
        homepage.getElementsByClassName("form-horizontal")[0].getElementsByTagName("input")[0].attributes["value"];

    var login_req = await Requests.post("https://mon-espace.izly.fr/Home/Logon",
        body: {"Username": user, "Password": password, "__RequestVerificationToken": veriftoken, "ReturnUrl": "/"});
    login_req.raiseForStatus();
  }

  var qrcode_req = await Requests.post("https://mon-espace.izly.fr/Home/CreateQrCodeImg", body: {"numberOfQrCodes": 1});
  qrcode_req.raiseForStatus();
  var status = qrcode_req.statusCode.toString();
  var qrcode_base64 = qrcode_req.json()[0];

  var balance_req = await Requests.get("https://mon-espace.izly.fr/Home");
  balance_req.raiseForStatus();
  var izlyhomepage = parse(balance_req.content());
  var data = izlyhomepage.getElementsByClassName("balance-text order-2")[0].innerHtml;
  String balance_formated = data.split("+")[1].split("<")[0] + "€";
  return [status, balance_formated, qrcode_base64];
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  _MyAppState createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> {
  final TextEditingController _controller = TextEditingController();
  Future<List<String>>? izly_data;
  bool showForm = false;

  String? username;
  String? password;

  // Create storage
  final storage = new FlutterSecureStorage();

  Future writeSecureData(String key, String value) async {
    await storage.write(key: key, value: value);
  }

  Future<String?> readSecureData(String key) async {
    return await storage.read(key: key);
  }

  void initapp() async {
    username = await readSecureData("username");
    password = await readSecureData("password");
    setState(() {
      if (username != null && password != null) {
        showForm = false;
        izly_data = getData(username, password);
      } else {
        showForm = true;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    initapp();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Izly QR Code')),
        body: Center(
          child: showForm ? loginForm(context) : buildQRCodeContainer(),
        ),
      ),
    );
  }

  Container buildQRCodeContainer() {
    return Container(
      child: GestureDetector(
        onTap: () {
          setState(() {
            izly_data = getData("", "");
          });
        },
        onLongPress: () {
          setState(() {
            showForm = true;
          });
        },
        child: Container(
          child: buildFutureQRcode(),
        ),
      ),
    );
  }

  FutureBuilder<List<String>> buildFutureQRcode() {
    return FutureBuilder<List<String>>(
      future: izly_data,
      builder: (context, snapshot) {
        if (snapshot.hasData && (snapshot.data![0] == "302" || snapshot.data![0] == "200")) {
          String qrcode = snapshot.data![2];
          String balance = snapshot.data![1];
          return Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  balance,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(0.0),
                child: Image.memory(
                  dataFromBase64String(qrcode),
                  fit: BoxFit.contain,
                  width: 150,
                  height: 150,
                ),
              ),
            ],
          );
        } else if (snapshot.hasError) {
          return Text("${snapshot.error}");
        }
        return CircularProgressIndicator();
      },
    );
  }

  // Show login form
  Form loginForm(BuildContext context) {
    final UsernameController = TextEditingController();
    final PasswordController = TextEditingController();

    @override
    void dispose() {
      UsernameController.dispose();
      PasswordController.dispose();
      super.dispose();
    }

    final _formKey = GlobalKey<FormState>();
    return Form(
      key: _formKey,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          height: 45.0,
          width: 150.0,
          child: TextFormField(
            controller: UsernameController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              icon: Icon(Icons.person),
              hintText: 'User',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ne peut pas être vide';
              }
              return null;
            },
          ),
        ),
        SizedBox(
          height: 45.0,
          width: 150.0,
          child: TextFormField(
            controller: PasswordController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              icon: Icon(Icons.lock),
              hintText: 'Password',
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Ne peut pas être vide';
              }
              return null;
            },
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10.0),
          child: ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                writeSecureData("username", UsernameController.text);
                writeSecureData("password", PasswordController.text);
                setState(() {
                  izly_data = getData(UsernameController.text, PasswordController.text);
                  showForm = false;
                });
              }
            },
            child: const Text('Connexion'),
          ),
        ),
      ]),
    );
  }
}