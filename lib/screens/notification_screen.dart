import 'package:flutter/material.dart';
import 'package:apps_packagebox/services/notification_service.dart';
import 'package:apps_packagebox/pages/home_page.dart';
import 'package:apps_packagebox/auth/auth_choice.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  void _showNotificationDialog({required bool success, String? errorMessage}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.check_circle : Icons.error,
                  color: success ? Colors.green : Colors.red,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  success 
                    ? 'Notifikasi Berhasil Diaktifkan'
                    : 'Gagal Mengaktifkan Notifikasi',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  success 
                    ? 'Anda akan menerima pemberitahuan tentang status box'
                    : errorMessage ?? 'Silakan coba lagi nanti',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context); // Close dialog
                      if (success) {
                        await _navigateToNextScreen();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: success ? Colors.blue : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      success ? 'Lanjutkan' : 'Tutup',  
                      style: const TextStyle(fontSize: 16
                        , color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => isLoggedIn 
            ? const HomePage() 
            : const AuthChoiceScreen(),
        ),
      );
    }
  }

  Future<void> _handleNotificationPermission(bool allow) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (allow) {
        // Inisialisasi notifikasi
        await _notificationService.initialize();
        final success = await _notificationService.registerDeviceToken();

        if (success) {
          // PENTING: Simpan bahwa notifikasi sudah diaktifkan
          await prefs.setBool('isNotificationEnabled', true);
          
          if (mounted) {
            // Navigasi ke screen berikutnya
            await _navigateToNextScreen();
          }
        } else if (mounted) {
          _showNotificationDialog(
            success: false,
            errorMessage: 'Gagal mengaktifkan notifikasi. Silakan coba lagi.',
          );
        }
      } else {
        // Jika user memilih "Nanti Saja", tetap set bahwa keputusan sudah dibuat
        // tapi notifikasi tidak diaktifkan
        await prefs.setBool('isNotificationEnabled', false);
        await _navigateToNextScreen();
      }
    } catch (e) {
      if (mounted) {
        _showNotificationDialog(
          success: false,
          errorMessage: 'Error: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'asset/images/logow.png',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 32),
              const Text(
                'Aktifkan Notifikasi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Dapatkan pemberitahuan tentang status box dan pembaruan penting lainnya',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _handleNotificationPermission(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Aktifkan Notifikasi',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _handleNotificationPermission(false),
                      child: const Text(
                        'Nanti Saja',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}