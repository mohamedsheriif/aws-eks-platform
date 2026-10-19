locals {
  subnets_with_nacl = {
    for name, config in var.subnets : name => config if config.create_nacl
  }

  vpc_igw = {
    for name, config in var.vpc : name => config if config.create_igw
  }

  subnet_routing_map = merge([
    for rt_key, rt_config in var.route_tables : {
      for subnet_key in rt_config.subnet_keys :
      "${rt_key}-${subnet_key}" => {
        route_table_key = rt_key
        subnet_key      = subnet_key
      }
    }
  ]...)
}
