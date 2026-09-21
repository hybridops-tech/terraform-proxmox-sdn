# tests/naming_validation.tftest.hcl
#
# Covers PR review feedback: valid ID, excessive length, dash/underscore,
# leading digit, one-character ID, and confirms that subnet keys (a local
# Terraform map key, not a Proxmox object ID) remain unrestricted.

provider "proxmox" {
  endpoint  = var.proxmox_url
  api_token = var.proxmox_token
  insecure  = true
}

variables {
  proxmox_node            = "test-node"
  proxmox_host            = "10.0.0.1"
  proxmox_url             = "https://10.0.0.1:8006/api2/json"
  proxmox_token           = "user@pam!test=dummy"
  dhcp_default_start_host = 120
  dhcp_default_end_host   = 220

  # Baseline valid vnets, reused across zone_name-focused runs.
  vnets = {
    vnetmgmt = {
      vlan_id     = 10
      description = "test"
      subnets = {
        subnet_name = {
          cidr    = "10.10.0.0/24"
          gateway = "10.10.0.1"
        }
      }
    }
  }
}

# ---- zone_name ----

run "zone_name_valid" {
  command = plan
  variables {
    zone_name = "hybzone"
  }
}

run "zone_name_too_long" {
  command = plan
  variables {
    zone_name = "hybzonelong" # 11 chars
  }
  expect_failures = [var.zone_name]
}

run "zone_name_dash" {
  command = plan
  variables {
    zone_name = "hyb-zone"
  }
  expect_failures = [var.zone_name]
}

run "zone_name_underscore" {
  command = plan
  variables {
    zone_name = "hyb_zone"
  }
  expect_failures = [var.zone_name]
}

run "zone_name_leading_digit" {
  command = plan
  variables {
    zone_name = "1hybzon"
  }
  expect_failures = [var.zone_name]
}

run "zone_name_one_char" {
  command = plan
  variables {
    zone_name = "h"
  }
  expect_failures = [var.zone_name]
}

# ---- vnets (VNet keys) ----

run "vnet_key_valid" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
}

run "vnet_key_too_long" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      vnetmgmttoolong = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
  expect_failures = [var.vnets]
}

run "vnet_key_dash" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      "vnet-1" = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
  expect_failures = [var.vnets]
}

run "vnet_key_underscore" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      "vnet_1" = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
  expect_failures = [var.vnets]
}

run "vnet_key_leading_digit" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      "1vnet" = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
  expect_failures = [var.vnets]
}

run "vnet_key_one_char" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      "v" = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
  expect_failures = [var.vnets]
}

# ---- subnet keys: local map keys, NOT Proxmox object IDs ----
# Must remain unrestricted.

run "subnet_key_underscore_is_allowed" {
  command = plan
  variables {
    zone_name = "hybzone"
    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = "test"
        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

}

run "vlan_id_min_valid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 1
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
}

run "vlan_id_max_valid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 4094
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
}

run "vlan_id_zero_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 0
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

run "vlan_id_above_max_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 4095
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

run "vlan_id_fractional_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10.5
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

run "vlan_id_negative_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = -1
        description = "test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

# ---- vnet description (applied as the Proxmox VNet alias) ----

run "vnet_description_allowed_characters_valid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = "Lab (dev)_1.0 - test"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
}

run "vnet_description_max_length_valid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = join("", [for i in range(256) : "a"])

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }
}

run "vnet_description_unsupported_character_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = "Validation/testing network"

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

run "vnet_description_too_long_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = join("", [for i in range(257) : "a"])

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}

run "vnet_description_empty_invalid" {
  command = plan

  variables {
    zone_name = "hybzone"

    vnets = {
      vnetmgmt = {
        vlan_id     = 10
        description = ""

        subnets = {
          subnet_name = {
            cidr    = "10.10.0.0/24"
            gateway = "10.10.0.1"
          }
        }
      }
    }
  }

  expect_failures = [var.vnets]
}
