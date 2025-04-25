terraform {
  required_providers {
       aws ={
        source = "hashicorp/aws"
    }
  }
}
provider "aws" {
  region = var.region
}
// start with Network configuration for cluster and cicd vm
resource "aws_vpc" "eks_vpc" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
  tags = {
    Name="My-cluster-vpc"
  }
}

resource "aws_subnet" "private_subnet1" {
vpc_id = aws_vpc.eks_vpc.id
cidr_block = "10.0.1.0/24"
availability_zone = "us-east-2a"
tags = {
  Name="private-subnet1"
}
}
resource "aws_subnet" "private_subnet2" {
vpc_id = aws_vpc.eks_vpc.id
cidr_block = "10.0.2.0/24"
availability_zone = "us-east-2b"
tags = {
  Name="private-subnet2"
}
}
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.eks_vpc.id
  cidr_block = "10.0.3.0/24"
  availability_zone = "us-east-2a"
  map_public_ip_on_launch = true
  tags = {
    Name="puplic-subnet"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name="eks-igw"
  }
}
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnet.id
  depends_on    = [aws_internet_gateway.igw]
}


resource "aws_route_table" "private-rt" {
  vpc_id = aws_vpc.eks_vpc.id
    route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name="eks-prt"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-rt"
  }
}
resource "aws_route_table_association" "private_1" {
  subnet_id = aws_subnet.private_subnet1.id
  route_table_id = aws_route_table.private-rt.id
}
resource "aws_route_table_association" "private_2" {
  subnet_id = aws_subnet.private_subnet2.id
  route_table_id = aws_route_table.private-rt.id
}
resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}


// create eks cluster
resource "aws_eks_cluster" "my_cluster" {
  name = "my-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  vpc_config {
    subnet_ids = [ 
      aws_subnet.private_subnet1.id,
      aws_subnet.private_subnet2.id
    ]
    security_group_ids = [ aws_security_group.eks_sg.id ]
    endpoint_private_access = true
    endpoint_public_access = false
  }
  
  depends_on = [ 
    aws_iam_role_policy_attachment.eks_cluster_policy
   ]
}

resource "aws_iam_role" "eks_cluster_role" {
  name = var.Eks_cluster_name
   assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}
resource "aws_iam_instance_profile" "nodes" {
  name = "eks-node-profile"
  role = aws_iam_role.eks_nodes.name
}


resource "aws_security_group" "eks_sg" {
  name        = "eks-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = aws_vpc.eks_vpc.id
   ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }
   ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"] 
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "kubernetes.io/cluster/my-eks-cluster" = "owned"
  }
}
resource "aws_eks_node_group" "nodes" {
  cluster_name = aws_eks_cluster.my_cluster.name
  node_group_name = "private-nodes"
  node_role_arn = aws_iam_role.eks_nodes.arn
  subnet_ids = [aws_subnet.private_subnet1.id,aws_subnet.private_subnet2.id]
  
  scaling_config {
    desired_size = 2 
    max_size = 2 
    min_size = 2
  }
  ami_type       = "AL2_x86_64"
  instance_types = ["t3.medium"]
  disk_size      = 20
  tags = {
    Name="eks_worker_nodes"
  }
   depends_on = [
    aws_iam_role_policy_attachment.nodes_AmazonEC2ContainerRegistryReadOnly,
    aws_iam_role_policy_attachment.nodes_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.nodes_AmazonEKSWorkerNodePolicy
  ]
}
resource "aws_iam_role" "eks_nodes" {
  name = "my-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "nodes_AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

// start create cicd vm 
resource "aws_security_group" "cicd-sg" {
  name = "cicd-security-group"
  vpc_id = aws_vpc.eks_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  
  }
  egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

  tags = {
    Name = "cicd-sg"
  }
  
}

resource "aws_key_pair" "my_key" {   
  key_name   = var.ssh_key_name 
  public_key = file("~/.ssh/my-key.pub") 
}
//
resource "aws_iam_policy" "jenkins_eks_access" {
  name        = "JenkinsEKSAccessPolicy"
  description = "Policy for Jenkins on EC2 to access EKS cluster"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sts:GetCallerIdentity"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}
resource "aws_iam_role" "jenkins_ec2_role" {
  name = "JenkinsEC2Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "jenkins_attach" {
  role       = aws_iam_role.jenkins_ec2_role.name
  policy_arn = aws_iam_policy.jenkins_eks_access.arn
}
resource "aws_iam_role_policy_attachment" "jenkins_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  role       = aws_iam_role.jenkins_ec2_role.name
}
resource "aws_iam_instance_profile" "jenkins_instance_profile" {
  name = "JenkinsInstanceProfile"
  role = aws_iam_role.jenkins_ec2_role.name
}
//

resource "aws_instance" "CICD" {
  ami = var.ami_id
  instance_type = var.ec2_instance_type
  subnet_id = aws_subnet.public_subnet.id
  vpc_security_group_ids = [ aws_security_group.cicd-sg.id ]
  key_name = var.ssh_key_name
  iam_instance_profile = aws_iam_instance_profile.jenkins_instance_profile.name
   provisioner "local-exec" {
    command = "chmod +x /home/omar/Complete-DevOps-Pipeline/infra/scripts/config_cicd.sh && /home/omar/Complete-DevOps-Pipeline/infra/scripts/config_cicd.sh"
    
    environment = {
      TF_VAR_cicd_public_ip = self.public_ip
      TF_VAR_ssh_key_path   = var.ssh_key_path
    }
  }

  tags = {
    Name="jenkins-cicd-machine"
  }
}