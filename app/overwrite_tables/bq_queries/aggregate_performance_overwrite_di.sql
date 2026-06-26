DECLARE create_sql STRING;
DECLARE source_table STRING DEFAULT '{% if incremental == "true" %}{target_dataset}.aggregate_asset_performance_{date_iso}{% else %}{target_dataset}.aggregate_asset_performance{% endif %}';
DECLARE target_table STRING DEFAULT '{target_dataset}.aggregate_asset_performance_overwrite_di';

SET create_sql = 'CREATE OR REPLACE TABLE `' || target_table || '` AS (' ||
    'select GENERATE_UUID() as uuid, * from `' || source_table || '`' ||
    ');';

EXECUTE IMMEDIATE create_sql;