import 'package:flutter/material.dart';

class ModoAcompanhanteScreen extends StatelessWidget {
  const ModoAcompanhanteScreen({super.key});

  Widget infoCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeBg,
    Color? badgeColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color.fromRGBO(0, 0, 0, 0.07),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF26215C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF888780),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg ?? const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: badgeColor ?? const Color(0xFF0F6E56),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget navBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color.fromRGBO(0, 0, 0, 0.06),
          width: 0.5,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Icon(Icons.home_rounded, color: Color(0xFF888780), size: 20),
          Icon(Icons.access_time_rounded, color: Color(0xFF888780), size: 20),
          Icon(Icons.auto_graph_rounded, color: Color(0xFF888780), size: 20),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  color: Color(0xFF534AB7), size: 20),
              SizedBox(height: 3),
              CircleAvatar(
                radius: 2,
                backgroundColor: Color(0xFF534AB7),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EEFF),
      body: Center(
        child: Container(
          width: 300,
          constraints: const BoxConstraints(minHeight: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: const Color.fromRGBO(0, 0, 0, 0.08),
              width: 0.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFDF6FF),
                  border: Border(
                    bottom: BorderSide(
                      color: Color.fromRGBO(0, 0, 0, 0.05),
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
                        children: const [
                          Icon(
                            Icons.chevron_left_rounded,
                            color: Color(0xFF7F77DD),
                            size: 18,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Voltar',
                            style: TextStyle(
                              color: Color(0xFF7F77DD),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Modo Acompanhante',
                      style: TextStyle(
                        color: Color(0xFF26215C),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Orientações rápidas para apoiar a gestante',
                      style: TextStyle(
                        color: Color(0xFF888780),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE1F5EE), Color(0xFFF7FFFB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(15, 110, 86, 0.12),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.favorite_outline_rounded,
                              size: 20,
                              color: Color(0xFF0F6E56),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Acompanhe, apoie e ajude a manter a gestante segura e calma durante as contrações.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF085041),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    infoCard(
                      icon: Icons.self_improvement_rounded,
                      iconBg: const Color(0xFFEEEDFE),
                      iconColor: const Color(0xFF534AB7),
                      title: 'Mantenha a calma',
                      subtitle:
                          'Sua tranquilidade ajuda a gestante a se sentir mais segura.',
                    ),
                    infoCard(
                      icon: Icons.access_time_rounded,
                      iconBg: const Color(0xFFE1F5EE),
                      iconColor: const Color(0xFF0F6E56),
                      title: 'Observe as contrações',
                      subtitle:
                          'Acompanhe duração, intervalo e intensidade para apoiar a decisão.',
                    ),
                    infoCard(
                      icon: Icons.air_rounded,
                      iconBg: const Color(0xFFFAEEDA),
                      iconColor: const Color(0xFF854F0B),
                      title: 'Ajude na respiração',
                      subtitle:
                          'Respirações lentas e profundas ajudam no foco e no alívio.',
                    ),
                    infoCard(
                      icon: Icons.folder_open_rounded,
                      iconBg: const Color(0xFFEEEDFE),
                      iconColor: const Color(0xFF534AB7),
                      title: 'Separe documentos e itens',
                      subtitle:
                          'Deixe tudo pronto para a ida à maternidade sem pressa.',
                    ),
                    infoCard(
                      icon: Icons.warning_amber_rounded,
                      iconBg: const Color(0xFFFBEAF0),
                      iconColor: const Color(0xFFD4537E),
                      title: 'Atenção aos sinais de risco',
                      subtitle:
                          'Sangramento importante, perda de consciência ou dor intensa fora do padrão exigem urgência.',
                      badge: 'IMPORTANTE',
                      badgeBg: const Color(0xFFFBEAF0),
                      badgeColor: const Color(0xFF72243E),
                    ),
                  ],
                ),
              ),
              navBar(),
            ],
          ),
        ),
      ),
    );
  }
}