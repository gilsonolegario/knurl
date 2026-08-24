# Knurl — Instruções do projeto

Regras globais (`~/.config/opencode/AGENTS.md`) valem sempre; este arquivo tem precedência neste diretório.

**TeX diagnostics & package installer for macOS**: analisa projeto `.tex`, mapeia `\usepackage` para pacotes TeX Live (overrides embutidos + mapping oficial TUG) e instala o que falta via `tlmgr` — pedindo admin só quando necessário. Swift 6.0 (tools 6.0), SwiftPM puro, macOS 15+, binário universal (arm64+x86_64). MIT, público em `github.com/gilsonolegario/knurl`; site em Pages via **worktree `.site-worktree/`** (branch `gh-pages`). Commits estilo conventional, em inglês.

## Comandos

```bash
swift build                      # debug
swift build -c release           # release
swift test                       # 156 testes (KnurlCoreTests + KnurlTests)
swift run Knurl                  # roda o app da árvore

# Universal (Apple Silicon + Intel):
swift build -c release --arch arm64 && swift build -c release --arch x86_64
lipo -create .build/arm64-apple-macosx/release/Knurl \
            .build/x86_64-apple-macosx/release/Knurl -output Knurl-universal
```

Bundle `.app` em `dist/` é montado MANUALMENTE: binário universal (não o slice x86_64!) + `Knurl_Knurl.bundle` (resources do SwiftPM) dentro de `Contents/Resources`. Assinatura com Apple ID gratuito — **não notarizado**: Gatekeeper pede right-click → Open ou `xattr -dr com.apple.quarantine`.

## Arquitetura e convenções

- **KnurlCore** = biblioteca de lógica pura (parsing, detecção de distribuição/engine, CTANMapper, InstallPlanner, relatórios) — SEM dependência de UI, totalmente testada. **Lógica nova entra no KnurlCore com teste.** `Knurl` = app SwiftUI (glass UI, dropzone, painel de log).
- Estilo obrigatório (commit `1550c7b`): headers por arquivo, `///` nas APIs públicas, `// MARK:` organizando seções.
- **Botões/UI nativos era Sequoia** (`docs/botoes-convencoes.md`): primário `.appProminent()` (pill âmbar, label escuro), secundário `.bordered`, toolbar `.borderless`; todo botão de ação tem ícone. **Glass só em conteúdo** (shim `glassEffectCompat` em `Brand.swift`) — NUNCA em botões de ação. Sem Material-3, sem hover/scaleEffect custom.
- Instalação com root passa por coordinator dedicado (`InstallCoordinator`/`NativeAdminRunner`) com consentimento explícito — **o app nunca roda privilegiado**; não adicionar escalada silenciosa.

## Zonas proibidas

- `.site-worktree/` é o worktree do branch `gh-pages` (site publicado) — não editar/apagar por engano.
- `dist/` e `build/` são artefatos gitignored — não commitar; o `.app` do dist só reflete cópia manual.
- PNGs soltos na raiz (`ChatGPT Image *.png`, `latex-icon-concept*.png`) são rascunho de ícone — não são source, não limpar sem pedir.
