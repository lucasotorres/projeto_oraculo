-- ============================================================
-- PROJETO ORÁCULO - FATEC ZL
-- Regras de Negócio: Triggers, UDFs e Stored Procedures
-- Banco: SQL Server
-- ============================================================


-- ============================================================
-- 1. TABELA AUXILIAR: Histórico das 3 últimas mensagens
--    (Criada por tipo de mensagem para não repetir sorteio)
-- ============================================================

IF OBJECT_ID('tb_historico_mensagem', 'U') IS NULL
BEGIN
    CREATE TABLE tb_historico_mensagem (
        id            INT IDENTITY(1,1) PRIMARY KEY,
        id_tipo       INT          NOT NULL,  -- FK para tb_tipo_mensagem
        id_mensagem   INT          NOT NULL,  -- ID da mensagem sorteada
        dt_ocorrencia DATETIME     NOT NULL DEFAULT GETDATE(),
        CONSTRAINT FK_historico_tipo FOREIGN KEY (id_tipo)
            REFERENCES tb_tipo_mensagem(id)
    );
END
GO


-- ============================================================
-- 2. TRIGGERS
-- ============================================================

-- 2.1 Bloquear UPDATE e DELETE em mensagens (imutáveis)
-- Aplica-se às 3 tabelas de mensagem

IF OBJECT_ID('trg_bloqueia_update_delete_vida_pessoal', 'TR') IS NOT NULL
    DROP TRIGGER trg_bloqueia_update_delete_vida_pessoal;
