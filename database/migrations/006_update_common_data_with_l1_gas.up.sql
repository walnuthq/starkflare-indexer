-- 006_update_common_data_with_l1_gas.up.sql --
BEGIN;

DROP FUNCTION IF EXISTS starkflare_api.get_l1_gas_last_7_days();

-- Create a new function to get l1_data_gas for each of the last 7 days
CREATE OR REPLACE FUNCTION starkflare_api.get_l1_gas_last_7_days()
RETURNS TABLE (
    l1_data_gas_date DATE,
    l1_data_gas_last_7_days BIGINT,
    l1_gas_last_7_days BIGINT
)
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TO_TIMESTAMP(timestamp)::DATE AS l1_data_gas_date,
        SUM(l1_data_gas) AS l1_data_gas_last_7_days,
        SUM(l1_gas) AS l1_gas_last_7_days
    FROM 
        starkflare_api.account_calls
    WHERE 
        TO_TIMESTAMP(timestamp) >= NOW() - INTERVAL '6 days'
    GROUP BY 
        l1_data_gas_date
    ORDER BY 
        l1_data_gas_date;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission on the "get_l1_gas_last_7_days()" function to the web role
GRANT EXECUTE ON FUNCTION starkflare_api.get_l1_gas_last_7_days TO starkflare_web_anon;

-- Update the get_common_data function to include the new field

DROP FUNCTION IF EXISTS starkflare_api.get_common_data();

CREATE OR REPLACE FUNCTION starkflare_api.get_common_data()
RETURNS json
AS $$
DECLARE
    user_stats json;
    transaction_stats json;
    top_contracts_by_steps json;
    top_transactions json;
    l1_gas_stats json;
BEGIN
    -- Fetch user stats
    SELECT json_build_object(
        'unique_users_last_7_days', user_stats.unique_users_last_7_days,
        'new_users_last_7_days', user_stats.new_users_last_7_days,
        'lost_users_last_7_days', user_stats.lost_users_last_7_days
    ) INTO user_stats
    FROM starkflare_api.get_user_stats() AS user_stats;

    -- Fetch transaction stats
    SELECT json_build_object(
        'transactions_count_last_7_days', transaction_stats.transactions_count_last_7_days,
        'steps_number_last_7_days', transaction_stats.steps_number_last_7_days
    ) INTO transaction_stats 
    FROM starkflare_api.get_transaction_stats() AS transaction_stats;

    -- Fetch top contracts by steps stats
    SELECT COALESCE(
        json_agg(json_build_object(
            'contract_address', contracts.contract_hash,
            'steps_number', contracts.contract_steps,
            'steps_percentage', contracts.contract_steps_percentage
        )), '[]') INTO top_contracts_by_steps
    FROM starkflare_api.get_top_contracts_by_steps() AS contracts;

    -- Fetch top transactions by steps
    SELECT COALESCE(json_agg(json_build_object(
        'tx_hash', tx.tx_hash,
        'steps_consumed', tx.steps_number,
        'tx_timestamp', tx.tx_timestamp,
        'block_number', tx.block_number
        )), '[]') INTO top_transactions
    FROM starkflare_api.get_top_transactions_by_steps() AS tx;

    -- Retrieve L1 gas stats of last 7 days
    SELECT COALESCE(
        json_agg(json_build_object(
            'date', l1_gas_stats.l1_data_gas_date,
            'l1_data_gas', l1_gas_stats.l1_data_gas_last_7_days,
            'l1_gas', l1_gas_stats.l1_gas_last_7_days
        )), '[]') INTO l1_gas_stats
    FROM starkflare_api.get_l1_gas_last_7_days() AS l1_gas_stats;

    RETURN json_build_object(
        'user_stats', user_stats,
        'transaction_stats', transaction_stats,
        'top_contracts_by_steps', top_contracts_by_steps,
        'top_transactions_by_steps', top_transactions,
        'l1_gas_stats', l1_gas_stats
    );
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission on the "get_common_data()" function to the web role
GRANT EXECUTE ON FUNCTION starkflare_api.get_common_data TO starkflare_web_anon;

COMMIT;
