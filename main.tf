terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    # Add the time provider to manage the delay
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

# A single, default provider for the central monitoring workspace project.
provider "google" {
  project = "monitoring-project"
  region  = "us-central1"
}

locals {
  monitoring_project_id = "monitoring-project"
  monitored_projects = [
    "monitored-project",
    
  ]
}

# This resource adds all projects from the list to your central monitoring workspace.
resource "google_monitoring_monitored_project" "all_monitored_projects" {
  for_each      = toset(local.monitored_projects)
  metrics_scope = "locations/global/metricsScopes/${local.monitoring_project_id}"
  name          = each.key
}

# A single notification channel for all alerts to use.
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "Ops Team Email"
  type         = "email"
  labels = {
    email_address = "your-email-address-here"
  }
}

# ===================================================================
# DELAY TO ALLOW FOR METRICS SCOPE PROPAGATION
# This resource pauses execution to ensure Google's backend has time
# to recognize the newly monitored projects before we create alerts.
# ===================================================================
resource "time_sleep" "wait_for_monitoring_propagation" {
  create_duration = "60s"

  # This depends_on block is crucial. It ensures the timer only starts
  # AFTER all projects have been successfully added to the metrics scope.
  depends_on = [google_monitoring_monitored_project.all_monitored_projects]
}

# ===================================================================
# ALERT POLICY FOR CPU UTILIZATION
# ===================================================================
resource "google_monitoring_alert_policy" "cpu_alert_all_monitored_projects" {
  for_each              = toset(local.monitored_projects)
  display_name          = "CPU Alert - Project ${each.key}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email_channel.name]
  enabled               = true

  # This depends_on ensures that this alert policy will not be created
  # until the 60-second delay is complete.
  depends_on = [time_sleep.wait_for_monitoring_propagation]

  conditions {
    display_name = "CPU Usage > 80% - Project ${each.key}"
    condition_threshold {
      filter          = "project = \"${each.key}\" AND resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8
      duration        = "300s"
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}

# ===================================================================
# ALERT POLICY FOR DISK UTILIZATION
# ===================================================================
resource "google_monitoring_alert_policy" "disk_alert_all_monitored_projects" {
  for_each              = toset(local.monitored_projects)
  display_name          = "Disk Utilization Alert - Project ${each.key}"
  combiner              = "OR"
  notification_channels = [google_monitoring_notification_channel.email_channel.name]
  enabled               = true

  # This depends_on ensures that this alert policy will not be created
  # until the 60-second delay is complete.
  depends_on = [time_sleep.wait_for_monitoring_propagation]

  conditions {
    display_name = "Disk space used over 80% on a device"
    condition_threshold {
      filter = "project = \"${each.key}\" AND resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/disk/percent_used\" AND metric.label.state = \"used\""
      duration        = "900s"
      comparison      = "COMPARISON_GT"
      threshold_value = 80
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
        group_by_fields    = ["metric.labels.device"]
      }
    }
  }

  documentation {
    mime_type = "text/markdown"
    content = <<-EOT
    ### Alert: Low Disk Space Detected
    **Summary:** A disk on an instance has exceeded the 80% usage threshold.
    **Project ID:** `$${resource.label.project_id}`
    **Instance ID:** `$${resource.label.instance_id}`
    ---
    **Affected Disk/Device:** `$${metric.label.device}`
    ---
    Please investigate and take action to free up disk space on the specified device.
    EOT
  }
}
