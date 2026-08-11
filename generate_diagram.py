from diagrams import Cluster, Diagram
from diagrams.aws.network import (
    PublicSubnet, PrivateSubnet, InternetGateway, NATGateway, ELB
)
from diagrams.aws.security import Shield
from diagrams.aws.storage import SimpleStorageServiceS3
from diagrams.aws.general import Users

graph_attr = {
    "fontsize": "16",
    "fontname": "Sans-Serif",
    "bgcolor": "#FFFFFF",
    "pad": "0.5"
}

with Diagram(
    name="Order Platform — AWS Multi-AZ Infrastructure Architecture",
    filename="aws_order_platform_infrastructure",
    show=True,
    direction="TB",
    graph_attr=graph_attr
):
    users = Users("Users / Clients")
    s3_state = SimpleStorageServiceS3("S3 State Backend\n(Native S3 Lockfile)")

    with Cluster("AWS Region: ap-south-1 (Mumbai)"):
        with Cluster("VPC: order_platform_vpc (10.0.0.0/16)"):
            igw = InternetGateway("Internet Gateway\n(order_platform_igw)")
            
            alb_sg = Shield("Security Group\n(order_platform_alb_sg)\nHTTP 80 / HTTPS 443")
            alb = ELB("Application Load Balancer\n(order-platform-alb)")
            
            alb_sg - alb

            with Cluster("Availability Zone: ap-south-1a"):
                with Cluster("Public Subnet A (10.0.3.0/24)"):
                    pub_sub_a = PublicSubnet("Public Subnet A")
                    nat_a = NATGateway("NAT Gateway A\n+ Elastic IP A")
                
                with Cluster("Private Subnet A (10.0.1.0/24)"):
                    priv_sub_a = PrivateSubnet("Private Subnet A")

            with Cluster("Availability Zone: ap-south-1b"):
                with Cluster("Public Subnet B (10.0.4.0/24)"):
                    pub_sub_b = PublicSubnet("Public Subnet B")
                    nat_b = NATGateway("NAT Gateway B\n+ Elastic IP B")
                
                with Cluster("Private Subnet B (10.0.2.0/24)"):
                    priv_sub_b = PrivateSubnet("Private Subnet B")

            # Traffic Connections
            users >> alb
            alb >> pub_sub_a
            alb >> pub_sub_b
            
            pub_sub_a >> igw
            pub_sub_b >> igw

            nat_a >> igw
            nat_b >> igw
            
            priv_sub_a >> nat_a
            priv_sub_b >> nat_b
