terraform {
  required_version = ">= 1.7.0" # import blocks with for_each

  # State lives in the same Cloudflare R2 bucket as infra/warp-pi-access,
  # under its own key — separate state, same bucket. See that project's
  # main.tf for why R2 (not GCS) and how backend credentials are supplied
  # (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars, never a file).
  backend "s3" {
    bucket = "beyondthefirewall-tfstate"
    key    = "cloudflare/terraform.tfstate"
    region = "auto"

    endpoints = {
      s3 = "https://2314a9913a2e9dadad8bb6d1625aa17b.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
