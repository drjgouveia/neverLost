import 'dart:convert';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class Contact {
  String pin = "0000";
  String name = "";
  String number = "";

  Contact(String pin, String number, String name) {
    this.name = name;
    this.number = number;
    this.pin = pin;
  }

  Contact.fromJSON(Map<String, dynamic> json) {
    this.pin = json["pin"];
    this.name = json["name"];
    this.number = json["number"];
  }

  Map<String, dynamic> toJson() => {
    "pin": this.pin,
    "number": this.number,
    "name": this.name,
  };
}