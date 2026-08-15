"""
generate_diagram.py
Generates the architecture diagram for the Order Platform hybrid deployment:
- Stateless Layer: AWS ECS Fargate (Frontend, API, Worker)
- Stateful Layer: AWS EC2 Instance in Private Subnet (PostgreSQL, Redis, RabbitMQ)
- Public Ingress: Application Load Balancer with Path-Based Routing
"""

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.general import Users
from diagrams.aws.network import (
    PublicSubnet,
    PrivateSubnet,
    InternetGateway,
    NATGateway,
    ELB,
)
from diagrams.aws.compute import Fargate, EC2
from diagrams.aws.storage import EBS, SimpleStorageServiceS3
from diagrams.aws.security import IAMRole
from diagrams.aws.management import ParameterStore, Cloudwatch
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.inmemory import Redis
from diagrams.onprem.queue import Rabbitmq
from diagrams.onprem.container import Docker

graph_attr = {
    "fontsize": "24",
    "fontname": "Helvetica Neue",
    "bgcolor": "#FAFAFA",
    "pad": "0.8",
    "splines": "spline",
    "nodesep": "0.7",
    "ranksep": "0.9",
    "concentrate": "false"
}

node_attr = {
    "fontsize": "11",
    "fontname": "Helvetica Neue",
    "fontcolor": "#212121"
}

edge_attr = {
    "fontsize": "10",
    "fontname": "Helvetica Neue",
    "fontcolor": "#37474F"
}

with Diagram(
    name="Order Platform — Hybrid Cloud Architecture\n(ECS Fargate Stateless + EC2 Stateful)",
    filename="order_platform_architecture",
    show=False,
    direction="TB",
    graph_attr=graph_attr,
    node_attr=node_attr,
    edge_attr=edge_attr
):
    users = Users("Internet Users\n(Web Browser)")

    with Cluster("AWS Cloud (Region: ap-south-1 Mumbai)"):
        # Management Services
        with Cluster("Platform Services & Management"):
            s3_state = SimpleStorageServiceS3("S3 State Backend\n(Remote State)")
            exec_role = IAMRole("IAM Execution Role\n(Secrets & Logs Access)")
            ssm_secrets = ParameterStore("SSM Parameter Store\n(/order-platform/*)")
            cw_logs = Cloudwatch("CloudWatch Logs\n(/ecs/order-platform-*)")

        with Cluster("VPC: order_platform_vpc (10.0.0.0/16)"):
            igw = InternetGateway("Internet Gateway")

            # Public Subnets (Dual-AZ for High Availability ALB)
            with Cluster("Public Subnets (Dual-AZ)"):
                with Cluster("Public Subnet A (10.0.3.0/24)"):
                    nat_a = NATGateway("NAT Gateway A")
                with Cluster("Public Subnet B (10.0.4.0/24)"):
                    nat_b = NATGateway("NAT Gateway B")
                
                alb = ELB("Application Load Balancer\n(Public Port 80)")

            # Private Subnet Layer
            with Cluster("Private Subnets (Isolated Egress via NAT)"):

                # Stateless Compute on ECS Fargate
                with Cluster("Stateless Application Tier (AWS ECS Fargate)"):
                    frontend_task = Fargate("Frontend Task\n(React UI / Port 80)")
                    api_task = Fargate("API Backend Task\n(Express / Port 4000)")
                    worker_task = Fargate("Worker Task\n(Queue Consumer)")

                # Stateful Compute on EC2
                with Cluster("Stateful Data Tier (EC2 in Private Subnet)"):
                    with Cluster("Docker Compose Services (EC2 Host: 10.0.1.X)"):
                        docker_host = Docker("Docker Engine")
                        postgres = PostgreSQL("PostgreSQL\n(Port 5432)")
                        redis = Redis("Redis Cache\n(Port 6379)")
                        rabbitmq = Rabbitmq("RabbitMQ Broker\n(Port 5672)")
                    
                    ebs_disk = EBS("Persistent EBS Disk\n(gp3 / 20 GB)")

            # ------------------------------------------------------------------
            # Data & Traffic Flow Connections
            # ------------------------------------------------------------------

            # 1. Public Ingress Traffic
            users >> Edge(color="#1E88E5", style="bold", label="HTTP :80") >> igw >> alb
            alb >> Edge(color="#1E88E5", style="bold", label="Path: /*") >> frontend_task
            alb >> Edge(color="#00897B", style="bold", label="Path: /api/*, /health") >> api_task

            # 2. API queries to Stateful EC2
            api_task >> Edge(color="#8E24AA", style="dashed", label="Cache Check (:6379)") >> redis
            api_task >> Edge(color="#8E24AA", style="dashed", label="Read Miss / Query (:5432)") >> postgres
            api_task >> Edge(color="#E65100", style="bold", label="Publish Post (:5672)") >> rabbitmq

            # 3. Worker queue consumer pipeline
            rabbitmq >> Edge(color="#2E7D32", style="bold", label="Consume Message") >> worker_task
            worker_task >> Edge(color="#2E7D32", style="bold", label="Insert Record (:5432)") >> postgres
            worker_task >> Edge(color="#2E7D32", style="dashed", label="Invalidate Cache (:6379)") >> redis

            # 4. Storage Persistence on EC2
            postgres - Edge(color="#D81B60", style="bold", label="Data Volume") - ebs_disk

            # 5. Outbound Internet via NAT for Image Pulls & Package Updates
            nat_a >> igw
            nat_b >> igw

        # 6. IAM, Secrets, and Monitoring
        ssm_secrets >> Edge(color="#FB8C00", style="dotted", label="Inject PGPASSWORD & RABBITMQ_*") >> api_task
        ssm_secrets >> Edge(color="#FB8C00", style="dotted") >> worker_task
        exec_role >> Edge(color="#546E7A", style="dotted") >> frontend_task
        exec_role >> Edge(color="#546E7A", style="dotted") >> api_task
        
        frontend_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs
        api_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs
        worker_task >> Edge(color="#9E9E9E", style="dotted") >> cw_logs

print("Architecture diagram generated successfully as 'order_platform_architecture.png'!")