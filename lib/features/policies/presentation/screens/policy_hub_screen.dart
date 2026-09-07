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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() => _isLoading = true);
    try {
      final text = await _repo.getPolicyDocument(_selectedDoc);
      if (mounted) {
        setState(() {
          _textCtrl.text = text;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load document.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveDocument() async {
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Document cannot be empty.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.updatePolicyDocument(_selectedDoc, _textCtrl.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Legal Document updated and published successfully.',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Network error. Failed to save document.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Light theme compliant
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDoc,
                        dropdownColor: theme.cardColor,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Select Legal Entity',
                          filled: true,
                          fillColor: theme.scaffoldBackgroundColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'TermsOfService',
                            child: Text(
                              'Customer Terms of Service',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'PrivacyPolicy',
                            child: Text(
                              'Global Privacy Policy',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'DriverAgreement',
                            child: Text(
                              'Fleet Operator Service Agreement',
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null && v != _selectedDoc) {
                            setState(() => _selectedDoc = v);
                            _loadDocument();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 24),
                    FilledButton.icon(
                      onPressed: _isLoading || _isSaving ? null : _saveDocument,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.publish),
                      label: Text(
                        _isSaving ? 'Publishing...' : 'Save & Publish',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 32,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TextField(
                          controller: _textCtrl,
                          maxLines: null,
                          expands: true,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontFamily:
                                'monospace', // Monospace helps with drafting legal markdown/html formatting
                            height: 1.5,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Enter legal document text or markdown here...',
                            hintStyle: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(32),
                            filled: true,
                            fillColor: theme.cardColor,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal & Compliance Hub',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Manage public-facing platform agreements, privacy policies, and driver contracts.',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
