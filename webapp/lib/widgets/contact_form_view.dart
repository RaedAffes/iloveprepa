import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'contact_illustration.dart';

/// Floating contact form shown in the main area when the Contact icon is
/// tapped. Mirrors the "Talk to Us" CodePen design: a floating SVG envelope on
/// the left (animated), pill-shaped inputs with feather icons, a Pacifico
/// title, Quicksand body, and a gradient orange "Send message" button.
class ContactFormView extends StatefulWidget {
  const ContactFormView({super.key, required this.onBack, this.api});

  /// Returns to the library (overview / folder content).
  final VoidCallback onBack;

  /// Test seam — defaults to the real [ApiService].
  final ApiService? api;

  @override
  State<ContactFormView> createState() => _ContactFormViewState();
}

enum _Status { idle, sending, success, error }

class _ContactFormViewState extends State<ContactFormView> {
  late final ApiService _api = widget.api ?? ApiService();

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();

  _Status _status = _Status.idle;
  bool _messageRtl = false;
  String _error = '';

  static final RegExp _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _arabicRe = RegExp(r'[\u0600-\u06FF]');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _status = _Status.sending);
    try {
      final emailOk = await _api.validateEmail(_email.text.trim());
      if (!emailOk) {
        if (!mounted) return;
        setState(() {
          _status = _Status.error;
          _error =
              'Cette adresse e-mail semble invalide (domaine inexistant). '
              'Veuillez en saisir une autre.';
        });
        return;
      }
      await _api.sendContact(
        name: _name.text.trim(),
        email: _email.text.trim(),
        message: _message.text.trim(),
      );
      if (!mounted) return;
      setState(() => _status = _Status.success);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _Status.error;
        _error = e is ApiException
            ? e.message
            : "Une erreur est survenue. Veuillez réessayer.";
      });
    }
  }

  OutlineInputBorder _round() => OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: Color(0xFFDCE3E9), width: 1.2),
      );

  void _reset() {
    _name.clear();
    _email.clear();
    _message.clear();
    _formKey.currentState?.reset();
    setState(() => _status = _Status.idle);
  }

  InputDecoration _field(IconData icon, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Quicksand',
        fontWeight: FontWeight.w600,
        fontSize: 16,
        color: Color(0xFF838788),
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 10),
        child: Icon(
          icon,
          color: const Color(0xFF57565C),
          size: 20,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFFF2F6F8),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      enabledBorder: _round(),
      focusedBorder: _round(),
      errorBorder: _round(),
      focusedErrorBorder: _round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF6F9FC),
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;

          Widget content;
          if (_status == _Status.success) {
            content = _buildSuccessCard(wide);
          } else {
            content = _buildFormCard(wide);
          }

          return Align(
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: content,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormCard(bool wide) {
    final form = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTitle(),
            const SizedBox(height: 8),
            _buildField(
              icon: Icons.person_outline_rounded,
              hint: 'Name',
            ),
            const SizedBox(height: 16),
            _buildField(
              icon: Icons.mail_outline_rounded,
              hint: 'E-mail',
            ),
            const SizedBox(height: 16),
            _buildMessageField(),
            const SizedBox(height: 22),
            _buildSubmitButton(),
            if (_status == _Status.error) ...[
              const SizedBox(height: 14),
              _buildError(),
            ],
          ],
        ),
      ),
    );

    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const ContactIllustration(height: 368),
          const SizedBox(width: 12),
          form,
        ],
      );
    }

    // Phone / narrow screens: the illustration is faded behind the form
    // instead of sitting next to it. Wide screens keep the side-by-side layout.
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.28,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                child: const ContactIllustration(height: 320),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 170),
          child: form,
        ),
      ],
    );
  }

  Widget _buildSuccessCard(bool wide) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/check.png',
            height: 280,
          ),
          const SizedBox(height: 26),
          Text(
            'Message envoyé !',
            textAlign: TextAlign.center,
            style: _titleStyle,
          ),
          const SizedBox(height: 10),
          Text(
            'Merci pour votre message. Nous vous répondrons à votre '
            'adresse e-mail dans les plus brefs délais.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Quicksand',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              height: 1.5,
              color: Color(0xFF838788),
            ),
          ),
          const SizedBox(height: 28),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _reset,
              borderRadius: BorderRadius.circular(48),
              child: Ink(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF923C),
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Center(
                  child: Text(
                    "Envoyer un autre message",
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Text(
      'Talk to us',
      textAlign: TextAlign.center,
      style: _titleStyle,
    );
  }

  TextStyle get _titleStyle => const TextStyle(
        fontFamily: 'Pacifico',
        height: 1.1,
        color: Color(0xFF212529),
        fontSize: 36,
      );

  Widget _buildField({required IconData icon, required String hint}) {
    final isEmail = hint == 'E-mail';
    return TextFormField(
      controller: isEmail ? _email : _name,
      keyboardType: isEmail ? TextInputType.emailAddress : null,
      textInputAction: TextInputAction.next,
      style: _inputStyle,
      decoration: _field(icon, hint),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) {
          return isEmail
              ? 'Veuillez saisir votre adresse e-mail.'
              : 'Veuillez saisir votre nom.';
        }
        if (isEmail && !_emailRe.hasMatch(value)) {
          return 'Veuillez saisir une adresse e-mail valide.';
        }
        return null;
      },
    );
  }

  Widget _buildMessageField() {
    return SizedBox(
      height: 150,
      child: Stack(
        children: [
          Positioned.fill(
            child: Directionality(
              textDirection: _messageRtl
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: TextFormField(
                controller: _message,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                textAlign: _messageRtl ? TextAlign.right : TextAlign.start,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF212529),
                  fontSize: 16,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Votre message…',
                  hintStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Color(0xFF838788),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF2F6F8),
                  contentPadding: const EdgeInsets.fromLTRB(52, 16, 20, 16),
                  enabledBorder: _round(),
                  focusedBorder: _round(),
                  errorBorder: _round(),
                  focusedErrorBorder: _round(),
                ),
                onChanged: (v) {
                  final rtl = _arabicRe.hasMatch(v);
                  if (rtl != _messageRtl) {
                    setState(() => _messageRtl = rtl);
                  }
                },
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Veuillez écrire votre message.'
                    : null,
              ),
            ),
          ),
          Positioned(
            left: _messageRtl ? null : 20,
            right: _messageRtl ? 20 : null,
            top: 20,
            child: Icon(
              Icons.edit_outlined,
              size: 20,
              color: const Color(0xFF57565C),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle get _inputStyle => const TextStyle(
        fontFamily: 'Quicksand',
        color: Color(0xFF212529),
        fontSize: 16,
        height: 1.3,
      );

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0533D), width: 1),
      ),
      child: Text(
        _error,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Quicksand',
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Color(0xFFB23B28),
        ),
      ),
    );
  }

  Widget _buildSubmitButton({String label = 'Send message', VoidCallback? onTap}) {
    final sending = _status == _Status.sending;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: sending ? null : (onTap ?? _submit),
        borderRadius: BorderRadius.circular(48),
        child: Ink(
          height: 62,
          decoration: BoxDecoration(
            color: const Color(0xFFFF923C),
            borderRadius: BorderRadius.circular(48),
          ),
          child: Center(
            child: sending
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Quicksand',
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}