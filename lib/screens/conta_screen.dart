import 'package:flutter/material.dart';

import '../data/sessao.dart';
import '../services/auth_service.dart';
import '../services/firestore_error.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

class ContaScreen extends StatefulWidget {
  const ContaScreen({super.key});

  @override
  State<ContaScreen> createState() => _ContaScreenState();
}

class _ContaScreenState extends State<ContaScreen> {
  bool _saindo = false;
  String? _erro;
  String? _email;

  @override
  void initState() {
    super.initState();

    try {
      _email = AuthService.usuarioAtual?.email;
    } catch (_) {
      _email = null;
    }
  }

  Future<bool> _confirmarSaida(BuildContext context) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sair da conta?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(ctx),
            ),
          ),
          content: Text(
            'Seus registros continuam salvos e voltam quando você entrar '
            'de novo neste ou em outro aparelho.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary(ctx),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textPrimary(ctx)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Sair',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.pink,
                ),
              ),
            ),
          ],
        );
      },
    );

    return resposta == true;
  }

  Future<void> _sairDaConta() async {
    if (_saindo) return;

    final confirmado = await _confirmarSaida(context);
    if (!confirmado || !mounted) return;

    setState(() {
      _saindo = true;
      _erro = null;
    });

    limparEstadoDaSessao();

    try {
      await AuthService.logout();
    } catch (erro) {

      if (!mounted) return;
      setState(() {
        _saindo = false;
        _erro = FirestoreErro.mensagemAmigavel(erro);
      });
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _cabecalho(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        border: Border(
          bottom: BorderSide(color: AppColors.border(context), width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.purpleLabel(context),
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  'Voltar',
                  style: TextStyle(
                    color: AppColors.purpleLabel(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Conta',
            style: TextStyle(
              color: AppColors.textPrimary(context),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Sessão neste aparelho',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartaoDoEmail(BuildContext context) {
    final email = _email;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'E-MAIL',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textMuted(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email == null || email.isEmpty ? 'Não disponível' : email,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botaoSair(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saindo ? null : _sairDaConta,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryPurple,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _saindo
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Sair da conta',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: AppColors.borderStrong(context),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _cabecalho(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _cartaoDoEmail(context),
                    const SizedBox(height: 20),
                    if (_erro != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.statPink(context),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _erro!,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                    ],
                    _botaoSair(context),
                    const SizedBox(height: 8),
                    Text(
                      'Sair não apaga nada: seus dados ficam guardados na '
                      'sua conta.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppColors.textMuted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
