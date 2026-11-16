USE food_delivery_db;

DROP PROCEDURE IF EXISTS assert_statement_rejected;

DELIMITER $$

CREATE PROCEDURE assert_statement_rejected(
    IN p_statement TEXT,
    IN p_test_name VARCHAR(100)
)
BEGIN
    DECLARE v_rejected BOOLEAN DEFAULT FALSE;
    DECLARE v_message VARCHAR(128);

    BEGIN
        DECLARE CONTINUE HANDLER FOR SQLEXCEPTION SET v_rejected = TRUE;
        SET @test_statement = p_statement;
        PREPARE test_statement FROM @test_statement;
        EXECUTE test_statement;
        DEALLOCATE PREPARE test_statement;
    END;

    IF NOT v_rejected THEN
        SET v_message = CONCAT('Expected statement to fail: ', p_test_name);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_message;
    END IF;
END$$

CREATE PROCEDURE assert_decimal_query_equals(
    IN p_query TEXT,
    IN p_expected DECIMAL(12,2),
    IN p_test_name VARCHAR(100)
)
BEGIN
    DECLARE v_message VARCHAR(128);

    SET @assert_actual = NULL;
    SET @test_statement = CONCAT('SET @assert_actual = (', p_query, ')');
    PREPARE test_statement FROM @test_statement;
    EXECUTE test_statement;
    DEALLOCATE PREPARE test_statement;

    IF NOT (@assert_actual <=> p_expected) THEN
        SET v_message = CONCAT('Unexpected value: ', p_test_name);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_message;
    END IF;
END$$

DELIMITER ;
