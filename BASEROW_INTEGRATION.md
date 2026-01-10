# Integração Baserow - Servidor Próprio

## Configuração do Servidor

- **URL Base:** `http://213.199.56.115`
- **API Endpoint:** `http://213.199.56.115/api/database/rows/table`

## IDs das Tabelas

| Tabela | ID API | URL Admin |
|--------|--------|-----------|
| Usuarios | 4931 | http://213.199.56.115/database/774/table/4931/7800 |
| Filmes & Series | 4932 | http://213.199.56.115/database/774/table/4932/7801 |
| Categorias | 4933 | http://213.199.56.115/database/774/table/4933/7802 |
| Enviar Notificações | 4934 | http://213.199.56.115/database/774/table/4934/7803 |
| Episodios | 4935 | http://213.199.56.115/database/774/table/4935/7804 |

## Estrutura das Tabelas

### Filmes & Series (7801)
- Nome, Nome Formatado
- Sinopse
- Capa, Capa de fundo
- Data de Lançamento
- Imdb, Views
- Tipo (Filmes/Series)
- Categoria/Categorias
- Link
- Duração
- Temporadas
- UID (TMDB ID)

### Episodios (7804)
- Nome
- Link
- Temporada
- Episodio
- Data

### Categorias (7802)
- Nome

### Usuarios (7800)
- Dados de usuários

### Enviar Notificações (7803)
- Dados de notificações push

## Notas
- Servidor próprio com linhas ilimitadas
- Token de autenticação deve ser configurado no `baserow_service.dart`
