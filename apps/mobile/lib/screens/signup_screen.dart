import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _agreedToPrivacy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authNotifierProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    });
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    _buildCard(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 56),
          decoration: BoxDecoration(
            color: const Color(0xFF695959),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
          child: _buildForm(),
        ),
        Positioned(
          top: 0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.scaffoldBg,
              border: Border.all(color: const Color(0xFF695959), width: 3),
            ),
            child: ClipOval(
              child: ExcludeSemantics(
                child: Image.asset('assets/images/Logo.png', fit: BoxFit.cover),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome to\nCozyTalk!',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'SIGN UP',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: AppColors.yellowWarm,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          _label('Email'),
          const SizedBox(height: 6),
          _textField(
            controller: _emailController,
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),
          _label('Password'),
          const SizedBox(height: 6),
          _passwordField(),
          const SizedBox(height: 20),
          _checkboxRow(
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            label: 'I agree to the ',
            linkText: 'Terms of Service',
            onLinkTap: () => _showPolicy(context, _termsOfServiceContent),
          ),
          const SizedBox(height: 10),
          _checkboxRow(
            value: _agreedToPrivacy,
            onChanged: (v) => setState(() => _agreedToPrivacy = v ?? false),
            label: 'I agree to the ',
            linkText: 'Privacy Policy',
            onLinkTap: () => _showPolicy(context, _privacyPolicyContent),
          ),
          const SizedBox(height: 24),
          _signUpButton(),
          const SizedBox(height: 18),
          _orDivider(),
          const SizedBox(height: 18),
          _googleButton(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: const Color(0xCCFFFFFF),
                  fontSize: 13,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Text(
                  'Login',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.yellowWarm,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () =>
                ref.read(authNotifierProvider.notifier).signInAnonymously(),
            child: Text(
              'Login as a guest',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Colors.white,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    validator: validator,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: Colors.black87, fontSize: 14),
    decoration: _inputDecoration(hint),
  );

  Widget _passwordField() => TextFormField(
    controller: _passwordController,
    obscureText: _obscurePassword,
    validator: _validatePassword,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: Colors.black87, fontSize: 14),
    decoration: _inputDecoration('Enter your password').copyWith(
      suffixIcon: IconButton(
        tooltip: 'Toggle password visibility',
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFFAAAAAA),
          size: 20,
        ),
        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
      ),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: const Color(0xFF767676),
      fontSize: 14,
    ),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm, width: 1.5),
    ),
    errorStyle: Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.yellowWarm, fontSize: 12),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.yellowWarm),
    ),
  );

  Widget _checkboxRow({
    required bool value,
    required ValueChanged<bool?>? onChanged,
    required String label,
    required String linkText,
    required VoidCallback onLinkTap,
  }) => Row(
    children: [
      SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.yellowWarm,
          checkColor: const Color(0xFF4A3228),
          side: const BorderSide(color: Colors.white70),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: const Color(0xCCFFFFFF),
            fontSize: 12,
          ),
        ),
      ),
      GestureDetector(
        onTap: onLinkTap,
        child: Text(
          linkText,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: AppColors.yellowWarm,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.yellowWarm,
          ),
        ),
      ),
    ],
  );

  Widget _orDivider() => Row(
    children: [
      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'or',
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            color: const Color(0xCCFFFFFF),
            fontSize: 13,
          ),
        ),
      ),
      const Expanded(child: Divider(color: Colors.white38, thickness: 1)),
    ],
  );

  Widget _googleButton() {
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.status == AuthStatus.loading),
    );
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: isLoading ? null : _signUpWithGoogle,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF4A3228),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/images/icons/google_logo.svg',
              width: 22,
              height: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Sign up with Google',
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A3228),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signUpWithGoogle() async {
    await ref.read(authNotifierProvider.notifier).signInWithGoogle();
  }

  Widget _signUpButton() {
    final isLoading = ref.watch(
      authNotifierProvider.select((s) => s.status == AuthStatus.loading),
    );
    final canSubmit = _agreedToTerms && _agreedToPrivacy && !isLoading;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: canSubmit ? _submit : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.saveBtn,
          foregroundColor: const Color(0xFF4A3228),
          disabledBackgroundColor: const Color(0xFF8A7A74),
          disabledForegroundColor: Colors.white54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                'Sign Up',
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authNotifierProvider.notifier)
        .signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }

  void _showPolicy(BuildContext context, _PolicyContent content) {
    showDialog<void>(
      context: context,
      builder: (_) => _PolicyDialog(content: content),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required.';
    final email = value.trim().toLowerCase();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) return 'Enter a valid email address.';
    if (email.endsWith('@cozytalk.com')) {
      return 'This email cannot be used to sign up.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }
}

// ── Policy Dialog ──────────────────────────────────────────────────────────

class _PolicyContent {
  const _PolicyContent({required this.title, required this.sections});
  final String title;
  final List<_PolicySection> sections;
}

class _PolicySection {
  const _PolicySection({required this.heading, required this.body});
  final String heading;
  final String body;
}

class _PolicyDialog extends StatelessWidget {
  const _PolicyDialog({required this.content});
  final _PolicyContent content;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Stack(
          children: [
            // Entire content (header + body) scrolls together
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — leave space for the X button
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'CozyTalk Application',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(fontSize: 12, color: Colors.black54),
                        ),
                        Text(
                          'Last Updated: April 2026',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                  // Sections
                  ...content.sections.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.heading,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            s.body,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(fontSize: 13, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Close button — always visible at top-right
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.cancel_outlined, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Policy Content ─────────────────────────────────────────────────────────

const _termsOfServiceContent = _PolicyContent(
  title: 'Terms of Service',
  sections: [
    _PolicySection(
      heading: '1. Age Requirement',
      body:
          'You must be 18 years old or older to create a CozyTalk account. By signing up, you confirm that you meet this age requirement. Accounts found to belong to users under 18 will be permanently removed without prior notice.',
    ),
    _PolicySection(
      heading: '2. Acceptance of Terms',
      body:
          'By creating a CozyTalk account, you agree to these Terms of Service. If you do not agree, please do not use this service.',
    ),
    _PolicySection(
      heading: '3. Use of Service',
      body:
          'CozyTalk connects you with strangers for casual conversation. You agree to use the platform respectfully and lawfully. Harassment, threats, or harmful behaviour toward others is strictly prohibited.',
    ),
    _PolicySection(
      heading: '4. Chat Retention',
      body:
          'All chat messages are automatically deleted 3 days after they were sent. Any chat that has been reported by a user will be retained indefinitely for moderation and legal review purposes. By using CozyTalk, you consent to this policy.',
    ),
    _PolicySection(
      heading: '5. Do Not Share Private Information',
      body:
          'You must not share sensitive personal information with strangers on CozyTalk, including but not limited to:\n'
          '- Passwords, PINs, or OTP codes\n'
          '- National ID card or passport number\n'
          '- Bank account or credit card details\n'
          '- Home address or workplace location\n'
          '- Personal phone number or email address\n\n'
          'CozyTalk is not responsible for any harm resulting from your disclosure of personal information to other users.',
    ),
    _PolicySection(
      heading: '6. Prohibited Content',
      body:
          'You may not share, send, or request: illegal content, explicit or adult material, hate speech, spam or phishing links, or any content that violates the rights of others.',
    ),
    _PolicySection(
      heading: '7. Account Responsibility',
      body:
          'You are responsible for all activity under your account. Do not share your login credentials with anyone. CozyTalk is not liable for unauthorised access resulting from your negligence.',
    ),
    _PolicySection(
      heading: '8. Termination',
      body:
          'We reserve the right to suspend or permanently ban accounts that violate these Terms at any time, without prior notice, at our sole discretion.',
    ),
    _PolicySection(
      heading: '9. Changes to These Terms',
      body:
          'We may update these Terms from time to time. Continued use of CozyTalk after changes are posted constitutes your acceptance of the updated Terms.',
    ),
    _PolicySection(
      heading: '10. Contact',
      body: 'For questions about these Terms, contact us @CozyTalk on Discord.',
    ),
  ],
);

const _privacyPolicyContent = _PolicyContent(
  title: 'Privacy Policy',
  sections: [
    _PolicySection(
      heading: '1. Data We Collect',
      body:
          'We collect the following information when you use CozyTalk:\n'
          '- Email address (used for account creation and login)\n'
          '- Device information (device type, operating system version)\n'
          '- Usage data (session length, frequency of use)\n\n'
          'We do not store the content of your chat messages beyond what is required for safety and moderation review.',
    ),
    _PolicySection(
      heading: '2. Chat Retention & Deletion',
      body:
          'All chat messages are automatically deleted 3 days after they were sent. If a chat is reported by any user involved, that chat will be retained indefinitely to support our moderation and legal processes. By using CozyTalk, you acknowledge and consent to this policy.',
    ),
    _PolicySection(
      heading: '3. How We Use Your Data',
      body:
          'Your data is used to:\n'
          '- Match you with other users for conversation\n'
          '- Improve app performance and user experience\n'
          '- Detect and prevent abuse or policy violations\n'
          '- Send important service updates and announcements\n\n'
          'We do not sell your personal data to third parties.',
    ),
    _PolicySection(
      heading: '4. Your Private Information',
      body:
          'We strongly advise you never to share any of the following with other users in chat:\n'
          '- Passwords or PINs\n'
          '- National ID card or passport number\n'
          '- Bank account or credit card details\n'
          '- Home address or workplace location\n'
          '- Personal phone number or email address',
    ),
    _PolicySection(
      heading: '5. Data Security',
      body:
          'We use industry-standard encryption to protect your data in transit and at rest. However, no system is completely secure. Please protect your account with a strong, unique password that you do not use on other services.',
    ),
    _PolicySection(
      heading: '6. Cookies & Analytics',
      body:
          'CozyTalk uses analytics tools to understand usage patterns and improve the user experience. You can opt out of analytics tracking in your account settings at any time.',
    ),
    _PolicySection(
      heading: '7. Data Sharing',
      body:
          'We do not sell, trade, or share your personal information with third parties, except:\n'
          '- When required by law or valid legal process\n'
          '- To protect the rights and safety of CozyTalk users\n'
          '- With service providers who assist in operating the app, under strict confidentiality agreements',
    ),
    _PolicySection(
      heading: '8. Your Rights',
      body:
          'You have the right to:\n'
          '- Request access to the personal data we hold about you\n'
          '- Request correction of inaccurate data\n'
          '- Request deletion of your personal data\n\n'
          'To exercise any of these rights, contact us at: privacy@cozytalk.app. We will respond within 30 days.',
    ),
    _PolicySection(
      heading: '9. Changes to This Policy',
      body:
          'We may update this Privacy Policy from time to time. We will notify you of significant changes via in-app notification or email. Continued use of CozyTalk after changes are posted constitutes your acceptance.',
    ),
    _PolicySection(
      heading: '10. Contact',
      body:
          'For questions about this Privacy Policy, contact us @CozyTalk on Discord.',
    ),
  ],
);
