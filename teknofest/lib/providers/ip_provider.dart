import 'package:flutter/material.dart';

class IpProvider extends ChangeNotifier {
  String _ip = 'http://192.168.1.100'; // varsayılan IP bu ip adresi ana makinenin IP adresi ile değişmeli

  String get ip => _ip;

  void setIp(String newIp) {
    //yeni IP adresini atayıp haberleşmeyi bu IP adresi aracılığı ile yapılır.
    _ip = newIp;
    notifyListeners();
  }
}
