provider "aws" {
  region     = "ap-south-1"
  profile    = "mypriyanshi"
}

resource "aws_key_pair" "test" {
    key_name   = "task1-key"
    public_key = "${tls_private_key.t.public_key_openssh}"
}
provider "tls" {}
resource "tls_private_key" "t" {
    algorithm = "RSA"
}
provider "local" {}
resource "local_file" "key" {
    content  = "${tls_private_key.t.private_key_pem}"
    filename = "task1-key.pem"
       
}

resource "aws_security_group" "task1-sg" {
  name        = "task1-sg"
  description = "Allow HTTP and SSH inbound traffic"
  

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "task1-sg"
  }
}

resource "aws_instance" "web" {
    ami           = "ami-0447a12f28fddb066"
    instance_type = "t2.micro"
    key_name = "task1-key"
    security_groups = [ "task1-sg" ]
    depends_on = [
        aws_key_pair.test,
    ]

    connection {
      type     = "ssh"
      user     = "ec2-user"
      private_key = file("/var/lib/jenkins/workspace/cloud-task1-code/task1-key.pem")
      host     = aws_instance.web.public_ip
    }

    provisioner "remote-exec" {
      inline = [
        "sudo yum install httpd  php git -y",
        "sudo systemctl start httpd",
        "sudo systemctl enable httpd",
      ]
    }

    tags = {
      Name = "task1-in"
    }

  }


resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "task1-ebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

resource "null_resource" "nulllocal2"  {
depends_on = [
    aws_volume_attachment.ebs_att,
  ]

	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/var/lib/jenkins/workspace/cloud-task1-code/task1-key.pem")
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "git clone https://github.com/Priyanshi-Garg/cloud-task1-code.git"
    ]
  }
}

resource "aws_s3_bucket" "lwtask1pgs3" {
  bucket = "lwtask1pgs3"
  acl    = "private"

  tags = {
    Name        = "lwtask1pgs3"
  force_destroy = true
  }
}

output "mydbsi" {
                  value = aws_s3_bucket.lwtask1pgs3
}

locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_distribution" "task1-cloud" {
  origin {
    domain_name = "${aws_s3_bucket.lwtask1pgs3.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
custom_origin_config {
    http_port = 80
    https_port = 80
    origin_protocol_policy = "match-viewer"
    origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"] 
    }
  }
enabled = true
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"
forwarded_values {
    query_string = false
cookies {
      forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cloud-front" {
                      value = aws_cloudfront_distribution.task1-cloud
}
