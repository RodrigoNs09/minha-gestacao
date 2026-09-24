import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const String textoDoAvisoDeSaude =
    'O Minha Gestação é uma ferramenta de acompanhamento e registro. Não é '
    'um dispositivo médico e não diagnostica, trata, cura nem previne '
    'condições de saúde. As informações do app não substituem a avaliação de '
    'um profissional de saúde. Em caso de dúvida, preocupação ou urgência, '
    'procure atendimento profissional.';

class AvisoDeSaude extends StatelessWidget {
  const AvisoDeSaude({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textMuted(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              textoDoAvisoDeSaude,
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
