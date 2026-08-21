# TODO

## Interface (próxima iteração)

- **Exibir na interface onde cada pacote foi instalado**: após uma instalação com sucesso, mostrar o caminho real do artefato (ex.: `~/Library/texmf/tex/latex/fancyhdr/`, ou a árvore do sistema `/usr/local/texlive/<ano>/texmf-dist/...` para `tlmgr` sem usermode). Incluir nota curta de que `~/Library/texmf` já está no caminho de busca do kpathsea e que os aplicativos de LaTeX referenciam os pacotes automaticamente.
- **Ação "Revelar no Finder"** por pacote instalado (botão na linha da tabela do relatório ou no detalhe do estado).
- **Mostrar o TEXMFHOME detectado** (resultado de `userTexmfPath()`) na seção de ambiente do relatório, para o usuário saber o destino antes de instalar.

## Diagnóstico / bootstrap (lição da sessão 2026-08-10)

- [x] **Sinalizar claramente quando uma distribuição TeX está ausente ou quebrada**: entregue em 2026-08-10 via `TeXDistribution.detect` (estados ok/missing/broken) + banner persistente na UI com CTA "Instalar BasicTeX" (bootstrap). Ver `docs/superpowers/specs/2026-08-10-install-all-tex-status-design.md`.
- **Bootstrap deve validar o estado pós-instalação**: conferir que `/Library/TeX/texbin/pdflatex` e `kpsewhich` existem e respondem; limpar distribuições antigas/quebradas (ex.: `.DefaultTeX` com `Contents` vazio, `.texdist` vazios, `texmf-local` órfão) antes de instalar.

