import 'package:flutter/material.dart';

class IpProvider extends ChangeNotifier {
  String _ip = 'http://192.168.1.100'; // varsayılan IP

  String get ip => _ip;

  void setIp(String newIp) {
    _ip = newIp;
    notifyListeners();
  }
}
