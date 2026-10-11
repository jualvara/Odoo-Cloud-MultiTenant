resource "google_monitoring_uptime_check_config" "odoo" {
  for_each = var.uptime_hosts

  display_name       = "Odoo ${each.key} público"
  timeout            = "10s"
  period             = "60s"
  checker_type       = "STATIC_IP_CHECKERS"
  log_check_failures = true

  http_check {
    path         = "/web/health"
    port         = 80
    use_ssl      = false
    validate_ssl = false
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = each.value
    }
  }

  depends_on = [google_project_service.required["monitoring.googleapis.com"]]
}

resource "google_monitoring_alert_policy" "odoo_uptime" {
  for_each = google_monitoring_uptime_check_config.odoo

  display_name          = "Odoo ${each.key}: sin disponibilidad pública"
  combiner              = "OR"
  notification_channels = var.alert_notification_channel_ids

  conditions {
    display_name = "La comprobación pública de ${each.key} falla"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.\"check_id\"=\"${each.value.uptime_check_id}\""
      duration        = "120s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_NEXT_OLDER"
      }
    }
  }

  alert_strategy {
    auto_close = "1800s"
  }

  depends_on = [google_project_service.required["monitoring.googleapis.com"]]
}
