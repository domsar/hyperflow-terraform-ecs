#Definitions of Services and Tasks

data "template_file" "task_definition_hyperflow_worker" {
  template = "${file("${path.module}/task-hyperflow-worker.json")}"
  vars {
    image_url        = "${var.hyperflow_worker_container}"
    container_name   = "hyperflow-worker"
    master_ip        = "${aws_instance.hyperflowmaster.public_dns}"
    rabbitmq_port    = "${var.server_port}"
    acess_key        = "${var.ACCESS_KEY}"
    secret_key       = "${var.SECRET_ACCESS_KEY}"
    influxdb_url     = "${var.influx_db_url}"
    feature_download = "${var.feature_download}"
    nfs_mount        = "${var.nfs_mount}"
  }
}

resource "aws_ecs_task_definition" "task_hyperflow_worker" {
  family                = "task_definition_hyperflow_worker"
  container_definitions = "${data.template_file.task_definition_hyperflow_worker.rendered}"


  volume {
    name      = "tmp-storage"
    host_path = "/tmp"
  }
  volume {
    name      = "docker-socket"
    host_path = "/var/run/docker.sock"
  }


  depends_on = [
    "data.template_file.task_definition_hyperflow_worker",
  ]
}

resource "aws_ecs_service" "hyperflow-service-worker" {
  name               = "hyperflow-service-worker"
  cluster            = "${aws_ecs_cluster.hyperflow_cluster.id}"
  task_definition    = "${aws_ecs_task_definition.task_hyperflow_worker.arn}"
  desired_count      = "${var.aws_ecs_service_worker_desired_count}"

  depends_on = [
    "aws_iam_role.ecs_service",
    "aws_ecs_service.hyperflow-service-master",
  ]
}

# FARGATE

data "template_file" "task_definition_hyperflow_app" {
  template = "${file("${path.module}/task-hyperflow-app.json")}"
  vars {
    image_url = "${var.hyperflow_app_container}"
    container_name = "hyperflow-app"
    host_port         = "${var.app_port}"
    container_port    = "${var.app_port}"
  }
}

# The following settings are required for a task that will run in Fargate:
#   requires_compatibilities,
#   network_mode,
#   cpu,
#   memory.

resource "aws_ecs_task_definition" "task_hyperflow_app" {
  family                   = "task_definition_hyperflow_app"
  container_definitions    = "${data.template_file.task_definition_hyperflow_app.rendered}"
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = "${aws_iam_role.ecs_tasks_execution_role.arn}"
}

resource "aws_ecs_service" "hyperflow-service-app" {
  name            = "hyperflow-service-app"
  cluster         = "${aws_ecs_cluster.hyperflow_cluster.id}"
  task_definition = "${aws_ecs_task_definition.task_hyperflow_app.arn}"
  desired_count   = "${var.aws_ecs_service_app_desired_count}"

  load_balancer = {
    target_group_arn = "${aws_alb_target_group.main.arn}"
    container_name   = "hyperflow-service-app"
    container_port   = "${var.app_port}"
  }

  launch_type = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.awsvpc_sg.id}"]
    subnets         = ["${module.vpc.private_subnets}"]
  }

  depends_on = ["aws_alb_listener.main"]
}

# FARGATE

data "template_file" "task_definition_hyperflow_master" {
  template = "${file("${path.module}/task-hyperflow-master.json")}"

  vars {
    image_url         = "${var.hyperflow_master_container}"
    container_name    = "hyperflow-master"
    host_port         = "${var.server_port}"
    container_port    = "${var.server_port}"
    influx_db_url = "${var.influx_db_url}"
    acess_key         = "${var.ACCESS_KEY}"
    secret_key        = "${var.SECRET_ACCESS_KEY}"
    rabbitmq_managment_port = "${var.server_plugin_port}"
  }
}

resource "aws_ecs_task_definition" "task_hyperflow_master" {
  family                = "task_definition_hyperflow_master"
  container_definitions = "${data.template_file.task_definition_hyperflow_master.rendered}"
  depends_on = [
    "data.template_file.task_definition_hyperflow_master",
  ]
}

resource "aws_ecs_service" "hyperflow-service-master" {
  name               = "hyperflow-service-master"
  cluster            = "${aws_ecs_cluster.hyperflow_cluster.id}"
  task_definition    = "${aws_ecs_task_definition.task_hyperflow_master.arn}"
  desired_count      = "${var.master_count}"
  depends_on = [
    "aws_iam_role.ecs_service",
  ]
}
