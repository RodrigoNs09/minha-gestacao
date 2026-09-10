import 'package:flutter/material.dart';
import '../data/consultas_data.dart';
import '../models/consulta.dart';
import '../services/consultas_storage.dart';
import '../services/firestore_error.dart';
import '../theme/app_theme.dart';

List<Consulta> ordenadasPorData(
  List<Consulta> consultas, {
  required bool maisAntigaPrimeiro,
}) {
  final comData = <Consulta>[];
  final semData = <Consulta>[];

  for (final c in consultas) {
    (c.dataHora == null ? semData : comData).add(c);
  }

  comData.sort((a, b) {
    final umaData = a.dataHora!;
    final outraData = b.dataHora!;
    return maisAntigaPrimeiro
        ? umaData.compareTo(outraData)
        : outraData.compareTo(umaData);
  });

  return [...comData, ...semData];
}

const String mensagemSemSessao =
    'Não foi possível concluir: sessão expirada. Entre novamente.';

String resumoDaConsulta(Consulta c) {
  final partes = [
    c.titulo,
    c.data,
    c.hora,
    c.profissional,
  ].where((parte) => parte.trim().isNotEmpty).toList();

  return partes.isEmpty ? 'Consulta sem informações' : partes.join(' · ');
}

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  String? _idPendente;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final dados = await ConsultasStorage.carregarConsultas();
      if (!mounted) return;
      setState(() => listaConsultas = dados);
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FirestoreErro.mensagemAmigavel(erro))),
      );
    }
  }

  List<Consulta> get _proximas => ordenadasPorData(
    listaConsultas.where((c) => !c.realizada).toList(),
    maisAntigaPrimeiro: true,
  );

  List<Consulta> get _realizadas => ordenadasPorData(
    listaConsultas.where((c) => c.realizada).toList(),
    maisAntigaPrimeiro: false,
  );

  Future<void> _marcarComoRealizada(Consulta c) async {
    final index = listaConsultas.indexWhere((x) => x.id == c.id);
    if (index == -1) return;

    final anterior = listaConsultas[index];
    final atualizada = anterior.copyWith(realizada: true);
    listaConsultas[index] = atualizada;

    bool atualizou = false;
    Object? erro;
    try {

      atualizou = await ConsultasStorage.atualizar(atualizada);
    } catch (e) {
      erro = e;
    }

    if (!mounted) return;

    if (atualizou) {
      setState(() {});
      return;
    }

    final indiceAtual = listaConsultas.indexWhere((x) => x.id == c.id);
    if (indiceAtual != -1) {
      listaConsultas[indiceAtual] = anterior;
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro != null ? FirestoreErro.mensagemAmigavel(erro) : mensagemSemSessao,
        ),
      ),
    );
  }

  Future<bool> _confirmarExclusao(Consulta c) async {
    final resposta = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface(ctx),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Excluir consulta?',
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
                'Esta consulta será removida da sua agenda.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary(ctx),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resumoDaConsulta(c),
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

  Future<bool> _confirmarEExcluir(Consulta c) async {
    if (!await _confirmarExclusao(c)) return false;
    if (!mounted) return false;

    bool removeu = false;
    Object? erro;
    try {
      removeu = await ConsultasStorage.remover(c.id);
    } catch (e) {
      erro = e;
    }

    if (!mounted) return false;
    if (removeu) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          erro != null ? FirestoreErro.mensagemAmigavel(erro) : mensagemSemSessao,
        ),
      ),
    );
    return false;
  }

  Future<void> _abrirFormularioNovaConsulta() async {
    final tituloController = TextEditingController();
    final profissionalController = TextEditingController();
    DateTime dataEscolhida = DateTime.now().add(const Duration(days: 7));
    TimeOfDay horaEscolhida = const TimeOfDay(hour: 10, minute: 0);
    bool salvando = false;

    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface(ctx),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.border(ctx),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Text('Nova consulta',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary(ctx))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tituloController,
                    decoration: InputDecoration(
                      labelText: 'Título (ex: Pré-natal)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: profissionalController,
                    decoration: InputDecoration(
                      labelText: 'Médico(a) / Local',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final data = await showDatePicker(
                              context: ctx,
                              initialDate: dataEscolhida,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 300)),
                            );
                            if (data != null) setModalState(() => dataEscolhida = data);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border(ctx)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  '${dataEscolhida.day.toString().padLeft(2, '0')}/${dataEscolhida.month.toString().padLeft(2, '0')}/${dataEscolhida.year}',
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary(ctx)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final hora = await showTimePicker(context: ctx, initialTime: horaEscolhida);
                            if (hora != null) setModalState(() => horaEscolhida = hora);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border(ctx)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 16, color: AppTheme.primaryPurple),
                                const SizedBox(width: 8),
                                Text(
                                  '${horaEscolhida.hour.toString().padLeft(2, '0')}:${horaEscolhida.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary(ctx)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: salvando ? null : () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: AppColors.border(ctx)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Cancelar', style: TextStyle(color: AppColors.textPrimary(ctx))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: salvando
                              ? null
                              : () async {
                                  if (tituloController.text.trim().isEmpty) return;

                                  _idPendente ??= DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString();

                                  final novaConsulta = Consulta(
                                    id: _idPendente!,
                                    titulo: tituloController.text.trim(),
                                    profissional: profissionalController.text.trim(),
                                    data:
                                        '${dataEscolhida.year}-${dataEscolhida.month.toString().padLeft(2, '0')}-${dataEscolhida.day.toString().padLeft(2, '0')}',
                                    hora:
                                        '${horaEscolhida.hour.toString().padLeft(2, '0')}:${horaEscolhida.minute.toString().padLeft(2, '0')}',
                                  );

                                  setModalState(() => salvando = true);

                                  Consulta? salva;
                                  Object? erro;
                                  try {
                                    salva = await ConsultasStorage.adicionar(novaConsulta);
                                  } catch (e) {
                                    erro = e;
                                  }

                                  if (!ctx.mounted) return;

                                  if (salva == null) {

                                    setModalState(() => salvando = false);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          erro != null
                                              ? FirestoreErro.mensagemAmigavel(erro)
                                              : mensagemSemSessao,
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  listaConsultas.add(salva);
                                  _idPendente = null;
                                  Navigator.pop(ctx, true);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryPurple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Adicionar', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (salvou == true) setState(() {});
  }

  String _diasRestantesTexto(int? dias) {
    if (dias == null) return 'Data inválida';
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Amanhã';
    if (dias < 0) return 'Atrasada';
    return 'Em $dias dias';
  }

  Widget _consultaCard(Consulta c, {bool passada = false}) {
    final dataHora = c.dataHora;
    const meses = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    const dias = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

    return Dismissible(
      key: Key(c.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
      ),
      confirmDismiss: (_) => _confirmarEExcluir(c),
      onDismissed: (_) => setState(() => listaConsultas.removeWhere((x) => x.id == c.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context), width: 0.5),
        ),
        child: Opacity(
          opacity: passada ? 0.55 : 1.0,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 52,
                decoration: BoxDecoration(
                  color: passada ? AppColors.statPurple(context).withOpacity(0.5) : AppColors.statPurple(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dataHora == null

                      ? [
                          Icon(Icons.error_outline_rounded, size: 20, color: AppTheme.primaryPurple),
                          Text('--', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                        ]
                      : [
                          Text(dias[dataHora.weekday % 7], style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                          Text('${dataHora.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                          Text(meses[dataHora.month - 1], style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: AppTheme.primaryPurple)),
                        ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary(context),
                        decoration: passada ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(

                        dataHora == null
                            ? '${c.data} ${c.hora} · ${c.profissional}'.trim()
                            : '${c.hora} · ${c.profissional}',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary(context))),
                    if (dataHora == null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statPink(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Data inválida',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: Color(0xFF72243E))),
                      ),
                    ] else if (!passada) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.statPurple(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(_diasRestantesTexto(c.diasRestantes),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.accentText(context))),
                      ),
                    ] else
                      Text('Realizada', style: TextStyle(fontSize: 9, color: AppColors.textMuted(context))),
                  ],
                ),
              ),
              if (!passada)
                IconButton(
                  onPressed: () => _marcarComoRealizada(c),
                  icon: Icon(Icons.check_circle_outline_rounded, color: AppColors.textMuted(context), size: 20),
                  tooltip: 'Marcar como realizada',
                ),
            ],
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Agenda',
                                style: TextStyle(color: AppColors.textPrimary(context), fontSize: 20, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 3),
                            Text('Consultas e exames',
                                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                          ],
                        ),
                        GestureDetector(
                          onTap: _abrirFormularioNovaConsulta,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPurple,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('+ Nova', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
                  children: [
                    Text('PRÓXIMAS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: AppColors.textMuted(context))),
                    const SizedBox(height: 8),
                    if (_proximas.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border(context), width: 0.5),
                        ),
                        child: Text('Nenhuma consulta agendada. Toque em "+ Nova" para adicionar.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                      )
                    else
                      ..._proximas.map((c) => _consultaCard(c)),
                    if (_realizadas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('REALIZADAS',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.8, color: AppColors.textMuted(context))),
                      const SizedBox(height: 8),
                      ..._realizadas.map((c) => _consultaCard(c, passada: true)),
                    ],
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