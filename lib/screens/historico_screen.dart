import 'package:flutter/material.dart';
import '../models/contracao.dart';
import '../services/contracoes_storage.dart';
import '../services/firestore_error.dart';
import '../theme/app_theme.dart';

/// Data do registro, ou nulo quando o campo não descreve um dia real.
DateTime? dataDoRegistro(String data) {
  final partes = data.split('-');
  if (partes.length != 3) return null;

  final ano = int.tryParse(partes[0]);
  final mes = int.tryParse(partes[1]);
  final dia = int.tryParse(partes[2]);
  if (ano == null || mes == null || dia == null) return null;

  return DateTime(ano, mes, dia);
}

List<Contracao> comDataUtilizavel(List<Contracao> registros) =>
    registros.where((c) => dataDoRegistro(c.data) != null).toList();

List<Contracao> semDataUtilizavel(List<Contracao> registros) =>
    registros.where((c) => dataDoRegistro(c.data) == null).toList();

String resumoDaContracao(Contracao c) {
  final partes = [
    c.data,
    c.inicio,
    c.intensidade,
    if (c.duracaoFormatada != null) 'Duração: ${c.duracaoFormatada}',
  ].where((parte) => parte.trim().isNotEmpty).toList();

  return partes.isEmpty ? 'Contração sem informações' : partes.join(' · ');
}

