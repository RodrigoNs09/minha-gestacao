import 'package:flutter/material.dart';

import '../services/vacinas_engine.dart' show EstadoVacina;
import '../theme/app_theme.dart';

typedef CorDeSuperficie = Color Function(BuildContext context);

@immutable
class ApresentacaoDeEstado {
  final String rotulo;

  final IconData icone;

  final CorDeSuperficie fundo;

  const ApresentacaoDeEstado({
    required this.rotulo,
    required this.icone,
    required this.fundo,
  });
}

ApresentacaoDeEstado apresentacaoDe(EstadoVacina estado) {
  switch (estado) {
    case EstadoVacina.periodoRecomendado:
      return const ApresentacaoDeEstado(
        rotulo: 'Período recomendado',
        icone: Icons.event_available,
        fundo: AppColors.statGreen,
      );

    case EstadoVacina.aguardarIntervalo:
      return const ApresentacaoDeEstado(
        rotulo: 'Aguardando intervalo',
        icone: Icons.hourglass_bottom,
        fundo: AppColors.statOrange,
      );

    case EstadoVacina.verificarHistorico:
      return const ApresentacaoDeEstado(
        rotulo: 'Verificar histórico',
        icone: Icons.help_outline,
        fundo: AppColors.statOrange,
      );

    case EstadoVacina.avaliacaoProfissional:
      return const ApresentacaoDeEstado(
        rotulo: 'Avaliação profissional',
        icone: Icons.medical_services_outlined,
        fundo: AppColors.statPurple,
      );

    case EstadoVacina.naoDisponivel:
      return const ApresentacaoDeEstado(
        rotulo: 'Ainda não',
        icone: Icons.schedule,
        fundo: AppColors.statPurple,
      );

    case EstadoVacina.registrada:
      return const ApresentacaoDeEstado(
        rotulo: 'Registrada',
        icone: Icons.check_circle_outline,
        fundo: AppColors.statGreen,
      );

    case EstadoVacina.naoIndicada:
      return const ApresentacaoDeEstado(
        rotulo: 'Não indicada',
        icone: Icons.remove_circle_outline,
        fundo: AppColors.statPurple,
      );
  }
}
