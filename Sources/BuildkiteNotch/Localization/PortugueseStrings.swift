import BuildkiteNotchCore

struct PortugueseStrings: Strings {
    // MARK: Menus
    let refreshNow = "Atualizar agora"
    let settingsMenuItem = "Preferências…"
    let quit = "Sair"
    let closeWindow = "Fechar janela"
    let quitApp = "Sair do Buildkite Notch"
    let edit = "Editar"
    let undo = "Desfazer"
    let redo = "Refazer"
    let cut = "Recortar"
    let copy = "Copiar"
    let paste = "Colar"
    let selectAll = "Selecionar tudo"

    // MARK: Notch
    let refresh = "Atualizar"
    let settings = "Preferências"
    let openSettings = "Abrir Preferências"
    let connectAccount = "Conecte sua conta Buildkite"
    let choosePipelines = "Escolha os pipelines para acompanhar"
    let noRecentBuilds = "Sem builds recentes"
    let noMessage = "(sem mensagem)"
    let queued = "na fila"
    let queuedShort = "fila"
    let justNow = "agora"

    func ago(_ age: String) -> String { "há \(age)" }

    func jobs(finished: Int, total: Int) -> String { "\(finished)/\(total) jobs" }

    func label(for glyph: Glyph) -> String {
        switch glyph {
        case .idle: "ocioso"
        case .scheduled: "na fila"
        case .running: "rodando"
        case .failing: "falhando"
        case .passed: "passou"
        case .failed: "falhou"
        case .blocked: "aguardando"
        case .canceled: "cancelado"
        }
    }

    // MARK: Notifications
    func title(for event: BuildEventKind) -> String {
        switch event {
        case .passed: "✅ Passou"
        case .failed: "❌ Falhou"
        case .blocked: "⏸ Aguardando aprovação"
        case .canceled: "⛔️ Cancelado"
        }
    }

    // MARK: Settings
    let account = "Conta"
    let connect = "Conectar"
    let disconnect = "Desconectar"
    let organization = "Organização"

    func tokenHelp(scopes: String) -> String {
        "Crie um token em buildkite.com/user/api-access-tokens com os escopos \(scopes)."
    }

    func connected(as user: String?, missingScopes: [String]) -> String {
        let status = "Conectado: \(user ?? "token válido")"
        return missingScopes.isEmpty ? status : "\(status). Faltam escopos: \(missingScopes.joined(separator: ", "))"
    }

    func pipelinesHeader(selected: Int) -> String {
        "Pipelines (\(selected) \(selected == 1 ? "selecionado" : "selecionados"))"
    }

    let connectToListPipelines = "Conecte uma conta para listar os pipelines."
    let noPipelinesLoaded = "Nenhum pipeline carregado."
    let search = "Buscar"
    let branches = "Branches"
    let branchesHelp = "Branches separadas por vírgula. Vazio acompanha todas as branches."
    let notchPosition = "Posição do notch"
    let edge = "Borda"

    func name(for edge: ScreenEdge) -> String {
        switch edge {
        case .top: "Topo"
        case .bottom: "Base"
        case .left: "Esquerda"
        case .right: "Direita"
        }
    }

    let position = "Posição"
    let center = "Centralizar"
    let display = "Tela"
    let mainDisplay = "Principal"
    let dragHint = "Dica: segure ⌥ Option sobre o notch e arraste para movê-lo para qualquer borda."
    let appearance = "Aparência"
    let notchStyle = "Estilo do notch"

    func name(for style: NotchStyle) -> String {
        switch style {
        case .liquidGlass: "Liquid Glass"
        case .darkGlass: "Dark Glass"
        case .solidBlack: "Preto sólido"
        }
    }

    let refreshInterval = "Intervalo de atualização"
    let whileBuildsRun = "Com builds rodando"
    let whenIdle = "Sem builds rodando"
    let secondsUnit = "s"

    func pollIntervalHelp(range: ClosedRange<Int>) -> String {
        "Entre \(range.lowerBound) e \(range.upperBound) segundos. Intervalos curtos com muitos pipelines consomem mais do limite de requisições da API do Buildkite."
    }

    let general = "Geral"
    let language = "Idioma"
    let systemLanguage = "Padrão do sistema"
    let languageHelp = "Textos desenhados pelo macOS, como menus de contexto, mudam na próxima vez que o app abrir."
    let notifyWhenFinished = "Notificar quando builds terminarem"
    let launchAtLogin = "Abrir ao iniciar sessão"

    func loginItemFailed(_ reason: String) -> String { "Não foi possível alterar o login: \(reason)" }

    // MARK: Errors
    func describe(_ error: BuildkiteError) -> String {
        switch error {
        case .unauthorized: "Token inválido ou revogado."
        case .forbidden(let message): message ?? "Token sem permissão (verifique os escopos)."
        case .notFound: "Recurso não encontrado."
        case .rateLimited: "Limite de requisições da API atingido."
        case .http(let status, let message): message ?? "Erro HTTP \(status)."
        case .invalidResponse: "Resposta inválida da API."
        }
    }
}
