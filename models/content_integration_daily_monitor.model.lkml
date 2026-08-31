connection: "ota_phoenix"

include: "/views/**/*.view.lkml"

datagroup: daily_monitor_default {
  sql_trigger: SELECT toDate(max(date_added)) FROM ota_phoenix_v7.raw_15min ;;
  max_cache_age: "15 minutes"
}

explore: content_integration_daily_monitor {
  label: "Daily Monitor (live)"
  persist_with: daily_monitor_default

  always_filter: {
    filters: [content_integration_daily_monitor.created_date: "14 days"]
  }
}
