import 'package:flutter/material.dart';
import 'package:roadside_service/features/pricing_engine/domain/repositories/admin_repository.dart';
import '../../../../core/di/injection_container.dart';

class PolicyHubScreen extends StatefulWidget {
  const PolicyHubScreen({super.key});

  @override
  State<PolicyHubScreen> createState() => _PolicyHubScreenState();
}

class _PolicyHubScreenState extends State<PolicyHubScreen> {
  final AdminRepository _repo = sl<AdminRepository>();
  final _textCtrl = TextEditingController();
  String _selectedDoc = 'TermsOfService';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    _textCtrl.text = await _repo.getPolicyDocument(_selectedDoc);
    setState(() => _isLoading = false);
  }

  Future<void> _saveDocument() async {
    await _repo.updatePolicyDocument(_selectedDoc, _textCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document updated successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Policy Documents')),
      body: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedDoc,
                    decoration: const InputDecoration(
                      labelText: 'Select Document to Edit',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'TermsOfService',
                        child: Text('Terms of Service'),
                      ),
                      DropdownMenuItem(
                        value: 'PrivacyPolicy',
                        child: Text('Privacy Policy'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedDoc = v!);
                      _loadDocument();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _saveDocument,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Document'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      expands: true,
                      decoration: const InputDecoration(
                        hintText: 'Enter document text here...',
                        border: OutlineInputBorder(),
                        filled: true,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
