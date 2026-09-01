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
        booking_id,
        original_gds_account_id,
        fare_type,
        affiliate_name,
        site_and_currency,
        target_id,
        trip_type,
        origin_continent_region_id,
        destination_continent_region_id,
        multiticket_relationship,
        departure_date,
        destination_country_code,
        origin_country_code,
        destination_airport_code,
        origin_airport_code,
        route,
        'daily' AS source_table
      FROM ota_phoenix_v7.raw
      WHERE day_added <= (SELECT max_day FROM cutoff)
        AND {% condition created_date %} date_added {% endcondition %}
        AND {% condition airline_code %} airline_code {% endcondition %}
        AND {% condition content_source %} gds {% endcondition %}
        AND {% condition gds_account_id %} gds_account_id {% endcondition %}
        AND {% condition currency %} currency {% endcondition %}
        AND {% condition affiliate_id %} affiliate_id {% endcondition %}
        AND {% condition booking_id %} booking_id {% endcondition %}
        AND {% condition original_gds_account_id %} original_gds_account_id {% endcondition %}
        AND {% condition fare_type %} fare_type {% endcondition %}
        AND {% condition affiliate_name %} affiliate_name {% endcondition %}
        AND {% condition site_and_currency %} site_and_currency {% endcondition %}
        AND {% condition target_id %} target_id {% endcondition %}
        AND {% condition trip_type %} trip_type {% endcondition %}
        AND {% condition multiticket_relationship %} multiticket_relationship {% endcondition %}
        AND {% condition departure_date %} departure_date {% endcondition %}
        AND {% condition destination_country_code %} destination_country_code {% endcondition %}
        AND {% condition origin_country_code %} origin_country_code {% endcondition %}
        AND {% condition destination_airport_code %} destination_airport_code {% endcondition %}
        AND {% condition origin_airport_code %} origin_airport_code {% endcondition %}
        AND {% condition route %} route {% endcondition %}
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
        booking_id,
        original_gds_account_id,
        fare_type,
        affiliate_name,
        site_and_currency,
        target_id,
        trip_type,
        origin_continent_region_id,
        destination_continent_region_id,
        multiticket_relationship,
        departure_date,
        destination_country_code,
        origin_country_code,
        destination_airport_code,
        origin_airport_code,
        route,
        '15min' AS source_table
      FROM ota_phoenix_v7.raw_15min
      WHERE day_added > (SELECT max_day FROM cutoff)
        AND {% condition created_date %} date_added {% endcondition %}
        AND {% condition airline_code %} airline_code {% endcondition %}
        AND {% condition content_source %} gds {% endcondition %}
        AND {% condition gds_account_id %} gds_account_id {% endcondition %}
        AND {% condition currency %} currency {% endcondition %}
        AND {% condition affiliate_id %} affiliate_id {% endcondition %}
        AND {% condition booking_id %} booking_id {% endcondition %}
        AND {% condition original_gds_account_id %} original_gds_account_id {% endcondition %}
        AND {% condition fare_type %} fare_type {% endcondition %}
        AND {% condition affiliate_name %} affiliate_name {% endcondition %}
        AND {% condition site_and_currency %} site_and_currency {% endcondition %}
        AND {% condition target_id %} target_id {% endcondition %}
        AND {% condition trip_type %} trip_type {% endcondition %}
        AND {% condition multiticket_relationship %} multiticket_relationship {% endcondition %}
        AND {% condition departure_date %} departure_date {% endcondition %}
        AND {% condition destination_country_code %} destination_country_code {% endcondition %}
        AND {% condition origin_country_code %} origin_country_code {% endcondition %}
        AND {% condition destination_airport_code %} destination_airport_code {% endcondition %}
        AND {% condition origin_airport_code %} origin_airport_code {% endcondition %}
        AND {% condition route %} route {% endcondition %}
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

  dimension_group: departure {
    type: time
    timeframes: [raw, date]
    sql: toDate(${TABLE}.departure_date) ;;
    convert_tz: no
    group_label: "1. DATE"
    label: "Departure"
    description: "First-flight departure day on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: source_table {
    type: string
    sql: ${TABLE}.source_table ;;
    group_label: "1. DATE"
    label: "Source table"
    description: "daily = closed days from the daily Phoenix table. 15min = later days from the 15-minute table (intraday, incomplete)."
  }

  dimension: booking_id {
    type: number
    sql: ${TABLE}.booking_id ;;
    group_label: "2. BOOKING"
    label: "Booking ID"
    description: "Booking identifier on the Phoenix row. Matches Daily Monitor board 1609."
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

  dimension: original_gds_account_id {
    type: string
    sql: ${TABLE}.original_gds_account_id ;;
    group_label: "2. BOOKING"
    label: "Office ID of Original GDS"
    description: "Office ID before office override. Formerly Original GDS Account ID. Matches Daily Monitor board 1609."
  }

  dimension: fare_type {
    type: string
    sql: ${TABLE}.fare_type ;;
    group_label: "2. BOOKING"
    label: "Fare Type"
    description: "The fare type (published or private) of the selected flight at search. Matches Daily Monitor board 1609."
  }

  dimension: trip_type {
    type: string
    sql: ${TABLE}.trip_type ;;
    group_label: "2. BOOKING"
    label: "Trip Type"
    description: "The type of trip they booked: one-way, round-trip or multi-city. Matches Daily Monitor board 1609."
  }

  dimension: travel_type {
    type: string
    sql:
      CASE
        WHEN ${origin_continent_region_id} = ${destination_continent_region_id} THEN 'DOMESTIC'
        WHEN ${origin_continent_region_id} IN (8, 11)
          AND ${destination_continent_region_id} IN (8, 11)
          AND ${origin_continent_region_id} <> ${destination_continent_region_id} THEN 'TRANSBORDER'
        ELSE 'INTERNATIONAL'
      END
    ;;
    group_label: "2. BOOKING"
    label: "Travel Type"
    description: "Domestic (within US or within CA) vs International (US to all but US, CA to all but CA) vs Transborder (US to CA or CA to US). Same CASE as Daily Monitor board 1609."
  }

  dimension: multiticket_relationship {
    type: string
    sql: ${TABLE}.multiticket_relationship ;;
    group_label: "2. BOOKING"
    label: "Multiticket Relationship"
    description: "Role of this row in a multi-ticket pair (master / slave), or empty when the booking is a single ticket. Matches Daily Monitor board 1609."
  }

  dimension: origin_airport_code {
    type: string
    sql: ${TABLE}.origin_airport_code ;;
    group_label: "2. BOOKING"
    label: "Origin Airport Code"
    description: "Origin airport code on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: destination_airport_code {
    type: string
    sql: ${TABLE}.destination_airport_code ;;
    group_label: "2. BOOKING"
    label: "Destination Airport Code"
    description: "Destination airport code on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: origin_country_code {
    type: string
    sql: ${TABLE}.origin_country_code ;;
    group_label: "2. BOOKING"
    label: "Origin Country Code"
    description: "Origin country code on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: destination_country_code {
    type: string
    sql: ${TABLE}.destination_country_code ;;
    group_label: "2. BOOKING"
    label: "Destination Country Code"
    description: "Destination country code on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: route {
    type: string
    sql: ${TABLE}.route ;;
    group_label: "2. BOOKING"
    label: "Route"
    description: "Origin to destination airport pair on the Phoenix row. Matches Daily Monitor board 1609."
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

  dimension: affiliate_name {
    type: string
    sql: ${TABLE}.affiliate_name ;;
    group_label: "3. ACQUISITION"
    label: "Affiliate"
    description: "Affiliate display name on the Phoenix row. Matches Daily Monitor board 1609."
  }

  dimension: affiliate_group {
    type: string
    sql:
      CASE
        WHEN ${affiliate_id} IN (16, 8, 782, 11, 506, 26, 509, 49, 508, 1042) THEN 'EXTERNAL'
        WHEN ${affiliate_id} NOT IN (40, 16, 8, 782, 11, 506, 26, 509, 49, 508, 1042) THEN 'INTERNAL'
        WHEN ${affiliate_id} IN (40) THEN 'PHONE'
      END
    ;;
    group_label: "3. ACQUISITION"
    label: "Affiliate Group"
    description: "INTERNAL = customers searching on our site. EXTERNAL = customers searching on other sites (Kayak). PHONE = affiliate ID 40. Same CASE as Daily Monitor board 1609."
  }

  dimension: site_and_currency {
    type: string
    sql: ${TABLE}.site_and_currency ;;
    group_label: "3. ACQUISITION"
    label: "Site and Currency"
    description: "Site plus currency on the Phoenix row. Site id 1 = FlightHub and 4 = JustFly. Matches Daily Monitor board 1609."
  }

  dimension: target_id {
    type: number
    sql: ${TABLE}.target_id ;;
    group_label: "3. ACQUISITION"
    label: "Target ID"
    description: "Target identifier inside the affiliate. Matches Daily Monitor board 1609."
  }

  # --- HIDDEN HELPERS ---

  dimension: origin_continent_region_id {
    type: number
    hidden: yes
    sql: ${TABLE}.origin_continent_region_id ;;
  }

  dimension: destination_continent_region_id {
    type: number
    hidden: yes
    sql: ${TABLE}.destination_continent_region_id ;;
  }

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
