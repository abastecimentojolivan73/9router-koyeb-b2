# 9Router + Backblaze B2 + Litestream no Koyeb

Esta imagem deriva de `decolua/9router:latest`, adiciona o Litestream e usa o Backblaze B2 como réplica remota do SQLite.

O objetivo é manter o banco principal do 9Router em `/app/data/db/data.sqlite`, enquanto o Koyeb continua tratando o filesystem do container como efêmero. A imagem restaura o banco do B2 **antes** de iniciar o Node/9Router e, depois, o Litestream supervisiona o processo do 9Router e replica as alterações continuamente.

O 9Router documenta `DATA_DIR=/app/data`, porta `20128` e o banco principal em `/app/data/db/data.sqlite`. Consulte a documentação do projeto para detalhes sobre o layout de dados.  
Fonte: https://github.com/Raisolah/9router/blob/main/DOCKER.md

## Estrutura

```text
.
├── Dockerfile
├── entrypoint.sh
├── litestream.yml
└── README.md
```

## Como funciona

```text
Koyeb container
┌─────────────────────────────────────────────┐
│                                             │
│  entrypoint.sh                              │
│       │                                     │
│       ├── existe data.sqlite? ── SIM ─────┐ │
│       │                                    │ │
│       └── NÃO → restore do B2              │ │
│                    │                       │ │
│                    ▼                       │ │
│              data.sqlite                   │ │
│                    │                       │ │
│                    ▼                       │ │
│       Litestream replicate                 │ │
│                    │                       │ │
│                    ▼                       │ │
│              9Router / Node               │ │
│                                             │
└─────────────────────┬───────────────────────┘
                      │
                      ▼
             Backblaze B2 / S3
             9router/database
```

## 1. Crie o bucket no Backblaze B2

Crie um bucket privado no B2 e anote:

- nome do bucket
- região
- endpoint S3 do bucket

O endpoint tem o formato:

```text
https://s3.<REGION>.backblazeb2.com
```

Exemplo:

```text
https://s3.us-west-004.backblazeb2.com
```

Para o S3-Compatible API do Backblaze, use uma **Application Key** criada especificamente para isso. Não use a master application key.

Recomenda-se restringir a Application Key ao bucket que será usado pelo 9Router.

## 2. Crie a Application Key

No Backblaze:

`B2 Cloud Storage → Application Keys → Add a New Application Key`

Permissões recomendadas para este projeto:

- acesso ao bucket do 9Router;
- Read and Write;
- permissões suficientes para listar o bucket quando exigidas pelo S3 API.

Copie o `keyID` e o `applicationKey` quando forem exibidos.

## 3. Variáveis no Koyeb

No serviço do Koyeb, adicione:

```text
B2_KEY_ID=SEU_KEY_ID
B2_APPLICATION_KEY=SUA_APPLICATION_KEY
B2_BUCKET=SEU_BUCKET
B2_ENDPOINT=https://s3.SUA-REGIAO.backblazeb2.com
B2_REGION=SUA-REGIAO

DATA_DIR=/app/data
PORT=20128
HOSTNAME=0.0.0.0
```

Também mantenha as variáveis que você já utiliza no 9Router, principalmente os segredos de produção que sua instalação já tiver configurado, como `JWT_SECRET`, `INITIAL_PASSWORD`, `API_KEY_SECRET` e `MACHINE_ID_SALT`, quando aplicáveis à sua versão.

**Nunca coloque as chaves do B2 no GitHub.** Elas devem existir somente nos Secrets/Environment Variables do Koyeb.

## 4. Primeiro deployment: atenção ao banco atual

Antes de substituir a imagem que atualmente está rodando no Koyeb, faça uma cópia do seu `data.sqlite` atual. Isso é importante porque o B2 só poderá restaurar aquilo que já foi enviado para ele.

O Koyeb oferece acesso ao filesystem das instâncias via CLI. Primeiro liste as instâncias:

```bash
koyeb instances list
```

Depois copie o banco atual para seu computador:

```bash
koyeb instances cp INSTANCE_ID:/app/data/db/data.sqlite ./data.sqlite
```

Substitua `INSTANCE_ID` pelo ID real da sua instância.

## 5. Envie o banco atual para o B2 usando Litestream

A forma mais segura é criar a réplica Litestream usando a configuração deste repositório e o banco que você copiou.

Construa a imagem:

```bash
docker build -t 9router-b2 .
```

Depois inicialize a réplica no B2 com um snapshot completo:

### Linux/macOS

```bash
docker run --rm \
  --entrypoint litestream \
  -v "$PWD/data.sqlite:/app/data/db/data.sqlite" \
  -e B2_KEY_ID="SEU_KEY_ID" \
  -e B2_APPLICATION_KEY="SUA_APPLICATION_KEY" \
  -e B2_BUCKET="SEU_BUCKET" \
  -e B2_ENDPOINT="https://s3.SUA-REGIAO.backblazeb2.com" \
  -e B2_REGION="SUA-REGIAO" \
  9router-b2 \
  replicate -config /etc/litestream.yml -once -force-snapshot /app/data/db/data.sqlite
```

