import 'package:flutter/material.dart';
import '../data/gestacao_data.dart';
import '../services/gestacao_storage.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _ModoInformar { semanas, dpp }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _ModoInformar? _modo;
  int _semanasInformadas = 20;
  DateTime? _dppEscolhida;

  Future<void> _escolherDPP() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 140)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 300)),
      helpText: 'Data provável do parto',
      cancelText: 'Cancelar',
      confirmText: 'OK',
    );
    if (data != null) {
      setState(() => _dppEscolhida = data);
    }
  }

  bool get _podeContinuar {
    if (_modo == _ModoInformar.semanas) return true;
    if (_modo == _ModoInformar.dpp) return _dppEscolhida != null;
    return false;
  }

  Future<void> _continuar() async {
    DateTime dum;

    if (_modo == _ModoInformar.semanas) {
      // DUM = hoje - (semanas * 7 dias)
      dum = DateTime.now().subtract(Duration(days: _semanasInformadas * 7));
    } else {
      // DPP = DUM + 280 dias, então DUM = DPP - 280 dias
      dum = _dppEscolhida!.subtract(const Duration(days: 280));
    }

    atualizarDUM(dum);
    await GestacaoStorage.salvarDUM(dum);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _pular() async {
    // Usa o padrão (semana 28) já definido em gestacao_data.dart
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Widget _opcaoModo({
    required _ModoInformar modo,
    required IconData icon,
    required String titulo,
    required String subtitulo,
  }) {
    final selecionado = _modo == modo;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _modo = modo),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selecionado ? AppColors.statPurple(context) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selecionado ? AppTheme.primaryPurple : AppColors.border(context),
            width: selecionado ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selecionado ? AppTheme.primaryPurple : AppColors.statPurple(context),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: selecionado ? Colors.white : AppTheme.primaryPurple, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitulo, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoDetalhe() {
    if (_modo == _ModoInformar.semanas) {
      return Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.statPurple(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text('Você está de quantas semanas?',
                style: TextStyle(fontSize: 12, color: AppColors.accentText(context), fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => setState(() => _semanasInformadas = (_semanasInformadas - 1).clamp(1, 42)),
                  icon: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.primaryPurple),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    '$_semanasInformadas',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: AppColors.accentText(context)),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _semanasInformadas = (_semanasInformadas + 1).clamp(1, 42)),
                  icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPurple),
                ),
              ],
            ),
            Text('semanas', style: TextStyle(fontSize: 11, color: AppColors.accent(context))),
          ],
        ),
      );
    } else if (_modo == _ModoInformar.dpp) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _escolherDPP,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.statPurple(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _dppEscolhida != null ? AppTheme.primaryPurple : AppTheme.primaryPurple.withOpacity(0.2),
                width: _dppEscolhida != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryPurple),
                const SizedBox(width: 10),
                Text(
                  _dppEscolhida == null
                      ? 'Selecionar data prevista do parto'
                      : '${_dppEscolhida!.day.toString().padLeft(2, '0')}/'
                        '${_dppEscolhida!.month.toString().padLeft(2, '0')}/'
                        '${_dppEscolhida!.year}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 360,
          constraints: const BoxConstraints(minHeight: 760),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderStrong(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 20),
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
                  'Bem-vinda ao\nMinha Gestação',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context), height: 1.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Como você prefere nos contar em que fase da gestação está?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context), height: 1.5),
                ),
                const SizedBox(height: 28),

                _opcaoModo(
                  modo: _ModoInformar.semanas,
                  icon: Icons.calendar_view_week_rounded,
                  titulo: 'Sei quantas semanas estou',
                  subtitulo: 'Informar diretamente a semana atual',
                ),
                _opcaoModo(
                  modo: _ModoInformar.dpp,
                  icon: Icons.child_friendly_rounded,
                  titulo: 'Sei a data prevista do parto',
                  subtitulo: 'A data que o médico(a) informou',
                ),

                if (_modo != null) ...[
                  const SizedBox(height: 6),
                  _campoDetalhe(),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _podeContinuar ? _continuar : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      disabledBackgroundColor: AppColors.textMuted(context),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Continuar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _pular,
                  child: Text('Não sei, configurar depois', style: TextStyle(fontSize: 12, color: AppColors.textMuted(context))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}