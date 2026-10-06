terraform {
  required_version = ">= 1.7.0" # import blocks with for_each

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }

  # TODO: add a remote backend before applying (state holds the full config).
}

# Token is read from the CLOUDFLARE_API_TOKEN environment variable.
provider "cloudflare" {}
