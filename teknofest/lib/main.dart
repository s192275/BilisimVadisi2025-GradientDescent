import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/ip_provider.dart';
import 'widgets/app_drawer.dart';
import 'upload_screen.dart';
import 'history_screen.dart';
import 'models/history_store.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => IpProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İlaç Bilgi Uygulaması',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        // Yaşlılara uygun büyük yazı tipi
        textTheme: TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 18),
          bodyMedium: TextStyle(fontSize: 16),
          bodySmall: TextStyle(fontSize: 14),
          labelLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          labelSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        // Buton teması
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            textStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        // AppBar teması
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal.shade700,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(),
      appBar: AppBar(title: Text('Ana Sayfa')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.teal.shade50,
              Colors.blue.shade50,
              Colors.green.shade50,
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Başlık - Artık buton gibi görünmüyor
                Container(
                  margin: EdgeInsets.only(bottom: 50),
                  child: Column(
                    children: [
                      Text(
                        '🏥',
                        style: TextStyle(fontSize: 48),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'İlaç Bilgi Sistemi',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.teal.shade800,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 3,
                        width: 100,
                        decoration: BoxDecoration(
                          color: Colors.teal.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),

                // Yeni Fotoğraf Yükle Butonu
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: 24),
                  child: ElevatedButton.icon(
                    icon: Icon(
                      Icons.camera_alt,
                      size: 32,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Yeni Fotoğraf Yükle',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.4),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UploadScreen()),
                      );
                    },
                  ),
                ),

                // Önceki Aramalar Butonu
                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: Icon(
                      Icons.history,
                      size: 32,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Önceki Aramalar',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade600,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      shadowColor: Colors.purple.withOpacity(0.4),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HistoryScreen(history: globalHistory),
                        ),
                      );
                    },
                  ),
                ),

                // Alt kısım bilgi metni
                Container(
                  margin: EdgeInsets.only(top: 40),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.teal.shade200,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.teal.shade700,
                        size: 24,
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'İlaç bilgilerinizi kolayca öğrenin',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.teal.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}