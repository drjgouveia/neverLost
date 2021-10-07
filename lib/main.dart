import 'dart:async';
import 'dart:convert';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:never_lost/contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:telephony/telephony.dart';
import 'sms_handler.dart' as sms_handler;

List<Contact> contacts_save = [];

Future<List<Contact>> loadContacts() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await Future.delayed(const Duration(seconds: 1));
  prefs.reload();

  List<dynamic> conts = jsonDecode(prefs.getString("contacts") ?? "[]");
  List<Contact> contacts = [];
  for (int i=0; i < conts.length; i++) {
    print(jsonDecode(conts[i]));
    contacts.add(Contact.fromJSON(jsonDecode(conts[i])));
  }

  contacts_save = contacts;
  return contacts;
}

void stopRinging() {
  FlutterRingtonePlayer.stop();
}

void SmsHandler(SmsMessage msg) async {
  List<Contact> contacts = await loadContacts();

  print(msg);

  bool verif = false;
  for(int i=0; i < contacts.length; i++) {
    if(msg.address!.contains(contacts[i].number) && msg.body!.contains(contacts[i].pin)) {
      verif = true;
    }
  }

  if(verif == true) {
    print("ENTROU!");
    Fluttertoast.showToast(
        msg: "Entrou!",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black45,
        textColor: Colors.white,
        fontSize: 16.0
    );

    if (msg.body!.contains("start") == true) {
      FlutterRingtonePlayer.playAlarm(volume: 1.0, asAlarm: true);
    } else {
      FlutterRingtonePlayer.stop();
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBackgroundService.initialize(onStart);

  final Telephony telephony = Telephony.instance;

  telephony.listenIncomingSms(
    onNewMessage: SmsHandler,
    onBackgroundMessage: SmsHandler,
    listenInBackground: true
  );

  runApp(MyApp());
}


class LifecycleEventHandler extends WidgetsBindingObserver {

  LifecycleEventHandler();

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    WidgetsFlutterBinding.ensureInitialized();
    switch (state) {
      case AppLifecycleState.resumed:
        FlutterBackgroundService().sendData(
            {"action": "setAsBackground"}
        );
        break;

      case AppLifecycleState.inactive:
        FlutterBackgroundService().sendData(
            {"action": "setAsForeground"}
        );
        FlutterRingtonePlayer.stop();
        break;

      case AppLifecycleState.paused:
        FlutterBackgroundService().sendData(
            {"action": "setAsForeground"}
        );
        FlutterRingtonePlayer.stop();
        break;

      case AppLifecycleState.detached:
        FlutterBackgroundService().sendData(
            {"action": "setAsForeground"}
        );
        FlutterRingtonePlayer.stop();
        break;
    }
  }
}


Future<void> onStart() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterBackgroundService service = FlutterBackgroundService();

  service.onDataReceived.listen((event) {
    if (event!["action"] == "setAsForeground") {
      print("started service foreground");
      service.setForegroundMode(true);
      return;
    }

    if (event["action"] == "setAsBackground") {
      print("started service background");
      service.setForegroundMode(false);
    }

    if (event["action"] == "stopService") {
      print("stopping service");
      service.stopBackgroundService();
    }
  });

  service.setForegroundMode(true);
  service.setAutoStartOnBootMode(true);

  Timer.periodic(Duration(seconds: 30), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "Never Lost service",
      content: "Keeping an eye on the incoming SMS",
    );
  });
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        primaryTextTheme: TextTheme(
            headline6: TextStyle(
                color: Colors.white
            )
        ),
      ),
      home: ExpansionTileDemo(),
    );
  }
}

class ExpansionTileDemo extends StatefulWidget {
  @override
  _ExpansionTileDemoState createState() => _ExpansionTileDemoState();
}

class FullScreenDialog extends StatelessWidget {
  String pin="0000", phone="000000000", name="";
  final phoneController = TextEditingController();
  final codeController = TextEditingController();
  final nameController = TextEditingController();
  List<Contact> contacts = [];
  late SharedPreferences prefs;

