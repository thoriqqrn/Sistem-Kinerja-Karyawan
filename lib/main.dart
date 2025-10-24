import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // File ini di-generate otomatis
import 'login_page.dart'; // Import halaman login yang akan kita buat
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Pastikan semua widget siap sebelum menjalankan aplikasi
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistem Kinerja',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginPage(), // Kita akan buat halaman ini selanjutnya
    );
  }
}
