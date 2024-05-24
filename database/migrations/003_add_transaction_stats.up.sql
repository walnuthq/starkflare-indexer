BEGIN;

CREATE OR REPLACE FUNCTION starkflare_api.get_transaction_stats()
RETURNS TABLE (
    transactions_count_last_7_days INTEGER[7],
    steps_number_last_7_days BIGINT[7]
)
AS $$
DECLARE
	current_transactions_count INTEGER;
	current_steps_number BIGINT;
BEGIN
    FOR i in 0..6 LOOP
        SELECT count(*), COALESCE(SUM(steps_number), 0)
        INTO current_transactions_count, current_steps_number
        FROM starkflare_api.account_calls
        WHERE timestamp BETWEEN EXTRACT(EPOCH FROM CURRENT_DATE - (7 - i))
          AND EXTRACT(EPOCH FROM CURRENT_DATE - (6 - i));
        transactions_count_last_7_days[i] := current_transactions_count;
        steps_number_last_7_days[i] := current_steps_number;
    END LOOP;
    RETURN QUERY
    SELECT transactions_count_last_7_days, steps_number_last_7_days;
END;
$$ LANGUAGE plpgsql;

DROP FUNCTION IF EXISTS starkflare_api.get_common_data();

CREATE OR REPLACE FUNCTION starkflare_api.get_common_data()
RETURNS json
AS $$
DECLARE
    user_stats json;
    transaction_stats json;
BEGIN
    SELECT json_build_object(
        'unique_users_last_7_days', user_stats.unique_users_last_7_days,
        'new_users_last_7_days', user_stats.new_users_last_7_days,
        'lost_users_last_7_days', user_stats.lost_users_last_7_days
    ) INTO user_stats
    FROM starkflare_api.get_user_stats() AS user_stats;
    SELECT json_build_object(
        'transactions_count_last_7_days', transaction_stats.transactions_count_last_7_days,
        'steps_number_last_7_days', transaction_stats.steps_number_last_7_days
    ) INTO transaction_stats 
    FROM starkflare_api.get_transaction_stats() AS transaction_stats;

    RETURN json_build_object('user_stats', user_stats, 'transaction_stats', transaction_stats);
END;
$$ LANGUAGE plpgsql;

COMMIT;