  Future<void> loadContacts() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(seconds: 1));
    this.prefs = prefs;
    prefs.reload();
    List<dynamic> conts = jsonDecode(prefs.getString("contacts") ?? "[]");
    this.contacts = [];

    for (int i = 0; i < conts.length; i++) {
      this.contacts.add(Contact.fromJSON(jsonDecode(conts[i])));
    }
    print(this.contacts.toString());
  }

  @override
  Widget build(BuildContext context) {
    loadContacts();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Contact details', style: TextStyle(color: Colors.black54)),
        actions: [
          new FlatButton(
            onPressed: () async {
              print("On pressed");
              if(this.name != "" && this.phone != "000000000") {
                await loadContacts();
                prefs.reload();
                this.contacts.add(Contact(this.pin, this.phone, this.name));
                List<dynamic> json = [];
                for (int i = 0; i < this.contacts.length; i++) {
                  print(jsonEncode(this.contacts[i].toJson()));
                  json.add(jsonEncode(this.contacts[i].toJson()));
                }
                print(json);
                this.prefs.setString("contacts", jsonEncode(json));
                print(jsonEncode(json));
                Navigator.pop(context, this.contacts);
              } else {
                Fluttertoast.showToast(
                    msg: "Information inputted invalid. Try again",
                    toastLength: Toast.LENGTH_LONG,
                    gravity: ToastGravity.CENTER,
                    timeInSecForIosWeb: 1,
                    backgroundColor: Colors.black45,
                    textColor: Colors.white,
                    fontSize: 16.0
                );
              }
            },
            child: Text("ADD CONTACT")
          )
        ],
      ),
      body:
        Padding(
          padding: EdgeInsets.symmetric(vertical: 35),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text("Insert the contact\'s data",  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17)),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.fromLTRB(25, 0, 25, 15),
                        child: TextField(
                          controller: nameController,
                          decoration: InputDecoration(labelText: "Enter contacts\' name"),
                          onChanged: (text) {
                            this.name = nameController.text;
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(25, 0, 25, 15),
                        child: TextField(
                          controller: phoneController,
                          decoration: InputDecoration(labelText: "Enter phone number"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (text) {
                            this.phone = phoneController.text;
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(25, 0, 25, 15),
                        child: TextField(
                          controller: codeController,
                          decoration: InputDecoration(labelText: "Enter control pin"),
                          keyboardType: TextInputType.number,
                          inputFormatters: <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (text) {
                            this.pin = codeController.text;
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ]
        ),
      ),
    );
  }
}

class _ExpansionTileDemoState extends State<ExpansionTileDemo> {
  List<Contact> contacts = [];
  late SharedPreferences prefs;

  Future<List<Contact>> loadContacts() async {
    WidgetsFlutterBinding.ensureInitialized();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await Future.delayed(const Duration(seconds: 1));
    this.prefs = prefs;
    prefs.reload();

    List<dynamic> conts = jsonDecode(prefs.getString("contacts") ?? "[]");
    this.contacts = [];
    for (int i=0; i < conts.length; i++) {
      print(jsonDecode(conts[i]));
      this.contacts.add(Contact.fromJSON(jsonDecode(conts[i])));
    }

    print(this.contacts.toString());
    setState(() {
      this.contacts = this.contacts;
    });
    return this.contacts;
  }

  void saveContacts() {
    List<dynamic> json = [];
    for (int i = 0; i < this.contacts.length; i++) {
      print(jsonEncode(this.contacts[i].toJson()));
      json.add(jsonEncode(this.contacts[i].toJson()));
    }

    this.prefs.setString("contacts", jsonEncode(json));
  }

  @override
  void initState() {
    WidgetsFlutterBinding.ensureInitialized();
    // WidgetsBinding.instance!.addObserver(LifecycleEventHandler());
    FlutterBackgroundService().sendData(
        {"action": "setAsForeground"}
    );
    loadContacts();
    super.initState();
    print("Main");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadContacts(),
      builder: (context, snapshot){
        if (this.contacts.length >= 0) {
          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              title: Padding(
                padding: EdgeInsets.all(0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Never Lost',
                          style: TextStyle(color: Colors.black54)),
                      FlatButton(onPressed: () {
                        FlutterRingtonePlayer.stop();
                      },
                        child: Text('Stop ringing',
                            style: TextStyle(color: Colors.redAccent)),
                      )
                    ]
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
            body: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 0.0, vertical: 20),
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                shrinkWrap: true,
                physics: BouncingScrollPhysics(),
                itemCount: this.contacts.length,
                itemBuilder: (BuildContext context, int index) {
                  return _buildPlayerModelList(this.contacts[index]);
                },
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                this.contacts = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => FullScreenDialog(),
                    fullscreenDialog: true,
                  ),
                );
                setState(() {});
              },
              tooltip: 'Add contact',
              child: Icon(Icons.add),
              foregroundColor: Colors.white,
            ),
          );
        } else {
          return Center(
            child: CircularProgressIndicator(),
          );
        }
      }
    );
  }

  Widget _buildPlayerModelList(Contact item) {
    return Card(
      child: ExpansionTile(
        title: Text(
          item.name,
          style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w600),
        ),
        children: <Widget>[
          ListTile(
            title: Text(
              "Phone number: ${item.number}",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "PIN: ${item.pin}",
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            trailing: FlatButton(
              onPressed: () {
                this.contacts.remove(item);
                saveContacts();
                setState(() {});
              },
              child: Icon(Icons.delete)
            ),
          )
        ],
      ),
    );
  }
}
