# MenuWatch

Aplicativo Android (Flutter) que acompanha cardápios digitais. Você cola o link
de um cardápio, o app lê os pratos, guarda no aparelho e avisa quando algo muda
ou quando um prato favorito aparece.

Tudo roda no celular: não há servidor, conta nem banco de dados externo.

## O que o app faz

- Lê cardápios em página web, PDF, imagem e links do Canva.
- Identifica nome, descrição, preço, categoria e, quando o cardápio traz uma
  data, se o prato está confirmado para o dia.
- Verifica os cardápios de tempos em tempos e registra pratos novos, removidos
  e mudanças de preço.
- Notifica mudanças e a volta de pratos favoritos, sem repetir o mesmo aviso.
- Tema claro e escuro.

## Limites conhecidos

- A verificação em segundo plano depende do Android: o intervalo mínimo é de
  15 minutos e o sistema pode atrasar a execução para economizar bateria.
- Páginas que só montam o conteúdo com JavaScript (inclusive alguns links do
  Canva) são relidas apenas com o app aberto.
- A leitura é feita por regras, sem IA. Cardápios com diagramação muito livre
  podem ser lidos com erros; texto em imagem depende da qualidade do OCR.
- Os dados ficam só neste aparelho. Não há sincronização nem backup.
- O app respeita o `robots.txt` e não contorna login nem bloqueios. Quando um
  link não pode ser lido, a tela explica o motivo.
- Um prato listado num cardápio permanente aparece como "no cardápio", não
  como "servido hoje". A disponibilidade só é confirmada quando o cardápio
  informa a data.

## Estrutura

```
lib/
  main.dart            inicialização e MaterialApp
  models/              Menu, Dish, histórico, avisos e ajustes
  providers/           estado do app (Riverpod)
  routes/              rotas (go_router)
  screens/             início, adicionar, cardápio, favoritos, avisos, ajustes
  widgets/             linha de prato, folha de detalhes, casca com abas etc.
  theme/               cores, tipografia e tema Material 3
  utils/               normalização de texto, datas e preços
  services/
    storage.dart       arquivo JSON local
    monitor.dart       verificação dos cardápios e geração de avisos
    differ.dart        comparação entre duas leituras
    background.dart    agendamento com WorkManager
    alerts.dart        notificações locais
    extraction/        download, HTML, PDF, OCR e renderização em WebView
    parser/            interpretação do texto em pratos
test/                  testes unitários e de comportamento
test_shots/            capturas de tela das telas (fora da suíte)
```

## Desenvolvimento

Requer Flutter 3.47 ou mais novo e o Android SDK.

```bash
flutter pub get
flutter analyze
flutter test
```

Capturas de tela de todas as telas, nos dois temas, em `test_shots/out/`:

```bash
flutter test --update-goldens test_shots/shots_test.dart
```

Os dados de exemplo usados nas capturas e nos testes ficam só em `test/` e não
entram no aplicativo.

## Gerar o APK

```bash
flutter build apk --release --target-platform android-arm,android-arm64
```

O arquivo sai em `build/app/outputs/flutter-apk/app-release.apk`.

A assinatura usa `android/key.properties` e
`android/keystore/menuwatch-release.jks`. Os dois ficam fora do controle de
versão. Guarde uma cópia deles em lugar seguro: sem a mesma chave, não dá para
publicar atualizações que instalem por cima da versão atual.