const String mensagemSemSessao =
    'Não foi possível excluir: sessão expirada. Entre novamente.';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  String _filtro = 'Hoje';

  List<Contracao> _contracoes = [];
  bool _carregando = true;
  String? _erro;

  static const _meses = [
    'JAN',
    'FEV',
    'MAR',
    'ABR',
    'MAI',
    'JUN',
    'JUL',
    'AGO',
    'SET',
    'OUT',
    'NOV',
    'DEZ',
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    List<Contracao>? dados;
    Object? erro;
    try {
      dados = await ContracoesStorage.carregarContracoes();
    } catch (e) {
      erro = e;
    }

    if (!mounted) return;

    setState(() {
      _carregando = false;
      if (dados != null) {
        _contracoes = dados;
      } else {
        _erro = FirestoreErro.mensagemAmigavel(erro!);
      }
    });
  }

  DateTime? _parseData(String data) => dataDoRegistro(data);

  List<Contracao> get semData => semDataUtilizavel(_contracoes);

  List<Contracao> get contracoesFiltradas {
    final agora = DateTime.now();
    final hojeData = DateTime(agora.year, agora.month, agora.day);

    return comDataUtilizavel(_contracoes).where((c) {
      final dataContracao = _parseData(c.data)!;

      if (_filtro == 'Hoje') {
        return dataContracao == hojeData;
      } else if (_filtro == 'Semana') {
        final seteDiasAtras = hojeData.subtract(const Duration(days: 7));
        return !dataContracao.isBefore(seteDiasAtras) &&
            !dataContracao.isAfter(hojeData);
      } else {
        return dataContracao.month == hojeData.month &&
            dataContracao.year == hojeData.year;
      }
    }).toList();
  }

  List<MapEntry<String, List<Contracao>>> get gruposPorDia {
    final Map<String, List<Contracao>> grupos = {};
    for (final c in contracoesFiltradas) {
      grupos.putIfAbsent(c.data, () => []).add(c);
    }

    for (final lista in grupos.values) {
      lista.sort((a, b) => b.inicio.compareTo(a.inicio));
    }

    final entradas = grupos.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // datas mais recentes primeiro

    return entradas;
  }

  String rotuloDia(String data) {
    final d = _parseData(data);
    if (d == null) return data;
    final hoje = DateTime.now();
    final hojeData = DateTime(hoje.year, hoje.month, hoje.day);

    if (d == hojeData) return 'HOJE — ${d.day} ${_meses[d.month - 1]}';
    if (d == hojeData.subtract(const Duration(days: 1))) {
      return 'ONTEM — ${d.day} ${_meses[d.month - 1]}';
    }
    return '${d.day} ${_meses[d.month - 1]}';
  }

  String get intervaloMedio {
    if (_filtro != 'Hoje') return '—';

    final lista = contracoesFiltradas;
    if (lista.length < 2) return '—';

    final horarios =
        lista
            .map((c) {
              final partes = c.inicio.split(':');
              if (partes.length != 2) return null;
              final hora = int.tryParse(partes[0]);
              final minuto = int.tryParse(partes[1]);
              if (hora == null || minuto == null) return null;
              return hora * 60 + minuto;
            })
            .whereType<int>()
            .toList()
          ..sort();

    if (horarios.length < 2) return '—';

    int soma = 0;
    for (int i = 1; i < horarios.length; i++) {
      soma += (horarios[i] - horarios[i - 1]).abs();
    }

    final media = soma ~/ (horarios.length - 1);
    return _formatarMinutos(media);
  }

  String _formatarMinutos(int totalMinutos) {
    if (totalMinutos < 60) return '${totalMinutos}min';
    final horas = totalMinutos ~/ 60;
    final minutos = totalMinutos % 60;
    if (minutos == 0) return '${horas}h';
    return '${horas}h${minutos}min';
  }

  String get duracaoMedia {
    final lista = contracoesFiltradas;
    if (lista.isEmpty) return '—';

    int somaSegundos = 0;
    int validas = 0;

    for (final c in lista) {
      final duracao = c.duracaoSegundos;
      if (duracao != null) {
        somaSegundos += duracao;
        validas++;
      }
    }

    if (validas == 0) return '—';

    final media = somaSegundos ~/ validas;
    final min = media ~/ 60;
    final seg = media % 60;

    if (min > 0) return '${min}min';
    return '${seg}s';
  }

  Color badgeBg(BuildContext context, String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return AppColors.statPink(context);
      case 'Moderada':
        return AppColors.statOrange(context);
      default:
        return AppColors.statGreen(context);
    }
  }

  Color badgeText(String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return const Color(0xFF72243E);
      case 'Moderada':
        return const Color(0xFF633806);
      default:
        return const Color(0xFF085041);
    }
  }

  Color dotColor(String intensidade) {
    switch (intensidade) {
      case 'Forte':
        return const Color(0xFFD4537E);
      case 'Moderada':
        return const Color(0xFFEF9F27);
      default:
        return const Color(0xFF1D9E75);
    }
  }

  Widget navBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.navBar(context),
        border: Border.all(color: AppColors.border(context), width: 0.5),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(
            Icons.home_rounded,
            color: AppColors.textSecondary(context),
            size: 20,
          ),
          Icon(
            Icons.access_time_rounded,
            color: AppColors.textSecondary(context),
            size: 20,
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_graph_rounded,
                color: AppTheme.primaryPurple,
                size: 20,
              ),
              const SizedBox(height: 3),
              const CircleAvatar(radius: 2, backgroundColor: Color(0xFF534AB7)),
            ],
          ),
          Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppColors.textSecondary(context),
            size: 20,
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarExclusao(Contracao c) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Excluir contração?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(ctx),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Este registro será removido do seu histórico.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resumoDaContracao(c),
                style: TextStyle(fontSize: 11, color: AppColors.textMuted(ctx)),
              ),
            ],
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
                'Excluir',
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

  Future<bool> _confirmarEExcluir(Contracao c) async {
    final id = c.id;
    if (id == null) return false;

    if (!await _confirmarExclusao(c)) return false;
    if (!mounted) return false;

    bool removeu = false;
    Object? erro;
    try {
      removeu = await ContracoesStorage.remover(id);
    } catch (e) {
      erro = e;
    }

    if (!mounted) return false;
    if (removeu) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro != null
              ? FirestoreErro.mensagemAmigavel(erro)
              : mensagemSemSessao,
        ),
      ),
    );
    return false;
  }

  Widget _cardExcluivel(
    BuildContext context,
    Contracao c, {
    required Widget child,
  }) {
    final id = c.id;
    if (id == null) return child;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Color(0xFFEF4444),
        ),
      ),
      confirmDismiss: (_) => _confirmarEExcluir(c),
      onDismissed: (_) =>
          setState(() => _contracoes.removeWhere((x) => x.id == id)),
      child: child,
    );
  }

  Widget _linhaSemData(BuildContext context, Contracao c) {
    return _cardExcluivel(
      context,
      c,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context), width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, size: 16, color: AppTheme.pink),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    'Data inválida: "${c.data}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${c.inicio} · ${c.intensidade}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaContracao(BuildContext context, Contracao c) {
    return _cardExcluivel(context, c, child: _conteudoDaLinha(context, c));
  }

  Widget _conteudoDaLinha(BuildContext context, Contracao c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor(c.intensidade),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.inicio,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Duração: ${c.duracaoFormatada ?? '--:--'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: badgeBg(context, c.intensidade),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              c.intensidade,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: badgeText(c.intensidade),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grupos = gruposPorDia;
    final totalFiltrado = contracoesFiltradas.length;

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
                      'Histórico',
                      style: TextStyle(
                        color: AppColors.textPrimary(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Acompanhe todos os registros',
                      style: TextStyle(
                        color: AppColors.textSecondary(context),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: ['Hoje', 'Semana', 'Mês'].map((f) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filtro = f),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 13,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: _filtro == f
                                    ? AppTheme.primaryPurple
                                    : AppColors.statPurple(context),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                f,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: _filtro == f
                                      ? Colors.white
                                      : AppTheme.primaryPurple,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _carregando
                    ? const Center(child: CircularProgressIndicator())
                    : _erro != null
                    ? _painelDeErro(context)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF534AB7), Color(0xFF7F77DD)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                _summaryItem('$totalFiltrado', 'Total'),
                                _divider(),
                                _summaryItem(intervaloMedio, 'Intervalo'),
                                _divider(),
                                _summaryItem(duracaoMedia, 'Duração méd.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (grupos.isEmpty && semData.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface(context),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.border(context),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'Nenhuma contração registrada.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            )
                          else
                            ...grupos.expand((grupo) {
                              return [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 8,
                                    top: 4,
                                  ),
                                  child: Text(
                                    rotuloDia(grupo.key),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8,
                                      color: AppColors.textMuted(context),
                                    ),
                                  ),
                                ),
                                ...grupo.value.map(
                                  (c) => _linhaContracao(context, c),
                                ),
                                const SizedBox(height: 6),
                              ];
                            }),

                          if (semData.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 4),
                              child: Text(
                                'SEM DATA VÁLIDA',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted(context),
                                ),
                              ),
                            ),
                            ...semData.map((c) => _linhaSemData(context, c)),
                          ],
                        ],
                      ),
              ),
              navBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _painelDeErro(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Não foi possível carregar seu histórico',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _erro!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.35,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Tentar novamente',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String valor, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(255, 255, 255, 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color.fromRGBO(255, 255, 255, 0.2),
    );
  }
}
