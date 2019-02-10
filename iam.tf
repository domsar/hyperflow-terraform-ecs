#Iam roles, profiles, policy
resource "aws_iam_role" "ecs_service" {
  name = "hyperflow-instecs-serviceance-role"
  assume_role_policy = "${file("ecs-service-role.json")}"
}

resource "aws_iam_role" "app_instance" {
  name = "hyperflow-instance-role"
  assume_role_policy = "${file("ec2-instance-role.json")}"
}

resource "aws_iam_instance_profile" "app" {
  name  = "hyperflow-instance-profile"
  role = "${aws_iam_role.app_instance.name}"
}

data "template_file" "instance_profile" {
  template = "${file("ecs-profile-policy.json")}"
}

resource "aws_iam_role_policy" "instance" {
  name   = "ECSInstanceRole"
  role   = "${aws_iam_role.app_instance.name}"
  policy = "${data.template_file.instance_profile.rendered}"
}

# Fargate is using awsvpc as networking mode,
# in this mode each task definiton gets its own private ip address.
# This network mode requires a role for the task execution.

data "aws_iam_policy_document" "ecs_tasks_execution_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_tasks_execution_role" {
  name               = "app-task-execution-role"
  assume_role_policy = "${data.aws_iam_policy_document.ecs_tasks_execution_role.json}"
}

resource "aws_iam_role_policy_attachment" "ecs_tasks_execution_role" {
  role       = "${aws_iam_role.ecs_tasks_execution_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
