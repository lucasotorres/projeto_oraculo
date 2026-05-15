🔮 Oráculo FATEC ZL — Oracle Event App

Java Web · Spring Boot · Spring Data JPA · MySQL

Aplicação web desenvolvida para o evento de portas abertas da FATEC Zona Leste, com dois propósitos: entreter alunos do ensino médio por meio de um oráculo temático e cadastrá-los como potenciais candidatos para futuros vestibulares.

✨ Funcionalidades

Tela inicial fullscreen com temática geek/oráculo
Oráculo com mensagens aleatórias por categoria (vida pessoal, trabalho e estudos), com controle das 3 últimas exibições para evitar repetições
Cadastro automático de potenciais candidatos com redirecionamento após 15 segundos
Painel administrativo restrito para gerenciamento de mensagens e consulta de candidatos
Consultas por curso, bairro, ordenação e recorte temporal (10 primeiros / 10 últimos)
Carga automática de mensagens via arquivos .txt em resources/txts/
🗄️ Banco de Dados & SQL

Triggers para regras de negócio de candidatos e mensagens
UDF + Stored Procedure para lógica de curiosidades
Procedure para autenticação administrativa (sem Spring Security)
Consultas com findBy, JPQL e Native Queries no Repository
🏗️ Stack & Arquitetura

Java 17 + Spring Boot
Spring Web + Spring Data JPA
MySQL + Hibernate
JSP + CSS / Bootstrap
Padrão MVC (SOLID)
Maven + mvn site
📁 Estrutura relevante

src/main/resources/txts/
├── tipoMensagem.txt
├── vidaPessoal.txt
├── trabalho.txt
└── estudo.txt
doc/
├── DiagramaClasse.png
└── DiagramaER.png
