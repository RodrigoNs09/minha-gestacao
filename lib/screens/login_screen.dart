import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/gestacao_storage.dart';
import '../theme/app_theme.dart';
import '../main.dart';
import 'onboarding_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _carregando = false;
  String? _erro;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _fazerLogin() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text;

    if (email.isEmpty || senha.isEmpty) {
      setState(() => _erro = 'Preencha e-mail e senha.');
      return;
    }

    setState(() {
      _carregando = true;
      _erro = null;
    });

    final erro = await AuthService.login(email: email, senha: senha);

    if (!mounted) return;

    if (erro != null) {
      setState(() {
        _carregando = false;
        _erro = erro;
      });
      return;
    }

    // Login deu certo — navega direto, sem depender só do StreamBuilder
    final jaConfigurou = await GestacaoStorage.restaurarDUM();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => jaConfigurou ? const HomeScreen() : const OnboardingScreen(),
      ),
      (route) => false,
    );
  }

  // A mesma frase para conta existente e inexistente. Confirmar aqui que o
  // e-mail está cadastrado transformaria o formulário num verificador de
  // contas de gestantes.
  static const String _avisoNeutroDeRecuperacao =
      'Se houver uma conta com esse e-mail, enviamos um link para redefinir '
      'a senha. Verifique também a caixa de spam.';

  Future<void> _abrirRecuperacao() async {
    final controller = TextEditingController(text: _emailController.text.trim());
    String? erroDoEnvio;
    bool enviando = false;

    final enviou = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> enviar() async {
              final email = controller.text.trim();
              if (email.isEmpty) {
                setDialogState(() => erroDoEnvio = 'Informe seu e-mail.');
                return;
              }

              setDialogState(() {
                enviando = true;
                erroDoEnvio = null;
              });

              final erro = await AuthService.recuperarSenha(email: email);

              if (!ctx.mounted) return;

              if (erro != null) {
                setDialogState(() {
                  enviando = false;
                  erroDoEnvio = erro;
                });
                return;
              }

              Navigator.pop(ctx, true);
            }

            return AlertDialog(
              backgroundColor: AppColors.surface(ctx),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                'Recuperar senha',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(ctx)),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enviaremos um link para você criar uma senha nova.',
                    style: TextStyle(fontSize: 12, height: 1.35, color: AppColors.textSecondary(ctx)),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: AppColors.textPrimary(ctx)),
                    decoration: InputDecoration(
                      labelText: 'E-mail',
                      filled: true,
                      fillColor: AppColors.statPurple(ctx),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  if (erroDoEnvio != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      erroDoEnvio!,
                      style: TextStyle(fontSize: 11, height: 1.35, color: AppColors.textSecondary(ctx)),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancelar', style: TextStyle(color: AppColors.textPrimary(ctx))),
                ),
                TextButton(
                  onPressed: enviando ? null : enviar,
                  child: enviando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Enviar',
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.primaryPurple),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();

    if (enviou != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_avisoNeutroDeRecuperacao)),
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
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF534AB7), Color(0xFF7F77DD)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(child: Text('🤱', style: TextStyle(fontSize: 32))),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Minha Gestação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Entre na sua conta',
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
                      labelText: 'Senha',
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _carregando ? null : _fazerLogin,
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
                          : const Text('Entrar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _carregando ? null : _abrirRecuperacao,
                    child: Text(
                      'Esqueci minha senha',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      );
                    },
                    child: Text(
                      'Não tem conta? Criar agora',
                      style: TextStyle(fontSize: 13, color: AppTheme.primaryPurple),
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