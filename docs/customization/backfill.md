## Backfill performance data

If already set up a solution and want your performance tables (`asset_performance`,
`asset_converion_split`, `ad_group_network_split`, `ios_skan_decoder`,
`geo_performance`) to contains historical data from a certain date in the past,
please do the following:

* In `app_reporting_pack.yaml` under `gaarf > params > macro`
add `initial_load_date: 'YYYY-MM-DD'`, where `YYYY-MM-DD` is the first date
you want to have performance data loaded.

```yaml
gaarf:
  params:
    macro:
      initial_load_date: '2022-01-01'
      start_date: :YYYYMMDD-30
      end_date: :YYYYMMDD-1
```

