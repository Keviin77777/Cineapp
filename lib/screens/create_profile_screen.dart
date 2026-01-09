import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/profile.dart';

class CreateProfileScreen extends StatefulWidget {
  const CreateProfileScreen({super.key});

  @override
  State<CreateProfileScreen> createState() => _CreateProfileScreenState();
}

class _CreateProfileScreenState extends State<CreateProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedAvatar = 'M';
  String _selectedColor = '0xFFE74C3C';

  // Avatares de personagens com cores e iniciais
  final List<Map<String, dynamic>> _avatars = [
    {
      'initial': 'M',
      'color': '0xFFE74C3C',
      'name': 'Miguel',
      'gradient': ['0xFFE74C3C', '0xFFC0392B']
    },
    {
      'initial': 'S',
      'color': '0xFFE91E63',
      'name': 'Sam',
      'gradient': ['0xFFE91E63', '0xFFC2185B']
    },
    {
      'initial': 'T',
      'color': '0xFF3498DB',
      'name': 'Tory',
      'gradient': ['0xFF3498DB', '0xFF2980B9']
    },
    {
      'initial': 'E',
      'color': '0xFF9B59B6',
      'name': 'Eleven',
      'gradient': ['0xFF9B59B6', '0xFF8E44AD']
    },
    {
      'initial': 'I',
      'color': '0xFFF39C12',
      'name': 'Iron Man',
      'gradient': ['0xFFF39C12', '0xFFE67E22']
    },
    {
      'initial': 'P',
      'color': '0xFFE74C3C',
      'name': 'Peter',
      'gradient': ['0xFFE74C3C', '0xFFDC143C']
    },
    {
      'initial': 'M',
      'color': '0xFF1ABC9C',
      'name': 'MJ',
      'gradient': ['0xFF1ABC9C', '0xFF16A085']
    },
    {
      'initial': 'H',
      'color': '0xFFFF6B9D',
      'name': 'Harley',
      'gradient': ['0xFFFF6B9D', '0xFFFF1493']
    },
    {
      'initial': 'K',
      'color': '0xFF2ECC71',
      'name': 'Ken',
      'gradient': ['0xFF2ECC71', '0xFF27AE60']
    },
    {
      'initial': 'B',
      'color': '0xFFFF1493',
      'name': 'Barbie',
      'gradient': ['0xFFFF1493', '0xFFFF69B4']
    },
    {
      'initial': 'C',
      'color': '0xFF4169E1',
      'name': 'Cap',
      'gradient': ['0xFF4169E1', '0xFF0000CD']
    },
    {
      'initial': 'W',
      'color': '0xFF8B008B',
      'name': 'Wanda',
      'gradient': ['0xFF8B008B', '0xFF9400D3']
    },
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, digite um nome')),
      );
      return;
    }

    final profile = Profile(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      avatarUrl: _selectedAvatar,
      backgroundColor: _selectedColor,
    );

    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList('profiles') ?? [];
    profilesJson.add(jsonEncode(profile.toJson()));
    await prefs.setStringList('profiles', profilesJson);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Perfil'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nome do Perfil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Digite seu nome',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Escolha seu Avatar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 15,
                mainAxisSpacing: 20,
                childAspectRatio: 0.75,
              ),
              itemCount: _avatars.length,
              itemBuilder: (context, index) {
                final avatar = _avatars[index];
                final isSelected = _selectedAvatar == avatar['initial'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAvatar = avatar['initial']!;
                      _selectedColor = avatar['color']!;
                    });
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(int.parse(avatar['gradient'][0])),
                              Color(int.parse(avatar['gradient'][1])),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white.withOpacity(0.3),
                            width: isSelected ? 3 : 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            avatar['initial']!,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        avatar['name']!,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[400],
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Criar Perfil',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
