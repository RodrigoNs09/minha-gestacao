# Minha Gestação 🤱

App Flutter de acompanhamento da gestação, desenvolvido em parceria com fisioterapeutas. Nasceu como um monitor de contrações e evoluiu para acompanhar toda a gravidez — do primeiro registro até o parto.

Os dados ficam na conta da usuária, no Cloud Firestore. Cada pessoa acessa apenas os próprios registros, e eles acompanham a conta ao trocar de aparelho.

## Funcionalidades

### Conta e sessão
- **Cadastro e login por e-mail e senha**, via Firebase Authentication
- **Recuperação de senha** por e-mail, com resposta neutra — o formulário não revela se um e-mail está cadastrado
- **Sair da conta** sem apagar nada: os registros voltam no próximo login
- **Excluir a conta** em definitivo: apaga as cinco subcoleções, o documento raiz e o usuário do Firebase Auth, nessa ordem, após confirmação e reautenticação por senha

### Onboarding
- **Configuração inicial flexível** — a gestante informa quantas semanas está ou a data prevista do parto (DPP), sem precisar saber a data exata da última menstruação

### Contrações
- **Registro em tempo real** — cronômetro com início, duração e intensidade
- **Histórico** com filtros por hoje, semana e mês, e estatísticas derivadas dos registros

### Acompanhamento da gestação
- **Progresso** — semana atual, trimestre e tamanho do bebê comparado a frutas, calculado a partir da DUM e editável a qualquer momento
- **Contador de chutes** — meta de 10 movimentos, com o progresso salvo a cada toque; uma sessão iniciada sobrevive a sair da tela
- **Histórico de chutes** — sessões anteriores
- **Diário de sintomas** — humor do dia, checklist de sintomas comuns e registro de peso, com histórico dos dias anteriores
- **Agenda de consultas** — consultas e exames com contagem regressiva e histórico de realizados
- **Vacinação** — calendário de vacinas da gestação e registro das doses aplicadas

### Experiência
- **Tema claro e escuro**
- **Interface responsiva** — layout comum a todas as telas, testado de 320×568 a 800×1280, em retrato e paisagem, com escala de fonte até 1.5
- **Português do Brasil** como locale único

## Tecnologias

| Camada | Tecnologia |
|---|---|
| Framework | Flutter 3.41.6 (stable) |
| Linguagem | Dart 3.11.4 |
| Autenticação | Firebase Authentication (e-mail e senha) |
| Persistência | Cloud Firestore |
| Localização | `flutter_localizations` (pt-BR) |
| Plataforma de lançamento | Android (minSdk 24, targetSdk 36) |

Dependências de produção — deliberadamente enxutas:

```yaml
firebase_core: ^3.6.0
firebase_auth: ^5.3.1
cloud_firestore: ^5.4.4
flutter_localizations: # SDK
```

Em desenvolvimento: `flutter_test` (SDK) e `flutter_lints: ^6.0.0`.

O projeto não usa armazenamento local nem faz chamadas HTTP próprias e não integra analytics, Crashlytics ou mecanismos próprios de rastreamento no código do app.

Os diretórios `ios/`, `macos/`, `linux/`, `windows/` e `web/` existem por serem parte do template do Flutter, mas **só o Android é alvo de build e validação neste momento**. As demais plataformas não estão configuradas ou validadas para o fluxo de release atual.

## Persistência

Tudo vive sob o documento do usuário autenticado, identificado pelo UID do Firebase Auth:

```
usuarios/{uid}
├── gestacao_dum          (campo)  data da última menstruação
├── gestacao_id           (campo)  identidade da gestação atual
├── chute_em_andamento    (campo)  sessão de chutes não finalizada
├── contracoes/{id}       (subcoleção)
├── chutes/{id}           (subcoleção)
├── sintomas/{data}       (subcoleção, um documento por dia)
├── consultas/{id}        (subcoleção)
└── vacinas/{id}          (subcoleção)
```

Nada é gravado fora de `usuarios/{uid}`. Cada tela tem um *storage* correspondente em `lib/services/`, que grava documento a documento — a única exceção é a exclusão de conta, que precisa varrer as coleções em lotes.

As regras de segurança estão versionadas em [`firestore.rules`](firestore.rules) e restringem leitura e escrita ao dono do documento:

```
match /usuarios/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```

## Como rodar localmente

### Pré-requisitos

