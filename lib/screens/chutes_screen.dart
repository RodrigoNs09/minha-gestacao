import 'package:flutter/material.dart';
import '../data/chutes_data.dart';
import '../models/chute_sessao.dart';
import '../services/chutes_storage.dart';
import '../services/firestore_error.dart';
import '../theme/app_theme.dart';

const int _metaChutes = 10;

List<ChuteSessao> comSessao(List<ChuteSessao> historico, ChuteSessao sessao) {
  return [...historico.where((s) => s.id == null || s.id != sessao.id), sessao];
}

bool sessaoJaNoHistorico(
  List<ChuteSessao> historico, {
  required String data,
  required String horaInicio,
}) {
  return historico.any((s) => s.data == data && s.horaInicio == horaInicio);
}

enum RetomadaDeProgresso {

  nenhuma,

  restaurar,

  concluir,

  jaRegistrada,

  deOutroDia,

  irrecuperavel,
}

RetomadaDeProgresso retomadaPara(
  ProgressoDeChutes? progresso, {
  required String hoje,
  required int meta,
  required List<ChuteSessao> historico,
  required String Function(DateTime) formatarHora,
}) {
  if (progresso == null) return RetomadaDeProgresso.nenhuma;
  if (progresso.data != hoje) return RetomadaDeProgresso.deOutroDia;
  if (progresso.chutes < meta) return RetomadaDeProgresso.restaurar;

  final inicio = progresso.inicio;
  if (inicio == null) return RetomadaDeProgresso.irrecuperavel;

  if (progresso.sessaoId == null &&
      sessaoJaNoHistorico(
        historico,
        data: progresso.data,
        horaInicio: formatarHora(inicio),
      )) {
    return RetomadaDeProgresso.jaRegistrada;
  }

  return RetomadaDeProgresso.concluir;
}

const String mensagemSemSessao =
    'Não foi possível salvar: sessão expirada. Entre novamente.';

const String mensagemProgressoIrrecuperavel =
    'A contagem anterior não pôde ser recuperada e foi descartada.';

class ChutesScreen extends StatefulWidget {
  const ChutesScreen({super.key});

  @override
  State<ChutesScreen> createState() => _ChutesScreenState();
}

