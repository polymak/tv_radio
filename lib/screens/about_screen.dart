import 'package:flutter/material.dart';

/// AboutScreen displays application information and creator details
class AboutScreen extends StatelessWidget {
  const AboutScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        backgroundColor: Colors.blueAccent,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo
            Center(
              child: Image.asset(
                'assets/images/logo-app-TVRadio.png',
                width: 120,
                height: 120,
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 24),

            // Title
            Center(
              child: Text(
                'TV Radio RDC',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Content
            const Text(
              'TV Radio RDC est une application Android qui permet d’écouter la radio en direct et de suivre la télévision en direct des chaînes locales et étrangères les plus suivies en RDC.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.6,
              ),
              textAlign: TextAlign.justify,
            ),

            const SizedBox(height: 24),

            const Divider(height: 1),

            const SizedBox(height: 16),

            // Creator Information
            const Text(
              'Informations:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            _buildInfoRow('Créateur', 'Polycarpe Makombo'),
            _buildInfoRow('Date de création', '05 mars 2026 à Kinshasa'),

            const SizedBox(height: 8),

            // Email with clickable link
            Row(
              children: [
                const Text(
                  'Email: ',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
                Expanded(
                  child: Text(
                    'polycarpemakombo@gmail.com',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.blueAccent,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