### PowerShell

```powershell
docker run --rm `
  --entrypoint litestream `
  -v "${PWD}/data.sqlite:/app/data/db/data.sqlite" `
  -e B2_KEY_ID="SEU_KEY_ID" `
  -e B2_APPLICATION_KEY="SUA_APPLICATION_KEY" `
  -e B2_BUCKET="SEU_BUCKET" `
  -e B2_ENDPOINT="https://s3.SUA-REGIAO.backblazeb2.com" `
  -e B2_REGION="SUA-REGIAO" `
  9router-b2 `
  replicate -config /etc/litestream.yml -once -force-snapshot /app/data/db/data.sqlite
```

Depois disso, o banco atual já estará no B2.

## 6. Suba a imagem no GitHub

Crie um repositório, por exemplo:

```text
9router-koyeb-b2
```

Coloque os quatro arquivos deste projeto na raiz e faça:

```bash
git init
git add .
git commit -m "Add 9Router B2 persistence with Litestream"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/9router-koyeb-b2.git
git push -u origin main
```

## 7. Conecte ao Koyeb

No Koyeb, crie/edite o serviço usando o repositório GitHub e selecione:

```text
Builder: Docker
Dockerfile: Dockerfile
Port: 20128
```

Use apenas **uma instância** no primeiro teste.

Mantenha a memória em 512 MB somente se o 9Router atual já estiver estável nesse limite. O Litestream é leve, mas 512 MB deixa pouca margem para picos do Node.

## 8. Primeiro boot

Se o B2 tiver a réplica inicial, os logs esperados serão semelhantes a:

```text
[9ROUTER-B2] Banco local não encontrado. Procurando réplica no B2...
[9ROUTER-B2] Banco restaurado do B2 com sucesso.
[9ROUTER-B2] Iniciando Litestream + 9Router...
```

Se o B2 estiver vazio, o comportamento será:

```text
[9ROUTER-B2] Nenhuma réplica encontrada. 9Router será inicializado com banco novo.
```

Isso é intencional. A imagem não bloqueia o primeiro boot quando ainda não existe backup.

## 9. O que fica persistente

A solução replica especificamente:

```text
/app/data/db/data.sqlite
```

Isso preserva os dados armazenados nesse banco.

Outros arquivos dentro de `/app/data`, como logs, certificados ou configurações que não estejam no SQLite, **não são automaticamente persistidos pelo B2 nesta versão**.

## 10. O que acontece quando o Koyeb recriar o container

```text
Container antigo
      ↓
filesystem apagado
      ↓
novo container
      ↓
entrypoint.sh
      ↓
sem data.sqlite
      ↓
Litestream restore
      ↓
B2
      ↓
data.sqlite restaurado
      ↓
Litestream replicate
      ↓
9Router iniciado
```

A restauração acontece antes da abertura do banco pelo 9Router.

## 11. Verificação manual

No Koyeb CLI, você pode verificar os processos:

```bash
koyeb instances exec INSTANCE_ID -- ps
```

E verificar o arquivo:

```bash
koyeb instances exec INSTANCE_ID -- ls -lh /app/data/db/
```

Os logs podem ser acompanhados pelo painel do Koyeb ou CLI.

## 12. Teste de recuperação antes de confiar no sistema

Faça um teste controlado:

1. confirme que o banco foi enviado ao B2;
2. confirme que o 9Router está funcionando;
3. redeploy/recrie a instância;
4. verifique os logs do `entrypoint.sh`;
5. confirme que suas configurações continuam no 9Router.

Não considere a solução validada até esse teste de restauração funcionar.

## 13. Observações sobre o Litestream

Este projeto usa Litestream `v0.5.16`.

A configuração segue a sintaxe atual do Litestream v0.5.x, na qual cada banco usa uma única chave `replica` em vez da antiga configuração `replicas`.

O `replicate -exec` é usado para manter o Litestream como processo principal e executar o 9Router como processo filho. Quando o processo filho termina, o Litestream também encerra.

## 14. Segurança

Nunca faça commit de:

```text
B2_KEY_ID
B2_APPLICATION_KEY
JWT_SECRET
INITIAL_PASSWORD
API_KEY_SECRET
MACHINE_ID_SALT
```

Se uma Application Key vazar, revogue-a no Backblaze e crie outra.

## Fontes oficiais

9Router Docker: https://github.com/Raisolah/9router/blob/main/DOCKER.md

Litestream configuração: https://litestream.io/reference/config/

Litestream restore: https://litestream.io/reference/restore/

Litestream replicate: https://litestream.io/reference/replicate/

Litestream + Backblaze B2: https://litestream.io/guides/backblaze/

Backblaze S3-Compatible API: https://www.backblaze.com/docs/cloud-storage-s3-compatible-api
