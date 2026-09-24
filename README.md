# Buildkite Notch

Um notch para macOS que acompanha os builds e deploys dos seus pipelines do
[Buildkite](https://buildkite.com), inspirado no [Codenotch](https://github.com/vinzdg/codenotch).

- **Notch recolhido:** um anel por pipeline. O arco mostra o progresso dos jobs na cor do estado
  (amarelo rodando, vermelho falhou, roxo aguardando aprovação, verde passou), com o tempo decorrido
  ou há quanto tempo o build terminou.
- **Hover:** abre um card com uma seção por pipeline (barra de progresso, jobs, branch, commit) e os
  builds recentes. Clique em qualquer item para abrir o build no Buildkite.
- **Notificações** quando um build passa, falha, é cancelado ou fica aguardando aprovação.
- **Posição livre:** topo, base, esquerda ou direita de qualquer tela. Nas laterais o notch fica na
  vertical. Segure **⌥ Option** sobre o notch e arraste, ou ajuste em Preferências → Posição do notch.
  Em Macs com notch físico, no topo e centralizado, ele se funde ao notch da câmera.
- **Aparência:** Liquid Glass, Dark Glass ou Preto sólido.

## Instalação

### Homebrew

```sh
brew install --cask nickolasdeluca/tap/buildkite-notch
```

### Manual

Baixe o `BuildkiteNotch-<versão>.zip` da [última release](https://github.com/nickolasdeluca/buildkite-notch/releases/latest),
descompacte e mova `BuildkiteNotch.app` para `/Applications`. O app é assinado e notarizado pela Apple.

Requer macOS 14 (Sonoma) ou posterior, Apple Silicon ou Intel.

## Configuração

Na primeira execução a janela de Preferências abre sozinha (depois, use o ícone na barra de menu).

1. Crie um token em <https://buildkite.com/user/api-access-tokens> com os escopos
   `read_builds`, `read_pipelines` e `read_organizations`.
2. Cole o token e clique em **Conectar**.
3. Escolha a organização e marque os pipelines que quer acompanhar.
4. Opcional: filtre por branches (ex.: `main, production`).

O token fica no Keychain do macOS. Nada sai da sua máquina além das chamadas à API do Buildkite.
O app consulta a API a cada 10 s enquanto há builds rodando, a cada 30 s parado e espera 60 s se
atingir o limite de requisições.

## Desenvolvimento

Requer Xcode 16+ (Swift 6). Não há projeto Xcode: o app é um pacote SwiftPM e o `Makefile` monta o `.app`.

```sh
make run      # build debug, monta build/BuildkiteNotch.app e abre
make test     # testes do módulo core
make release  # build release universal (arm64 + x86_64), assinatura ad-hoc
make install  # release + copia para /Applications
make icon     # regera Resources/AppIcon.icns a partir de Scripts/make-icon.swift
```

Builds locais usam assinatura ad-hoc, então o macOS pode pedir acesso ao Keychain após cada rebuild.

### Estrutura

```
Sources/BuildkiteNotchCore/   API REST v2, modelos, regras de notificação e geometria do notch (sem UI, testável)
Sources/BuildkiteNotch/       App AppKit + SwiftUI
  Notch/                      Janela do notch, notch recolhido, card, estilos
  Services/                   Preferências, Keychain, polling (BuildStore), notificações
  Settings/                   Janela de Preferências
Tests/BuildkiteNotchCoreTests/
Resources/                    Info.plist e AppIcon.icns
Scripts/                      make-icon.swift, release.sh
```

## Distribuição

As releases são assinadas com **Developer ID**, notarizadas e publicadas no GitHub. O cask do
Homebrew fica em [`nickolasdeluca/homebrew-tap`](https://github.com/nickolasdeluca/homebrew-tap).

Preparação (uma vez por máquina):

1. **Certificado Developer ID Application:** Xcode → Settings → Accounts → sua equipe →
   Manage Certificates → **+** → *Developer ID Application*. Só o Account Holder da conta pode criá-lo.
2. **Credenciais de notarização:** copie `Scripts/release.env.example` para `Scripts/release.env`
   (fora do git) e preencha **uma** das opções:
   - `NOTARY_PROFILE`: um perfil salvo com `xcrun notarytool store-credentials`. Perfis valem por
     time, então um criado para outro projeto serve aqui.
   - `APPLE_API_KEY_PATH`, `APPLE_API_KEY_ID` e `APPLE_API_ISSUER_ID`: chave de API do App Store
     Connect (Users and Access → Integrations → Keys).
3. **Tap do Homebrew:** um repositório público `nickolasdeluca/homebrew-tap` (pode começar vazio).

Para publicar uma versão:

```sh
make bump VERSION=0.2.0   # atualiza Info.plist
# atualize o CHANGELOG.md e faça o commit
make dist                 # só gera build/BuildkiteNotch-0.2.0.zip assinado e notarizado
make publish              # dist + tag + GitHub Release + atualização do cask
```

Todas as variáveis estão documentadas em `Scripts/release.env.example`. Variáveis exportadas no
shell têm prioridade sobre o arquivo.
