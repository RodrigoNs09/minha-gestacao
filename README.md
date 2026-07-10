# Minha Gestação 🤱

App Flutter completo de acompanhamento de gestação, desenvolvido em parceria com fisioterapeutas. Nasceu como um monitor de contrações e evoluiu para um companheiro completo da gravidez — do primeiro sinal até o parto.

## Funcionalidades

### Contrações
- **Registro em tempo real** — timer com início, duração e intensidade
- **Histórico** — filtros por hoje, semana e mês com estatísticas dinâmicas
- **Assistente de Dúvidas** — respostas com apoio de IA sobre o trabalho de parto

### Gestação
- **Progresso da gestação** — semana atual, trimestre e tamanho do bebê comparado a frutas, calculado automaticamente a partir da data da última menstruação
- **Contador de Chutes** — monitora os movimentos do bebê com meta de 10 chutes, histórico de sessões
- **Diário de Sintomas** — humor do dia, checklist de sintomas comuns e registro de peso
- **Agenda de Consultas** — cadastro de consultas e exames com contagem regressiva, histórico de realizadas

### Experiência
- **Modo escuro / claro** — toggle com persistência e paleta adaptada à identidade visual
- **Dados 100% locais** — tudo salvo no dispositivo via SharedPreferences, sem necessidade de internet

## Tecnologias

| Camada        | Tecnologia                        |
|---------------|------------------------------------|
| Framework     | Flutter 3.x                        |
| Linguagem     | Dart                                |
| IA            | Anthropic Claude API                |
| Persistência  | SharedPreferences                   |
| Plataforma    | Android, iOS, Web, Windows          |

## Como rodar localmente

### Pré-requisitos

- Flutter SDK 3.x instalado
- Chave de API da Anthropic (para o Assistente de Dúvidas)

### Passo a passo

1. Clone o repositório:
   ```bash
   git clone https://github.com/RodrigoNs09/sua-contracao-.git
   cd sua-contracao-
   ```

2. Instale as dependências:
   ```bash
   flutter pub get
   ```

3. Rode o projeto:
   ```bash
   # Web
   flutter run -d chrome

   # Android (com emulador ou dispositivo conectado)
   flutter run -d android
   ```

## Estrutura do projeto

```
lib/
├── theme/
│   └── app_theme.dart              # Paleta de cores e suporte a dark mode
├── widgets/
│   └── editar_dum_dialog.dart       # Modal para editar data da gestação
├── models/
│   ├── contracao.dart
│   ├── gestacao_info.dart           # Cálculo de semana, trimestre e tamanho do bebê
│   ├── chute_sessao.dart
│   ├── registro_sintomas.dart
│   └── consulta.dart
├── data/
│   ├── contracoes_data.dart
│   ├── gestacao_data.dart
│   ├── chutes_data.dart
│   ├── sintomas_data.dart
│   └── consultas_data.dart
├── services/
│   ├── contracoes_storage.dart
│   ├── gestacao_storage.dart
│   ├── chutes_storage.dart
│   ├── sintomas_storage.dart
│   └── consultas_storage.dart
├── screens/
│   ├── contracao_screen.dart        # Timer e registro de contrações
│   ├── historico_screen.dart        # Histórico com filtros
│   ├── assistente_screen.dart       # Chat com IA
│   ├── chutes_screen.dart           # Contador de chutes
│   ├── sintomas_screen.dart         # Diário de sintomas
│   └── agenda_screen.dart           # Agenda de consultas
└── main.dart                        # App entry point + HomeScreen
```

## Sobre o projeto

Desenvolvido inicialmente como projeto acadêmico em parceria com fisioterapeutas do **Pilates Bioestética**, com foco em apoiar gestantes durante o trabalho de parto. Recebeu nota **9.0** na avaliação acadêmica como "Sua Contração".

Evoluiu para **Minha Gestação** com o objetivo de acompanhar toda a jornada da gravidez, não só o momento do parto — unindo monitoramento clínico (contrações) com bem-estar diário (sintomas, chutes, consultas).

## Autor

**Rodrigo Nascimento da Silva**
- GitHub: [@RodrigoNs09](https://github.com/RodrigoNs09)
- E-mail: rodrigotw.com.br@gmail.com