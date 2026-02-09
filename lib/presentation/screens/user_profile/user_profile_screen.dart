import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart';
import '../../providers/user_provider.dart';
import '../../../core/theme/app_colors.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  late TextEditingController _nameController;
  String? _selectedCountry;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _initializeFromProfile() {
    final profile = ref.read(userProfileProvider).value;
    if (profile != null) {
      _nameController.text = profile.name;
      _selectedCountry = profile.country;
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                _initializeFromProfile();
                setState(() => _isEditing = true);
              },
            ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          if (!_isEditing && _nameController.text.isEmpty) {
            _nameController.text = profile.name;
            _selectedCountry = profile.country;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.name.isNotEmpty ? profile.name[0].toUpperCase() : 'P',
                    style: const TextStyle(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (_isEditing) ...[
                  // Edit Mode
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.flag),
                    title: const Text('Country'),
                    subtitle: Text(_getCountryName(_selectedCountry ?? profile.country)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        onSelect: (Country country) {
                          setState(() {
                            _selectedCountry = country.countryCode;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _isEditing = false);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await ref.read(userProfileProvider.notifier).updateProfile(
                                  name: _nameController.text.trim(),
                                  country: _selectedCountry,
                                );
                            setState(() => _isEditing = false);
                          },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // View Mode
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: const Text('Name'),
                            subtitle: Text(
                              profile.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          const Divider(),
                          ListTile(
                            leading: const Icon(Icons.flag),
                            title: const Text('Country'),
                            subtitle: Text(
                              _getCountryName(profile.country),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }

  String _getCountryName(String code) {
    try {
      final country = CountryParser.parseCountryCode(code);
      return '${country.flagEmoji} ${country.name}';
    } catch (e) {
      return code;
    }
  }
}
