import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/gestacao_storage.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _carregando = false;
  String? _erro;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _cadastrar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;
    final confirmar = _confirmarSenhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Preencha todos os campos.');
      return;
    }

    if (senha.length < 6) {
      setState(() => _erro = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    if (senha != confirmar) {
      setState(() => _erro = 'As senhas não coincidem.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final erro = await AuthService.cadastrar(email: email, senha: senha);

    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _carregando = false;
        _erro = erro;
      });
      return;
    }

    // Cadastro deu certo — navega direto, sem depender só do StreamBuilder
    final jaConfigurou = await GestacaoStorage.restaurarDUM();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => jaConfigurou ? const HomeScreen() : const OnboardingScreen(),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 360,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderStrong(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded, color: AppTheme.primaryPurple, size: 18),
                          Text('Voltar', style: TextStyle(color: AppTheme.primaryPurple, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Criar conta',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Comece a acompanhar sua gestação',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                  ),
                  const SizedBox(height: 28),

                  if (_erro != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _erro!,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                      ),
                    ),

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      filled: true,
                      fillColor: AppColors.statPurple(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _senhaController,
                    obscureText: !_senhaVisivel,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Senha (mín. 6 caracteres)',
                      filled: true,
                      fillColor: AppColors.statPurple(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _senhaVisivel ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: AppColors.textMuted(context),
                          size: 20,
                        ),
                        onPressed: () => setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmarSenhaController,
                    obscureText: !_senhaVisivel,
                    style: TextStyle(color: AppColors.textPrimary(context)),
                    decoration: InputDecoration(
                      labelText: 'Confirmar senha',
                      filled: true,
                      fillColor: AppColors.statPurple(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _cadastrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryPurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _carregando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Criar conta', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}