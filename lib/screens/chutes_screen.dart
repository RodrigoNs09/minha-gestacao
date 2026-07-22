import 'package:flutter/material.dart';
import '../data/chutes_data.dart';
import '../models/chute_sessao.dart';
import '../services/chutes_storage.dart';
import '../theme/app_theme.dart';

const int _metaChutes = 10;

class ChutesScreen extends StatefulWidget {
  const ChutesScreen({super.key});

  @override
  State<ChutesScreen> createState() => _ChutesScreenState();
}

class _ChutesScreenState extends State<ChutesScreen> with SingleTickerProviderStateMixin {
  int _chutesAtuais = 0;
  DateTime? _inicioSessao;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _carregar();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final dados = await ChutesStorage.carregarSessoes();
    setState(() => listaChutes = dados);

    final progresso = await ChutesStorage.carregarProgressoAtual();
    if (progresso != null && progresso['data'] == _hoje()) {
      setState(() {
        _chutesAtuais = progresso['chutes'];
        _inicioSessao = DateTime.tryParse(progresso['horaInicio']);
      });
    } else if (progresso != null) {
      // Progresso de outro dia — descarta
      await ChutesStorage.limparProgressoAtual();
    }
  }

  String _hoje() {
    final agora = DateTime.now();
    return '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';
  }

  String _formatarHora(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<ChuteSessao> get _sessoesHoje {
    final hoje = _hoje();
    return listaChutes.where((s) => s.data == hoje).toList().reversed.toList();
  }

  Future<void> _registrarChute() async {
    if (_chutesAtuais >= _metaChutes) return;

    _inicioSessao ??= DateTime.now();

    setState(() => _chutesAtuais++);

    // Salva o progresso a cada chute, para não perder se sair da tela
    await ChutesStorage.salvarProgressoAtual(
      chutes: _chutesAtuais,
      data: _hoje(),
      horaInicio: _inicioSessao!.toIso8601String(),
    );

    if (_chutesAtuais >= _metaChutes) {
      final fim = DateTime.now();
      final novaSessao = ChuteSessao(
        data: _hoje(),
        horaInicio: _formatarHora(_inicioSessao!),
        horaFim: _formatarHora(fim),
        totalChutes: _metaChutes,
        completa: true,
      );

      listaChutes.add(novaSessao);
      await ChutesStorage.salvarSessoes(listaChutes);
      await ChutesStorage.limparProgressoAtual();

      // Pequeno delay pra usuária ver a meta atingida antes de resetar
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      setState(() {
        _chutesAtuais = 0;
        _inicioSessao = null;
      });
    }
  }

  Widget _dot(int index) {
    final ativo = index < _chutesAtuais;
    return Container(
      width: 22,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: ativo ? AppTheme.primaryPurple : AppColors.statPurple(context),
        shape: BoxShape.circle,
      ),
      child: ativo
          ? const Icon(Icons.check, size: 12, color: Colors.white)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final metaAtingida = _chutesAtuais >= _metaChutes;

    return Scaffold(
      backgroundColor: AppColors.scaffold(context),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: AppColors.borderStrong(context), width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  border: Border(bottom: BorderSide(color: AppColors.border(context), width: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left_rounded, color: AppColors.purpleLabel(context), size: 18),
                          const SizedBox(width: 4),
                          Text('Voltar', style: TextStyle(color: AppColors.purpleLabel(context), fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Contador de Chutes',
                        style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text('Meta: $_metaChutes movimentos em até 2h',
                        style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 90),
                  children: [
                    Center(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseController.value * 0.04);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surface(context),
                            border: Border.all(
                              color: metaAtingida ? const Color(0xFF1D9E75) : AppTheme.primaryPurple,
                              width: 4,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$_chutesAtuais',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w500,
                                  color: metaAtingida ? const Color(0xFF1D9E75) : AppTheme.primaryPurple,
                                ),
                              ),
                              Text('chutes', style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: List.generate(_metaChutes, _dot),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: metaAtingida ? null : _registrarChute,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: metaAtingida ? const Color(0xFF1D9E75) : AppTheme.primaryPurple,
                            boxShadow: [
                              BoxShadow(
                                color: (metaAtingida ? const Color(0xFF1D9E75) : AppTheme.primaryPurple).withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                metaAtingida ? Icons.check_circle_rounded : Icons.directions_walk_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                metaAtingida ? 'Meta atingida!' : 'Registrar',
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border(context), width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sessões de hoje',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
                          const SizedBox(height: 10),
                          if (_sessoesHoje.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Nenhuma sessão registrada ainda hoje.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                              ),
                            )
                          else
                            ..._sessoesHoje.map((s) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.horaInicio,
                                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary(context))),
                                          Text('Concluída', style: TextStyle(fontSize: 10, color: AppColors.textMuted(context))),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.statGreen(context),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text('${s.totalChutes} chutes ✓',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF085041))),
                                      ),
                                    ],
                                  ),
                                )),
                        ],
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