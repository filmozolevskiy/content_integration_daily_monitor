view: content_integration_daily_monitor {
  # Why (2026-08-31, FM): Daily Phoenix table has no today. 15-minute table
  # has today plus overlapping closed days. A native derived table is the
  # only way to union them with a cutoff (last closed day on the daily
  # table) so each calendar day comes from one source. No warehouse view
  # exists. ClickHouse connection is read-only, so this is not a PDT.
  derived_table: {
    sql:
      WITH cutoff AS (
        SELECT max(day_added) AS max_day
        FROM ota_phoenix_v7.raw
      )
      SELECT
        date_added,
        day_added,
        airline_code,
        gds,
        gds_account_id,
        currency,
        affiliate_id,
        num_bookings,
        total_revenue,
        revenue_issuance_rate,
        usd_cad_xr,
        extra,
        'daily' AS source_table
      FROM ota_phoenix_v7.raw
      WHERE day_added <= (SELECT max_day FROM cutoff)
        AND {% condition created_date %} date_added {% endcondition %}
        AND {% condition airline_code %} airline_code {% endcondition %}
        AND {% condition content_source %} gds {% endcondition %}
        AND {% condition gds_account_id %} gds_account_id {% endcondition %}
        AND {% condition currency %} currency {% endcondition %}
        AND {% condition affiliate_id %} affiliate_id {% endcondition %}
      UNION ALL
      SELECT
        date_added,
        day_added,
        airline_code,
        gds,
        gds_account_id,
        currency,
        affiliate_id,
        num_bookings,
        total_revenue,
        revenue_issuance_rate,
        usd_cad_xr,
        extra,
        '15min' AS source_table
      FROM ota_phoenix_v7.raw_15min
      WHERE day_added > (SELECT max_day FROM cutoff)
        AND {% condition created_date %} date_added {% endcondition %}
        AND {% condition airline_code %} airline_code {% endcondition %}
        AND {% condition content_source %} gds {% endcondition %}
        AND {% condition gds_account_id %} gds_account_id {% endcondition %}
        AND {% condition currency %} currency {% endcondition %}
        AND {% condition affiliate_id %} affiliate_id {% endcondition %}
    ;;
  }

  # Why (2026-08-31, FM): Phoenix rows are pre-aggregated. There is no
  # unique key. This explore has no joins, so sums do not fan out.

  # --- DIMENSIONS ---

  dimension_group: created {
    type: time
    timeframes: [raw, date, day_of_week, week]
    sql: toDate(${TABLE}.date_added) ;;
    convert_tz: no
    group_label: "1. DATE"
    label: "Created"
    description: "Booking / event day from date_added. Timezone is America/New_York. Matches Daily Monitor board 1609."
  }

  dimension: source_table {
    type: string
    sql: ${TABLE}.source_table ;;
    group_label: "1. DATE"
    label: "Source table"
    description: "daily = closed days from the daily Phoenix table. 15min = later days from the 15-minute table (intraday, incomplete)."
  }

  dimension: airline_code {
    type: string
    sql: ${TABLE}.airline_code ;;
    group_label: "2. BOOKING"
    label: "Airline code"
    description: "Validating carrier code on the Phoenix row."
  }

  dimension: content_source {
    type: string
    sql: ${TABLE}.gds ;;
    group_label: "2. BOOKING"
    label: "Content source"
    description: "GDS / supplier name used for the booking. Maps to the gds column."
  }

  dimension: gds_account_id {
    type: string
    sql: ${TABLE}.gds_account_id ;;
    group_label: "2. BOOKING"
    label: "Office ID of booking GDS"
    description: "Office ID after office override. Used by Office ID tiles on board 1609."
  }

  dimension: currency {
    type: string
    sql: ${TABLE}.currency ;;
    group_label: "3. ACQUISITION"
    label: "Currency"
    description: "Source currency on the Phoenix row. Board 1609 filter. Revenue measures convert to CAD."
  }

  dimension: affiliate_id {
    type: number
    sql: ${TABLE}.affiliate_id ;;
    group_label: "3. ACQUISITION"
    label: "Affiliate ID"
    description: "Affiliate identifier. Board 1609 filter."
  }

  # --- HIDDEN HELPERS ---

  dimension: num_bookings {
    type: number
    hidden: yes
    sql: ${TABLE}.num_bookings ;;
  }

  dimension: total_revenue_raw {
    type: number
    hidden: yes
    sql: ${TABLE}.total_revenue ;;
  }

  dimension: revenue_issuance_rate {
    type: number
    hidden: yes
    sql: ${TABLE}.revenue_issuance_rate ;;
  }

  dimension: usd_cad_xr {
    type: number
    hidden: yes
    sql: ${TABLE}.usd_cad_xr ;;
  }

  dimension: extra {
    type: string
    hidden: yes
    sql: ${TABLE}.extra ;;
  }

  dimension: gbp_cad_xr {
    type: number
    hidden: yes
    sql: JSONExtractFloat(${extra}, 'gbp_cad') ;;
  }

  dimension: eur_cad_xr {
    type: number
    hidden: yes
    sql: JSONExtractFloat(${extra}, 'eur_cad') ;;
  }

  # --- MEASURES ---

  measure: issuance_rate_revenue {
    type: number
    hidden: yes
    sql: IF(SUM(IF(${revenue_issuance_rate} > 0, 1, 0)) = 0, 0, SUM(${revenue_issuance_rate}) / SUM(IF(${revenue_issuance_rate} > 0, 1, 0))) ;;
  }

  measure: num_bookings_total {
    type: number
    sql: SUM(${num_bookings}) ;;
    value_format: "0"
    group_label: "4. COUNTS"
    label: "Total Bookings (#)"
    description: "Sum of num_bookings. Same formula as Daily Monitor board 1609."
  }

  measure: total_revenue {
    type: number
    sql:
      (
        SUM(
          IF(${currency} = 'USD',
            ${total_revenue_raw} * ${usd_cad_xr},
            IF(${currency} = 'GBP',
              ${total_revenue_raw} * ${gbp_cad_xr},
              IF(${currency} = 'EUR',
                ${total_revenue_raw} * ${eur_cad_xr},
                ${total_revenue_raw}
              )
            )
          )
        )
      ) * ${issuance_rate_revenue}
    ;;
    value_format: "$#,##0"
    group_label: "4. COUNTS"
    label: "Total Revenue ($)"
    description: "Total revenue converted to CAD, then multiplied by the revenue issuance rate. Same formula as Daily Monitor board 1609. Today from the 15-minute table is incomplete."
  }
}
