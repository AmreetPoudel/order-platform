from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import Users
from diagrams.aws.network import (
    PublicSubnet,
    PrivateSubnet,
    InternetGateway,
    NATGateway,
    ELB,
    Route53
)
from diagrams.aws.compute import Fargate
from diagrams.aws.storage import ElasticFileSystemEFS, SimpleStorageServiceS3
from diagrams.aws.security import Shield, IAMRole
from diagrams.aws.management import ParameterStore, Cloudwatch

graph_attr = {
    "fontsize": "20",
    "fontname": "Sans-Serif",
    "bgcolor": "#FAFAFA",
    "pad": "1.0",
    "splines": "curved",
    "nodesep": "0.8",
    "ranksep": "1.0",
    "concentrate": "true"
}

node_attr = {
    "fontsize": "12",
    "fontname": "Sans-Serif"
}

edge_attr = {
    "fontsize": "11",
    "fontname": "Sans-Serif"
}

with Diagram(
    name="Order Platform — Production AWS ECS Fargate Architecture (Phase 2)",
    filename="aws_order_platform_infrastructure",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr
):
    users = Users("External Web Traffic\n(HTTP 80)")
    
    with Cluster("AWS Region: ap-south-1 (Mumbai)"):
        s3_state = SimpleStorageServiceS3("S3 State Backend\n(order-platform-tf-state)")
        exec_role = IAMRole("IAM Execution Role\n(ecsTaskExecutionRole)")
        ssm_secrets = ParameterStore("SSM Parameter Store\n(/order-platform/*)")
        cw_logs = Cloudwatch("CloudWatch Log Group\n(/ecs/order-platform)")

        with Cluster("VPC: order_platform_vpc (10.0.0.0/16)"):
            igw = InternetGateway("Internet Gateway")
            alb = ELB("Application Load Balancer\n(Path Ingress)")

            with Cluster("Availability Zone: ap-south-1a"):
                with Cluster("Public Subnet A (10.0.3.0/24)"):
                    pub_sub_a = PublicSubnet("public_subnet_a")
                    nat_a = NATGateway("NAT Gateway A")
                
                with Cluster("Private Subnet A (10.0.1.0/24)"):
                    priv_sub_a = PrivateSubnet("private_subnet_a")
                    frontend_task = Fargate("Frontend Task\n(React / Port 80)")
                    api_task = Fargate("API Task\n(Node.js / Port 4000)")
                    worker_task = Fargate("Worker Task\n(Background Consumer)")

            with Cluster("Availability Zone: ap-south-1b"):
                with Cluster("Public Subnet B (10.0.4.0/24)"):
                    pub_sub_b = PublicSubnet("public_subnet_b")
                    nat_b = NATGateway("NAT Gateway B")
                
                with Cluster("Private Subnet B (10.0.2.0/24)"):
                    priv_sub_b = PrivateSubnet("private_subnet_b")
                    postgres_task = Fargate("PostgreSQL Task\n(Port 5432)")
                    redis_task = Fargate("Redis Task\n(Port 6379)")
                    rabbitmq_task = Fargate("RabbitMQ Task\n(Port 5672/15672)")

            efs = ElasticFileSystemEFS("Amazon EFS Storage\n(POSIX Access Point uid:999)")

            # Public Ingress Traffic
            users >> Edge(color="#1976D2", style="bold", label="HTTP :80") >> alb
            alb >> Edge(color="#1976D2", label="Path /*") >> frontend_task
            alb >> Edge(color="#1976D2", label="Path /api/*") >> api_task

            # Cloud Map Private Service Discovery Connections
            api_task >> Edge(color="#7B1FA2", style="dashed", label="redis.order-platform.local") >> redis_task
            api_task >> Edge(color="#7B1FA2", style="dashed", label="rabbitmq.order-platform.local") >> rabbitmq_task
            api_task >> Edge(color="#7B1FA2", style="dashed", label="postgres.order-platform.local") >> postgres_task

            # Queue & DB Pipeline
            worker_task >> Edge(color="#388E3C", style="bold", label="Consume Message") >> rabbitmq_task
            worker_task >> Edge(color="#388E3C", style="bold", label="Insert Record") >> postgres_task

            # EFS Storage Mount
            postgres_task - Edge(color="#D32F2F", style="bold", label="Mount /var/lib/postgresql/data") - efs

            # Egress NAT Connections
            pub_sub_a - Edge(color="#757575", style="dotted") - igw
            pub_sub_b - Edge(color="#757575", style="dotted") - igw
            priv_sub_a >> Edge(color="#757575", style="dotted") >> nat_a >> Edge(color="#757575", style="dotted") >> igw
            priv_sub_b >> Edge(color="#757575", style="dotted") >> nat_b >> Edge(color="#757575", style="dotted") >> igw

        # Secrets & Logging
        ssm_secrets - Edge(color="#F57C00", style="dashed", label="Secret Injection") - api_task
        ssm_secrets - Edge(color="#F57C00", style="dashed", label="Secret Injection") - postgres_task
        ssm_secrets - Edge(color="#F57C00", style="dashed", label="Secret Injection") - rabbitmq_task

        exec_role - Edge(color="#0288D1", style="dotted") - frontend_task
        exec_role - Edge(color="#0288D1", style="dotted") - api_task
        
        frontend_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs
        api_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs
        postgres_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs

print("Diagram generated successfully as 'aws_order_platform_infrastructure.png'!")