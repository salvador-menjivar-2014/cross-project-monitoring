

# Cross-Project Google Cloud Monitoring and Alerting


-----

## Introduction

This Terraform configuration sets up a centralized Google Cloud Monitoring workspace. It automates the process of adding multiple GCP projects to a single metrics scope and deploys standardized alert policies for CPU and disk utilization across all monitored projects.

-----

## Features

  - **Centralized Monitoring**: Consolidates monitoring for multiple GCP projects into a single "monitoring-project".
  - **Automated Project Onboarding**: Easily add new projects to the monitoring scope by updating a list.
  - **Standardized Alerting**: Automatically creates alert policies for common issues across all projects:
      - High CPU Utilization (\> 80%)
      - High Disk Space Usage (\> 80%)
  - **Email Notifications**: Configures a single email notification channel for all alerts.
  - **Propagation Delay**: Includes a built-in delay using the `time_sleep` resource to prevent race conditions by ensuring the metrics scope is updated before alert policies are created.
  - **Rich Alert Content**: Provides detailed, formatted markdown content within the disk alert notification for faster troubleshooting.

-----

## Prerequisites

Before you begin, ensure you have the following:

  - **Terraform** installed (version 1.0 or later).
  - **Google Cloud SDK (`gcloud`)** installed and authenticated.
  - **Permissions**: The credentials used by Terraform must have the necessary IAM permissions (e.g., `roles/monitoring.admin`) in both the central `monitoring-project` and all `monitored_projects`.

-----

## Installation and Usage

1.  **Clone the Repository**:

    ```sh
    git clone <your-repository-url>
    cd <your-repository-directory>
    ```

2.  **Configure Projects**:
    Update the `main.tf` file with your specific project IDs and email address. See the [Configuration](https://www.google.com/search?q=%23configuration) section below for details.

3.  **Initialize Terraform**:
    This command downloads the required providers (Google Cloud and Time).

    ```sh
    terraform init
    ```

4.  **Plan the Deployment**:
    Review the changes Terraform will make to your infrastructure.

    ```sh
    terraform plan
    ```

5.  **Apply the Configuration**:
    Execute the plan to create the Google Cloud resources.

    ```sh
    terraform apply
    ```

-----

## Configuration

You must modify the following resources and variables in the `main.tf` file to match your environment.

### 1\. Provider and Monitoring Project

Set the `project` argument in the `google` provider and the `monitoring_project_id` in the `locals` block to your central monitoring project's ID.

```terraform
provider "google" {
  project = "your-central-monitoring-project" # <-- UPDATE THIS
  region  = "us-central1"
}

locals {
  monitoring_project_id = "your-central-monitoring-project" # <-- UPDATE THIS
  monitored_projects = [
    # ...
  ]
}
```

### 2\. Monitored Projects

Add the project IDs you wish to monitor to the `monitored_projects` list within the `locals` block.

```terraform
locals {
  # ...
  monitored_projects = [
    "gcp-project-alpha", # <-- ADD YOUR PROJECTS HERE
    "gcp-project-beta",
    "gcp-project-gamma"
  ]
}
```

### 3\. Notification Channel

Update the `email_address` label in the `google_monitoring_notification_channel` resource to the email address where alerts should be sent.

```terraform
resource "google_monitoring_notification_channel" "email_channel" {
  display_name = "Ops Team Email"
  type         = "email"
  labels = {
    email_address = "your-ops-team@example.com" # <-- UPDATE THIS
  }
}
```

-----


## License

This project is licensed under the [MIT License](https://www.google.com/search?q=LICENSE). Please include your own `LICENSE` file.
