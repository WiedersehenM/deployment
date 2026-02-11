locals {
  service_accounts = var.service_accounts
}

resource "google_service_account" "this" {
  for_each = local.service_accounts

  account_id   = "${var.app_name}-${each.key}"
  display_name = coalesce(try(each.value.display_name, null), each.key)
  description  = try(each.value.description, null)
}

resource "google_project_iam_member" "sa_roles" {
  for_each = {
    for pair in flatten([
      for sa_key, sa_cfg in local.service_accounts : [
        for role in try(sa_cfg.roles, []) : {
          key  = "${sa_key}:${role}"
          sa   = sa_key
          role = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.this[each.value.sa].email}"
}

resource "google_service_account_iam_member" "workload_identity" {
  for_each = {
    for pair in flatten([
      for sa_key, sa_cfg in local.service_accounts : [
        for b in try(sa_cfg.wi_bindings, []) : {
          key       = "${sa_key}:${b.namespace}:${b.k8s_service_account_name}"
          sa        = sa_key
          namespace = b.namespace
          ksa       = b.k8s_service_account_name
        }
      ]
    ]) : pair.key => pair
  }

  service_account_id = google_service_account.this[each.value.sa].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${each.value.namespace}/${each.value.ksa}]"
}