GO
CREATE TRIGGER trg_bloqueia_update_delete_vida_pessoal
ON tb_mensagem_vida_pessoal
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('Mensagens de vida pessoal não podem ser alteradas ou excluídas.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO

IF OBJECT_ID('trg_bloqueia_update_delete_trabalho', 'TR') IS NOT NULL
    DROP TRIGGER trg_bloqueia_update_delete_trabalho;
GO
CREATE TRIGGER trg_bloqueia_update_delete_trabalho
ON tb_mensagem_trabalho
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('Mensagens de trabalho não podem ser alteradas ou excluídas.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO

IF OBJECT_ID('trg_bloqueia_update_delete_estudo', 'TR') IS NOT NULL
    DROP TRIGGER trg_bloqueia_update_delete_estudo;
GO
CREATE TRIGGER trg_bloqueia_update_delete_estudo
ON tb_mensagem_estudo
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('Mensagens de estudo não podem ser alteradas ou excluídas.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO

-- 2.2 Bloquear UPDATE e DELETE em candidatos (imutáveis)

IF OBJECT_ID('trg_bloqueia_update_delete_candidato', 'TR') IS NOT NULL
    DROP TRIGGER trg_bloqueia_update_delete_candidato;
GO
CREATE TRIGGER trg_bloqueia_update_delete_candidato
ON tb_candidato
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    RAISERROR('Registros de candidatos não podem ser alterados ou excluídos.', 16, 1);
    ROLLBACK TRANSACTION;
END;
GO

-- 2.3 Trigger: Manter apenas as 3 últimas ocorrências no histórico por tipo
--     A cada INSERT no histórico, remove os registros mais antigos além dos 3 últimos

IF OBJECT_ID('trg_limita_historico_mensagem', 'TR') IS NOT NULL
    DROP TRIGGER trg_limita_historico_mensagem;
GO
CREATE TRIGGER trg_limita_historico_mensagem
ON tb_historico_mensagem
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_tipo INT;
    SELECT @id_tipo = id_tipo FROM inserted;

    -- Mantém somente os 3 registros mais recentes para o tipo inserido
    DELETE FROM tb_historico_mensagem
    WHERE id_tipo = @id_tipo
      AND id NOT IN (
          SELECT TOP 3 id
          FROM tb_historico_mensagem
          WHERE id_tipo = @id_tipo
          ORDER BY dt_ocorrencia DESC
      );
END;
GO


-- ============================================================
-- 3. UDF (User Defined Function)
--    Retorna um ID de mensagem aleatório que NÃO esteja
--    nas últimas 3 ocorrências registradas para aquele tipo.
-- ============================================================

IF OBJECT_ID('fn_sorteia_mensagem', 'FN') IS NOT NULL
    DROP FUNCTION fn_sorteia_mensagem;
GO
CREATE FUNCTION fn_sorteia_mensagem (@id_tipo INT)
RETURNS INT
AS
BEGIN
    DECLARE @id_sorteado INT;

    -- Busca IDs já exibidos recentemente para este tipo
    -- e sorteia um ID que NÃO esteja nessa lista
    IF @id_tipo = 1  -- vida pessoal
    BEGIN
        SELECT TOP 1 @id_sorteado = id
        FROM tb_mensagem_vida_pessoal
        WHERE id NOT IN (
            SELECT id_mensagem
            FROM tb_historico_mensagem
            WHERE id_tipo = @id_tipo
        )
        ORDER BY NEWID();
    END
    ELSE IF @id_tipo = 2  -- trabalho
    BEGIN
        SELECT TOP 1 @id_sorteado = id
        FROM tb_mensagem_trabalho
        WHERE id NOT IN (
            SELECT id_mensagem
            FROM tb_historico_mensagem
            WHERE id_tipo = @id_tipo
        )
        ORDER BY NEWID();
    END
    ELSE IF @id_tipo = 3  -- estudo
    BEGIN
        SELECT TOP 1 @id_sorteado = id
        FROM tb_mensagem_estudo
        WHERE id NOT IN (
            SELECT id_mensagem
            FROM tb_historico_mensagem
            WHERE id_tipo = @id_tipo
        )
        ORDER BY NEWID();
    END;

    -- Fallback: se todas as mensagens já foram exibidas recentemente,
    -- sorteia qualquer uma (edge case com poucas mensagens)
    IF @id_sorteado IS NULL
    BEGIN
        IF @id_tipo = 1
            SELECT TOP 1 @id_sorteado = id FROM tb_mensagem_vida_pessoal ORDER BY NEWID();
        ELSE IF @id_tipo = 2
            SELECT TOP 1 @id_sorteado = id FROM tb_mensagem_trabalho ORDER BY NEWID();
        ELSE IF @id_tipo = 3
            SELECT TOP 1 @id_sorteado = id FROM tb_mensagem_estudo ORDER BY NEWID();
    END;

    RETURN @id_sorteado;
END;
GO


-- ============================================================
-- 4. STORED PROCEDURES
-- ============================================================

-- 4.1 Procedure principal do Oráculo
--     Usa a UDF acima, registra no histórico e retorna a mensagem

IF OBJECT_ID('sp_sorteia_e_registra_mensagem', 'P') IS NOT NULL
    DROP PROCEDURE sp_sorteia_e_registra_mensagem;
GO
CREATE PROCEDURE sp_sorteia_e_registra_mensagem
    @id_tipo     INT,
    @mensagem    NVARCHAR(500) OUTPUT,
    @id_mensagem INT           OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Usa a UDF para obter o ID sorteado (sem repetir as 3 últimas)
    SET @id_mensagem = dbo.fn_sorteia_mensagem(@id_tipo);

    IF @id_mensagem IS NULL
    BEGIN
        SET @mensagem = 'Nenhuma mensagem disponível para este tipo.';
        RETURN;
    END;

    -- Recupera o texto da mensagem conforme o tipo
    IF @id_tipo = 1
        SELECT @mensagem = descricao FROM tb_mensagem_vida_pessoal WHERE id = @id_mensagem;
    ELSE IF @id_tipo = 2
        SELECT @mensagem = descricao FROM tb_mensagem_trabalho WHERE id = @id_mensagem;
    ELSE IF @id_tipo = 3
        SELECT @mensagem = descricao FROM tb_mensagem_estudo WHERE id = @id_mensagem;

    -- Registra no histórico (o trigger trg_limita_historico_mensagem
    -- cuida de manter apenas as 3 últimas automaticamente)
    INSERT INTO tb_historico_mensagem (id_tipo, id_mensagem, dt_ocorrencia)
    VALUES (@id_tipo, @id_mensagem, GETDATE());
END;
GO


-- 4.2 Procedure de validação de login e senha (admin)
--     Sem Spring Security — validação simples em banco

IF OBJECT_ID('sp_valida_login', 'P') IS NOT NULL
    DROP PROCEDURE sp_valida_login;
GO
CREATE PROCEDURE sp_valida_login
    @login     VARCHAR(50),
    @senha     VARCHAR(50),
    @autorizado BIT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Credenciais fixas conforme especificado no enunciado
    IF @login = 'admin' AND @senha = 'UhR@n?M1'
        SET @autorizado = 1;
    ELSE
        SET @autorizado = 0;
END;
GO


-- ============================================================
-- 5. COMO CHAMAR AS PROCEDURES NO JAVA (JDBC / Spring)
-- ============================================================
--
-- sp_sorteia_e_registra_mensagem:
--
--   StoredProcedureQuery query = em.createStoredProcedureQuery("sp_sorteia_e_registra_mensagem");
--   query.registerStoredProcedureParameter("id_tipo",     Integer.class, ParameterMode.IN);
--   query.registerStoredProcedureParameter("mensagem",    String.class,  ParameterMode.OUT);
--   query.registerStoredProcedureParameter("id_mensagem", Integer.class, ParameterMode.OUT);
--   query.setParameter("id_tipo", idTipo);
--   query.execute();
--   String mensagem    = (String)  query.getOutputParameterValue("mensagem");
--   Integer idMensagem = (Integer) query.getOutputParameterValue("id_mensagem");
--
-- sp_valida_login:
--
--   StoredProcedureQuery query = em.createStoredProcedureQuery("sp_valida_login");
--   query.registerStoredProcedureParameter("login",      String.class,  ParameterMode.IN);
--   query.registerStoredProcedureParameter("senha",      String.class,  ParameterMode.IN);
--   query.registerStoredProcedureParameter("autorizado", Boolean.class, ParameterMode.OUT);
--   query.setParameter("login", login);
--   query.setParameter("senha", senha);
--   query.execute();
--   Boolean autorizado = (Boolean) query.getOutputParameterValue("autorizado");
--
-- ============================================================
-- FIM DO SCRIPT
-- ============================================================
