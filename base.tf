#################################################################

# variables

#################################################################

variable "aws_access_key" {
	}
variable "aws_secret_key" {
	}
variable "aws_region" {
	}

variable "key_name" {
	default = "project"
} 

variable "network_address_space" {
	default = "10.1.0.0/16"
}

variable "subnet1_address_space" {
	default = "10.1.0.0/24"
}

variable "subnet2_address_space" {
	default = "10.1.1.0/24"
}


variable "environment_tag" {}
variable "bucket_name" {}

    





#################################################################

# providers

#################################################################

provider "aws" {
	 
	 access_key = "${var.aws_access_key}"
	 secret_key = "${var.aws_secret_key}"
	 region     = "${var.aws_region}"
}


#################################################################

# data

#################################################################

data "aws_availability_zones" "available" {}



#################################################################

# resources

#################################################################

# NETWORKING #
 
resource "aws_vpc" "terraform-vpc" 
{
	cidr_block = "${var.network_address_space}"
	enable_dns_hostnames = "true" 


	tags {
	  Name = "${var.environment_tag}-vpc"
	  
	  Environment  = "${var.environment_tag}"
	}
}

resource "aws_internet_gateway" "igw" {
	vpc_id = "${aws_vpc.terraform-vpc.id}"

	  tags {
	     Name = "${var.environment_tag}-igw"
	 
	     Environment  = "${var.environment_tag}"
	  }
}

resource "aws_subnet" "subnet1" {
	cidr_block              = "${var.subnet1_address_space}"
	vpc_id                  = "${aws_vpc.terraform-vpc.id}"
	map_public_ip_on_launch = "true"
	availability_zone = "${data.aws_availability_zones.available.names[0]}"

	tags {
	     Name = "${var.environment_tag}-subnet1"
	     
	     Environment  = "${var.environment_tag}"
	  }



}

resource "aws_subnet" "subnet2" {
	cidr_block              = "${var.subnet2_address_space}"
	vpc_id                  = "${aws_vpc.terraform-vpc.id}"
	map_public_ip_on_launch = "true"
	availability_zone = "${data.aws_availability_zones.available.names[1]}"

	 tags {
	     Name = "${var.environment_tag}-subnet2"
	     
	     Environment  = "${var.environment_tag}"
	  }

}



# ROUTING #

resource "aws_route_table" "rtb" {
	vpc_id   = "${aws_vpc.terraform-vpc.id}"

	route {
	  cidr_block = "0.0.0.0/0"
	  gateway_id = "${aws_internet_gateway.igw.id}"
	}

	 tags {
	   Name = "{var.environment_tag}-rtb"
	   
	   Environment  = "${var.environment_tag}"
	 }


}

resource "aws_route_table_association" "rta-subnet1" {
	 subnet_id      = "${aws_subnet.subnet1.id}"
	 route_table_id  = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
	 subnet_id      = "${aws_subnet.subnet2.id}"
	 route_table_id  = "${aws_route_table.rtb.id}"
}



# SECURITY GROUPS #

# ELB Security group

resource "aws_security_group" "elb_sg" {
	name      = "ngix_elb_sg"
	vpc_id     = "${aws_vpc.terraform-vpc.id}"

# SSH access from Anywhere

ingress {
	from_port     = 22
	to_port       = 22
	protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
   }

# HTTP access from anywhere

ingress {
	from_port     = 80
	to_port       = 80
	protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
   }

# Outbound Internet access

egress {
	from_port     = 0
	to_port       = 0
	protocol      = "-1"
    cidr_blocks   = ["0.0.0.0/0"]
  }
    
    tags {
	   Name = "{var.environment_tag}-sg"
	   
	   Environment  = "${var.environment_tag}"
	 }


}

# Nginx Security group

resource "aws_security_group" "nginx_sg" {
	name      = "nginx_sg"
	vpc_id     = "${aws_vpc.terraform-vpc.id}"

# SSH access from Anywhere

ingress {
	from_port     = 22
	to_port       = 22
	protocol      = "tcp"
    cidr_blocks   = ["0.0.0.0/0"]
   }

# HTTP access from anywhere

ingress {
	from_port     = 80
	to_port       = 80
	protocol      = "tcp"
    cidr_blocks   = ["${var.network_address_space}"]
   }

# Outbound Internet access

egress {
	from_port     = 0
	to_port       = 0
	protocol      = "-1"
    cidr_blocks   = ["0.0.0.0/0"]
  }

     tags {
	   Name = "{var.environment_tag}-nginx-sg"
	 
	   Environment  = "${var.environment_tag}"
	 }


}





# INSTANCES #

resource "aws_instance" "nginx1" {
	
	ami           = "ami-0a34f2d854bdbd4fb"
	instance_type = "t2.micro"
	subnet_id     = "${aws_subnet.subnet1.id}"
	vpc_security_group_ids = ["${aws_security_group.nginx_sg.id}"]
	key_name      = "${var.key_name}"

	 

	      tags {
	   Name = "${var.environment_tag}-nginx1"
	  
	   Environment  = "${var.environment_tag}"
	 }
  
	     
}

resource "aws_instance" "nginx2" {
	
	ami           = "ami-0a34f2d854bdbd4fb"
	instance_type = "t2.micro"
	subnet_id     = "${aws_subnet.subnet2.id}"
	vpc_security_group_ids = ["${aws_security_group.nginx_sg.id}"]
	key_name      = "${var.key_name}"

	 

	      tags {
	   Name = "${var.environment_tag}-nginx2"
	  
	   Environment  = "${var.environment_tag}"
	 }
  
	     
}


# LOAD BALANCER #

resource "aws_elb" "web" {
	name = "terraform-elb"

	subnets = ["${aws_subnet.subnet1.id}", "${aws_subnet.subnet2.id}"]
	security_groups = ["${aws_security_group.elb_sg.id}"]
	instances = ["${aws_instance.nginx1.id}", "${aws_instance.nginx2.id}"]

	listener {
	   instance_port     = 80
	   instance_protocol = "http"
	   lb_port           = 80
	   lb_protocol       = "http"
	   
	     }


	      tags {

	   Name = "${var.environment_tag}-elb"
	   
	   Environment  = "${var.environment_tag}"
	      }
}


#    S3 BUCKET     #

resource "aws_s3_bucket" "terraform-bucket" {
	
	bucket = "${var.environment_tag}-${var.bucket_name}"
	acl  = "private"
	force_destroy = "true"

	 tags {

	   Name = "${var.environment_tag}-bucket"
	   
	   Environment  = "${var.environment_tag}"
	      }

}




   


#################################################################

# output

#################################################################
   
   output "aws_instance_public_dns" {

     value = "${aws_instance.nginx1.public_dns}"
   }
