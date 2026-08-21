# Diagnóstico: OpenCode não abre projeto px3321-stock-reference

Data: 2026-08-21 ~16:40 (sessão ses_fda35b9ceffe09WwLuRpG72RP1)

## Sintoma
Ao abrir o OpenCode na pasta `~/Documents/Projetos/px3321-stock-reference`,
todas as rotas falham com `EPERM: operation not permitted, lstat` no
`FileSystem.realPath`. Só acontece com essa pasta/serviço.

## Causa identificada
Processo de longa duração `opencode2 serve --service` (PID 47065 no momento,
pai = launchd, iniciado 16:20:12) com estado interno corrompido/velho para o
workspace daquela pasta. O erro aparece no log a partir de 16:20:45:
`~/.local/share/opencode/log/opencode.log`.

## O que foi descartado (com evidência)
- Permissões POSIX/BSD flags/ACLs da pasta: normais (escrita testada ok)
- `com.apple.macl`: presente em várias pastas que funcionam (Knurl também tem)
- iCloud/mounts estranhos: nenhum
- TCC do terminal: descartado — shell filho do MESMO serviço acessa tudo
- Reprodução limpa: `opencode --print-logs run "responda apenas: OK"` DENTRO
  da pasta px3321-stock-reference funcionou perfeitamente (respondeu OK,
  watcher bootou, sem EPERM)

## Solução aplicada
1. Matar o serviço velho: `kill 47065` (encerra todas as sessões OpenCode)
2. Reabrir: `cd ~/Documents/Projetos/px3321-stock-reference && opencode`

Se voltar a acontecer: procurar por `opencode2 serve --service`
(`ps aux | grep "[s]erve --service"`), matar e reabrir.
