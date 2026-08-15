import 'package:flutter/material.dart';
import '../data/gestacao_data.dart';
import '../services/gestacao_storage.dart';
import '../theme/app_theme.dart';

enum _ModoInformar { semanas, dpp }

Future<void> mostrarEditarDUM(BuildContext context, VoidCallback aoSalvar) async {
  _ModoInformar modo = _ModoInformar.semanas;
  int semanasInformadas = gestacaoAtual.semanaAtual;
  DateTime? dppEscolhida;

  final resultado = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          bool podeConfirmar() {
            if (modo == _ModoInformar.semanas) return true;
            return dppEscolhida != null;
          }

          Future<void> escolherDPP() async {
            final data = await showDatePicker(
              context: ctx,
              initialDate: DateTime.now().add(const Duration(days: 140)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 300)),
              helpText: 'Data provável do parto',
              cancelText: 'Cancelar',
              confirmText: 'OK',
            );
            if (data != null) {
              setModalState(() => dppEscolhida = data);
            }
          }

          Widget opcaoModo({
            required _ModoInformar valor,
            required IconData icon,
            required String titulo,
            required String subtitulo,
          }) {
            final selecionado = modo == valor;
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setModalState(() => modo = valor),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: selecionado ? AppColors.statPurple(ctx) : AppColors.surface(ctx),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selecionado ? AppTheme.primaryPurple : AppColors.border(ctx),
                    width: selecionado ? 1.5 : 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selecionado ? AppTheme.primaryPurple : AppColors.statPurple(ctx),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(icon, color: selecionado ? Colors.white : AppTheme.primaryPurple, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary(ctx))),
                          Text(subtitulo, style: TextStyle(fontSize: 10, color: AppColors.textSecondary(ctx))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          Widget campoDetalhe() {
            if (modo == _ModoInformar.semanas) {
              return Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.statPurple(ctx),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text('Semana atual',
                        style: TextStyle(fontSize: 11, color: AppColors.accentText(ctx), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => setModalState(
                              () => semanasInformadas = (semanasInformadas - 1).clamp(1, 42)),
                          icon: Icon(Icons.remove_circle_outline_rounded, color: AppTheme.primaryPurple),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '$semanasInformadas',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.accentText(ctx)),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setModalState(
                              () => semanasInformadas = (semanasInformadas + 1).clamp(1, 42)),
                          icon: Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryPurple),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Container(
              margin: const EdgeInsets.only(top: 4, bottom: 16),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: escolherDPP,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.statPurple(ctx),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: dppEscolhida != null ? AppTheme.primaryPurple : AppTheme.primaryPurple.withOpacity(0.2),
                      width: dppEscolhida != null ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.primaryPurple),
                      const SizedBox(width: 8),
                      Text(
                        dppEscolhida == null
                            ? 'Selecionar data prevista'
                            : '${dppEscolhida!.day.toString().padLeft(2, '0')}/${dppEscolhida!.month.toString().padLeft(2, '0')}/${dppEscolhida!.year}',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary(ctx)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

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
                Text(
                  'Editar progresso da gestação',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary(ctx)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Como você prefere informar?',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(ctx)),
                ),
                const SizedBox(height: 16),

                opcaoModo(
                  valor: _ModoInformar.semanas,
                  icon: Icons.calendar_view_week_rounded,
                  titulo: 'Sei quantas semanas estou',
                  subtitulo: 'Ajustar direto o número',
                ),
                opcaoModo(
                  valor: _ModoInformar.dpp,
                  icon: Icons.child_friendly_rounded,
                  titulo: 'Sei a data prevista do parto',
                  subtitulo: 'A data que o médico informou',
                ),

                campoDetalhe(),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
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
                        onPressed: podeConfirmar() ? () => Navigator.pop(ctx, true) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          disabledBackgroundColor: AppColors.textMuted(ctx),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Salvar', style: TextStyle(color: Colors.white)),
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

  if (resultado == true) {
    DateTime novaDum;

    if (modo == _ModoInformar.semanas) {
      novaDum = DateTime.now().subtract(Duration(days: semanasInformadas * 7));
    } else {
      novaDum = dppEscolhida!.subtract(const Duration(days: 280));
    }

    atualizarDUM(novaDum);
    await GestacaoStorage.salvarDUM(novaDum);
    aoSalvar();
  }
}