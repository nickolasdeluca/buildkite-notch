# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versões seguem
[SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Adicionado

- Interface em inglês (en-US), além de português (pt-BR). O app segue o idioma do macOS e pode ser
  trocado em Preferências → Geral → Idioma.

### Corrigido

- Cask do Homebrew usa a sintaxe atual de `depends_on macos`, sem aviso de descontinuação.

## [0.1.0] - 2026-09-24

### Adicionado

- Notch com um anel de progresso por pipeline e card expandido ao passar o mouse.
- Posicionamento em qualquer borda de qualquer tela, com arraste via ⌥ Option.
- Notificações de build que passou, falhou, foi cancelado ou aguarda aprovação.
- Preferências: token no Keychain, organização, pipelines, filtro de branches, posição, aparência
  (Liquid Glass, Dark Glass, Preto sólido), notificações e abrir ao iniciar sessão.
- Ícone no Dock enquanto as Preferências estão abertas.
- Distribuição assinada com Developer ID, notarizada e instalável via Homebrew.
