# MangaReader iOS

Leitor SwiftUI para capítulos disponibilizados por uma fonte que o usuário tem autorização para acessar.

## O que já tem

- Campo para colar URL do capítulo.
- Descoberta das imagens das páginas no HTML.
- Leitura vertical com zoom nativo do sistema.
- Contador de páginas.
- Salvamento da última página por capítulo.
- Lista de capítulos encontrados na página.
- Botão para carregar o próximo capítulo.
- Interface simples para iPhone.

## Como abrir

1. Abra o projeto no Xcode em um Mac.
2. Crie um projeto iOS SwiftUI vazio ou use estes arquivos no projeto.
3. Defina o deployment target conforme o seu iPhone.
4. Adicione `MangaReaderApp.swift`, `ContentView.swift` e `ReaderModel.swift`.
5. Execute no simulador ou em um iPhone conectado com uma conta Apple.

## Observação

O parser é deliberadamente genérico: ele procura imagens e links de capítulos no HTML. Sites podem alterar sua estrutura, usar lazy-loading, proteção anti-bot ou URLs temporárias; nesse caso, o parser precisa ser ajustado.

Use o app somente com conteúdos que você tenha autorização para acessar/usar.