- Flutter SDK 3.41.x (Dart SDK `^3.11.4`)
- JDK 17 ou superior para a parte Android
- Um projeto Firebase com Authentication (e-mail/senha) e Cloud Firestore habilitados

Não é necessária nenhuma chave de API externa.

### Passo a passo

1. Clone o repositório:
   ```bash
   git clone https://github.com/RodrigoNs09/minha-gestacao.git
   cd minha-gestacao
   ```

2. Instale as dependências:
   ```bash
   flutter pub get
   ```

3. Rode no Android:
   ```bash
   flutter run -d android
   ```

O repositório já inclui `android/app/google-services.json` e `lib/firebase_options.dart` apontando para o projeto Firebase do app. Para usar um projeto próprio, regenere os dois com `flutterfire configure`.

### Build de release

A assinatura de release exige dois arquivos que **não são versionados**:

- `android/upload-keystore.jks` — a upload key
- `android/key.properties` — com `storePassword`, `keyPassword`, `keyAlias` e `storeFile`

Sem eles o Gradle falha com mensagem explícita, de propósito: assinar um release com a chave de debug produz um artefato que o Google Play rejeita. Gere a keystore com:

```bash
keytool -genkeypair -v -keystore android/upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias minha-gestacao-upload
```

O app usa **Google Play App Signing**: a chave acima é a de upload, não a de assinatura final.

### Testes

```bash
flutter test -j 1
```

A flag `-j 1` não é opcional em máquinas com pouca RAM — a execução paralela esgota a memória da VM do Dart. A suíte tem 1476 testes, incluindo testes de responsividade que montam as telas em seis tamanhos de tela e testes estruturais que travam invariantes de arquitetura lendo o código-fonte.

## Estrutura do projeto

```
lib/
├── main.dart                        # Entry point, gate de autenticação e HomeScreen
├── firebase_options.dart            # Gerado pelo FlutterFire
├── theme/
│   └── app_theme.dart               # Paleta e suporte a tema claro/escuro
├── widgets/
│   ├── moldura_responsiva.dart      # Moldura compartilhada por todas as telas
│   └── editar_dum_dialog.dart       # Folha para editar a data da gestação
├── models/
│   ├── contracao.dart
│   ├── gestacao_info.dart           # Semana, trimestre e tamanho do bebê
│   ├── chute_sessao.dart
│   ├── registro_sintomas.dart
│   ├── registro_vacinacao.dart
│   └── consulta.dart
├── data/                            # Estado em memória da sessão
│   ├── sessao.dart
│   ├── gestacao_data.dart
│   ├── contracoes_data.dart
│   ├── chutes_data.dart
│   ├── sintomas_data.dart
│   ├── consultas_data.dart
│   ├── vacinas_calendario_2026.dart
│   └── vacinas_ui.dart
├── services/
│   ├── auth_service.dart            # Cadastro, login, recuperação, logout, exclusão
│   ├── exclusao_de_conta.dart       # Orquestra a exclusão de dados e conta
│   ├── firestore_error.dart         # Tradução de erros para mensagens ao usuário
│   ├── vacinas_engine.dart
│   └── *_storage.dart               # Um por coleção do Firestore
└── screens/
    ├── login_screen.dart
    ├── register_screen.dart
    ├── onboarding_screen.dart       # Configuração inicial (semanas ou DPP)
    ├── contracao_screen.dart        # Cronômetro e registro de contrações
    ├── historico_screen.dart        # Histórico de contrações com filtros
    ├── chutes_screen.dart           # Contador de chutes
    ├── historico_chutes_screen.dart
    ├── sintomas_screen.dart         # Diário de sintomas
    ├── agenda_screen.dart           # Agenda de consultas
    ├── vacinas_screen.dart          # Calendário e registro de vacinação
    └── conta_screen.dart            # Sessão, sair e excluir conta
```

## Sobre o projeto

Desenvolvido inicialmente como projeto acadêmico em parceria com fisioterapeutas do **Pilates Bioestética**, com foco em apoiar gestantes durante a gestação. Recebeu nota **9.0** na avaliação acadêmica, quando ainda se chamava "Sua Contração".

Evoluiu para **Minha Gestação** com o objetivo de acompanhar toda a jornada da gravidez, não só o momento do parto — unindo monitoramento clínico (contrações) com bem-estar diário (sintomas, chutes, consultas, vacinação).

## Autor

**Rodrigo Nascimento da Silva**
- GitHub: [@RodrigoNs09](https://github.com/RodrigoNs09)
- E-mail: rodrigotw.com.br@gmail.com