class _ChutesScreenState extends State<ChutesScreen>
    with SingleTickerProviderStateMixin {
  int _chutesAtuais = 0;
  DateTime? _inicioSessao;
  bool _salvando = false;
  String? _idSessaoPendente;

  /// A meta foi atingida mas a sessão ainda não está no servidor. Enquanto
  /// isso for verdade o botão oferece nova tentativa em vez de ficar morto.
  bool _conclusaoPendente = false;

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

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _carregar() async {
    ProgressoDeChutes? progresso;

    try {
      final dados = await ChutesStorage.carregarSessoes();
      if (!mounted) return;
      setState(() => listaChutes = dados);

      progresso = await ChutesStorage.carregarProgressoAtual();
      if (!mounted) return;
    } catch (erro) {
      _avisar(FirestoreErro.mensagemAmigavel(erro));
      return;
    }

    final acao = retomadaPara(
      progresso,
      hoje: _hoje(),
      meta: _metaChutes,
      historico: listaChutes,
      formatarHora: _formatarHora,
    );

    switch (acao) {
      case RetomadaDeProgresso.nenhuma:
        return;

      case RetomadaDeProgresso.deOutroDia:
        await _descartarProgresso(avisar: false);
        return;

      case RetomadaDeProgresso.irrecuperavel:
        await _descartarProgresso(avisar: true);
        return;

      case RetomadaDeProgresso.restaurar:
        _restaurarContagem(progresso!);
        return;

      case RetomadaDeProgresso.jaRegistrada:

        _restaurarContagem(progresso!);
        await _limparProgressoEReiniciar();
        return;

      case RetomadaDeProgresso.concluir:

        _restaurarContagem(progresso!);
        setState(() => _conclusaoPendente = true);
        await _concluirSessaoPendente();
        return;
    }
  }

  void _restaurarContagem(ProgressoDeChutes progresso) {
    setState(() {
      _chutesAtuais = progresso.chutes;
      _inicioSessao = progresso.inicio;
      _idSessaoPendente = progresso.sessaoId;
    });
  }

  Future<void> _descartarProgresso({required bool avisar}) async {
    try {
      await ChutesStorage.limparProgressoAtual();
    } catch (_) {

    }

    if (!mounted) return;
    setState(() {
      _chutesAtuais = 0;
      _inicioSessao = null;
      _idSessaoPendente = null;
      _conclusaoPendente = false;
    });

    if (avisar) _avisar(mensagemProgressoIrrecuperavel);
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

  Future<void> _limparProgressoEReiniciar() async {

    bool limpou = false;
    Object? erro;
    try {
      limpou = await ChutesStorage.limparProgressoAtual();
    } catch (e) {
      erro = e;
    }

    if (!mounted) return;

    setState(() {
      _chutesAtuais = 0;
      _inicioSessao = null;
      _idSessaoPendente = null;
      _conclusaoPendente = false;
      _salvando = false;
    });

    if (!limpou) {
      _avisar(
        erro != null ? FirestoreErro.mensagemAmigavel(erro) : mensagemSemSessao,
      );
    }
  }

  Future<void> _concluirSessaoPendente() async {
    final inicio = _inicioSessao;
    if (inicio == null || _salvando) return;

    setState(() => _salvando = true);

    ChuteSessao? gravada;
    Object? erro;
    try {

      _idSessaoPendente ??= ChutesStorage.novoId();
      final id = _idSessaoPendente;

      if (id != null) {
        gravada = await ChutesStorage.adicionar(
          ChuteSessao(
            id: id,
            data: _hoje(),
            horaInicio: _formatarHora(inicio),
            horaFim: _formatarHora(DateTime.now()),
            totalChutes: _metaChutes,
            completa: true,
          ),
        );
      }
    } catch (e) {
      erro = e;
    }

    if (!mounted) return;

    if (gravada == null) {

      setState(() => _salvando = false);
      _avisar(
        erro != null ? FirestoreErro.mensagemAmigavel(erro) : mensagemSemSessao,
      );
      return;
    }

    setState(() => listaChutes = comSessao(listaChutes, gravada!));

    // Pequeno delay pra usuária ver a meta atingida antes de resetar
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    await _limparProgressoEReiniciar();
  }

  Future<void> _registrarChute() async {
    if (_chutesAtuais >= _metaChutes || _salvando) return;

    _inicioSessao ??= DateTime.now();

    final chutesAntes = _chutesAtuais;
    setState(() {
      _chutesAtuais++;
      _salvando = true;
    });

    bool gravou = false;
    Object? erro;
    try {

      _idSessaoPendente ??= ChutesStorage.novoId();

      // Salva o progresso a cada chute, para não perder se sair da tela
      gravou = await ChutesStorage.salvarProgressoAtual(
        ProgressoDeChutes(
          chutes: _chutesAtuais,
          data: _hoje(),
          inicio: _inicioSessao,
          sessaoId: _idSessaoPendente,
        ),
      );
    } catch (e) {
      erro = e;
    }

    if (!mounted) return;

    if (!gravou) {
      setState(() {
        _chutesAtuais = chutesAntes;
        _salvando = false;
      });
      _avisar(
        erro != null ? FirestoreErro.mensagemAmigavel(erro) : mensagemSemSessao,
      );
      return;
    }

    if (_chutesAtuais < _metaChutes) {
      setState(() => _salvando = false);
      return;
    }

    setState(() {
      _conclusaoPendente = true;
      _salvando = false;
    });
    await _concluirSessaoPendente();
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
    // Enquanto a sessão não está no servidor o botão não pode se anunciar
    // como concluído: fica roxo, oferecendo nova tentativa.
    final corDoBotao = (metaAtingida && !_conclusaoPendente)
        ? const Color(0xFF1D9E75)
        : AppTheme.primaryPurple;

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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant(context),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.border(context),
                      width: 0.5,
                    ),
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
                      'Contador de Chutes',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Meta: $_metaChutes movimentos em até 2h',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
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
                              color: metaAtingida
                                  ? const Color(0xFF1D9E75)
                                  : AppTheme.primaryPurple,
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
                                  color: metaAtingida
                                      ? const Color(0xFF1D9E75)
                                      : AppTheme.primaryPurple,
                                ),
                              ),
                              Text(
                                'chutes',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
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
                        onTap: _salvando
                            ? null
                            : _conclusaoPendente
                            ? _concluirSessaoPendente
                            : (metaAtingida ? null : _registrarChute),
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: corDoBotao,
                            boxShadow: [
                              BoxShadow(
                                color: corDoBotao.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _conclusaoPendente
                                    ? Icons.refresh_rounded
                                    : metaAtingida
                                    ? Icons.check_circle_rounded
                                    : Icons.directions_walk_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _conclusaoPendente
                                    ? 'Tentar novamente'
                                    : metaAtingida
                                    ? 'Meta atingida!'
                                    : 'Registrar',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
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
                        border: Border.all(
                          color: AppColors.border(context),
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sessões de hoje',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_sessoesHoje.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Nenhuma sessão registrada ainda hoje.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            )
                          else
                            ..._sessoesHoje.map(
                              (s) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.horaInicio,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textPrimary(
                                              context,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Concluída',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted(context),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.statGreen(context),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${s.totalChutes} chutes ✓',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF085041),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
