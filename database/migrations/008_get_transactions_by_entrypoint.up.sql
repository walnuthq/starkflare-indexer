BEGIN;

CREATE OR REPLACE FUNCTION starkflare_api.get_transactions_by_entrypoint_table(
  contract_address VARCHAR(66),
  entrypoint_selector VARCHAR(66)
)
RETURNS TABLE (
    tx_hash VARCHAR(66),
    steps_number INTEGER,
    tx_timestamp INTEGER
) AS $$
#variable_conflict use_variable
BEGIN
    RETURN QUERY
    SELECT
      starkflare_api.account_calls.tx_hash,
      starkflare_api.account_calls.steps_number,
      starkflare_api.account_calls.timestamp
    FROM starkflare_api.account_calls
    WHERE starkflare_api.account_calls.contract_address = contract_address
      AND starkflare_api.account_calls.entrypoint_selector = entrypoint_selector
    ORDER BY steps_number DESC;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION starkflare_api.get_transactions_by_entrypoint(
  contract_address VARCHAR(66),
  entrypoint_selector VARCHAR(66)
)
RETURNS JSON
AS $$
DECLARE
    transactions_by_entrypoint JSON;
BEGIN
    -- Fetch transactions by contract address and entrypoint
    SELECT json_agg(
        json_build_object(
            'tx_hash', transactions_by_entrypoint_table.tx_hash,
            'steps_number', transactions_by_entrypoint_table.steps_number,
            'timestamp', transactions_by_entrypoint_table.tx_timestamp
        )
    ) INTO transactions_by_entrypoint
    FROM starkflare_api.get_transactions_by_entrypoint_table(
      contract_address,
      entrypoint_selector
    ) AS transactions_by_entrypoint_table;

    RETURN json_build_object('transactions', COALESCE(transactions_by_entrypoint, '[]'::json));
END;
$$ LANGUAGE plpgsql;

grant execute on function starkflare_api.get_transactions_by_entrypoint to starkflare_web_anon;

COMMIT;
