import 'package:flutter/material.dart';

import '../main.dart';
import '../services/firestore_error.dart';
import '../services/proximo_destino.dart';
import '../theme/app_theme.dart';
import 'consentimento_screen.dart';
import 'onboarding_screen.dart';

class PortaDeEntrada extends StatefulWidget {
  const PortaDeEntrada({super.key, this.calcular = ProximoDestino.calcular});

  final Future<Destino> Function() calcular;

  @override
  State<PortaDeEntrada> createState() => _PortaDeEntradaState();
}

class _PortaDeEntradaState extends State<PortaDeEntrada> {
  Destino? _destino;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _calcular();
  }

  Future<void> _calcular() async {
    try {
      final destino = await widget.calcular();
      if (!mounted) return;
      setState(() => _destino = destino);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro);
    }
  }

  void _recalcular() {
    setState(() {
      _destino = null;
      _erro = null;
    });
    _calcular();
  }

  @override
  Widget build(BuildContext context) {
    final erro = _erro;
    if (erro != null) {
      return _ErroAoCarregar(
        mensagem: FirestoreErro.mensagemAmigavel(erro),
        aoTentarNovamente: _recalcular,
      );
    }

    switch (_destino) {
      case null:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case Destino.consentimento:
        return ConsentimentoScreen(aoAceitar: _recalcular);
      case Destino.home:
        return const HomeScreen();
      case Destino.onboarding:
        return const OnboardingScreen();
    }
  }
}

class _ErroAoCarregar extends StatelessWidget {
  final String mensagem;
  final VoidCallback aoTentarNovamente;

  const _ErroAoCarregar({
    required this.mensagem,
    required this.aoTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.textMuted(context)),
              const SizedBox(height: 16),
              Text(
                'Não foi possível carregar seus dados',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 6),
              Text(
                mensagem,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: aoTentarNovamente,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Tentar novamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
