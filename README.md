# Sua Contração 🤱

App Flutter de monitoramento inteligente de contrações para gestantes, desenvolvido em parceria com fisioterapeutas. Oferece registro em tempo real, análise de padrões com IA e modo acompanhante para suporte durante o trabalho de parto.

## Funcionalidades

- **Registro de contrações** — timer em tempo real com início, duração e intensidade
- **Histórico** — filtros por hoje, semana e mês com estatísticas dinâmicas
- **Análise Inteligente** — gráfico de distribuição por período do dia e insights gerados por IA
- **Assistente de Dúvidas** — respostas com apoio de IA para dúvidas sobre o trabalho de parto
- **Modo Acompanhante** — visão simplificada para o parceiro acompanhar em tempo real
- **Modo escuro / claro** — toggle com persistência e paleta adaptada à identidade do app

## Tecnologias

| Camada        | Tecnologia                        |
|---------------|----------------------------------|
| Framework     | Flutter 3.x                      |
| Linguagem     | Dart                             |
| IA            | Anthropic Claude API             |
| Persistência  | SharedPreferences                |
| Plataforma    | Android, iOS, Web, Windows       |

## Como rodar localmente

### Pré-requisitos

- Flutter SDK 3.x instalado
- Chave de API da Anthropic (para o Assistente de Dúvidas)

## Estrutura do projeto

```
lib/
├── theme/
│   └── app_theme.dart          # Paleta de cores e suporte a dark mode
├── models/
│   └── contracao.dart          # Modelo de dados
├── data/
│   └── contracoes_data.dart    # Lista global de contrações
├── services/
│   └── contracoes_storage.dart # Persistência com SharedPreferences
├── screens/
│   ├── contracao_screen.dart   # Timer e registro de contrações
│   ├── historico_screen.dart   # Histórico com filtros
│   ├── analise_screen.dart     # Gráfico e análise com IA
│   ├── assistente_screen.dart  # Chat com IA
│   └── modo_acompanhante_screen.dart
└── main.dart                   # App entry point + HomeScreen
```

## Sobre o projeto

Desenvolvido como projeto acadêmico em parceria com fisioterapeutas do **Pilates Bioestética**, com foco em apoiar gestantes durante o trabalho de parto. Recebeu nota **9.0** na avaliação acadêmica.

O app está em evolução contínua com planos de expandir para um acompanhamento completo da gestação — diário de sintomas, contador de chutes, agenda de consultas e mais.

## Autor

**Rodrigo Nascimento da Silva**
- GitHub: [@RodrigoNs09](https://github.com/RodrigoNs09)
- E-mail: rodrigotw.com.br@gmail.com