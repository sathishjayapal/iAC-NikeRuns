# MSK Cluster Configuration
resource "aws_msk_cluster" "this" {
  cluster_name           = var.cluster_name
  kafka_version          = var.kafka_version
  number_of_broker_nodes = var.number_of_broker_nodes

  broker_node_group_info {
    instance_type   = var.broker_instance_type
    client_subnets  = var.subnet_ids
    security_groups = [aws_security_group.msk.id]

    storage_info {
      ebs_storage_info {
        volume_size            = var.broker_volume_size
        provisioned_throughput {
          enabled           = var.enable_provisioned_throughput
          volume_throughput = var.enable_provisioned_throughput ? var.volume_throughput : null
        }
      }
    }

    connectivity_info {
      public_access {
        type = "DISABLED"
      }
    }
  }

  encryption_info {
    encryption_in_transit {
      client_broker = var.encryption_in_transit_client_broker
      in_cluster    = var.encryption_in_transit_in_cluster
    }

    encryption_at_rest_kms_key_arn = var.kms_key_arn
  }

  configuration_info {
    arn      = aws_msk_configuration.this.arn
    revision = aws_msk_configuration.this.latest_revision
  }

  client_authentication {
    sasl {
      iam   = var.enable_iam_auth
      scram = var.enable_scram_auth
    }

    tls {
      certificate_authority_arns = var.tls_certificate_authority_arns
    }
  }

  logging_info {
    broker_logs {
      cloudwatch_logs {
        enabled   = var.enable_cloudwatch_logs
        log_group = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.msk[0].name : null
      }

      firehose {
        enabled         = var.enable_firehose_logs
        delivery_stream = var.enable_firehose_logs ? var.firehose_delivery_stream : null
      }

      s3 {
        enabled = var.enable_s3_logs
        bucket  = var.enable_s3_logs ? var.s3_logs_bucket : null
        prefix  = var.enable_s3_logs ? var.s3_logs_prefix : null
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = var.cluster_name
    }
  )
}

# MSK Configuration for topic naming conventions and other settings
resource "aws_msk_configuration" "this" {
  name              = "${var.cluster_name}-config"
  kafka_versions    = [var.kafka_version]
  server_properties = <<PROPERTIES
auto.create.topics.enable=${var.auto_create_topics_enable}
default.replication.factor=${var.default_replication_factor}
min.insync.replicas=${var.min_insync_replicas}
num.io.threads=${var.num_io_threads}
num.network.threads=${var.num_network_threads}
num.partitions=${var.num_partitions}
num.replica.fetchers=${var.num_replica_fetchers}
socket.receive.buffer.bytes=${var.socket_receive_buffer_bytes}
socket.request.max.bytes=${var.socket_request_max_bytes}
socket.send.buffer.bytes=${var.socket_send_buffer_bytes}
unclean.leader.election.enable=${var.unclean_leader_election_enable}
zookeeper.session.timeout.ms=${var.zookeeper_session_timeout_ms}
PROPERTIES

  description = "Configuration for ${var.cluster_name} with topic naming conventions enforced via IAM policies"
}

# CloudWatch Log Group for MSK logs
resource "aws_cloudwatch_log_group" "msk" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/msk/${var.cluster_name}"
  retention_in_days = var.cloudwatch_log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-logs"
    }
  )
}
