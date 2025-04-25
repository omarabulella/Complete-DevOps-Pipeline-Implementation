terraform {
   /*
    backend "s3" { 
    bucket = "my-terraform-state-bucket-konecta"
    key = "terraform/eks/terraform.tfstate"
    region = "us-east-2"
    dynamodb_table = "terraform-locks"
    encrypt = true
    
  }
  */
}
resource "aws_s3_bucket" "terraform_state" {  
  bucket = var.s3_bucket_name
 /* lifecycle {
    prevent_destroy = true
  }*/
}
resource "aws_s3_bucket_versioning" "versioning" { 
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}
resource "aws_s3_bucket_public_access_block" "public_access" { 
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_dynamodb_table" "terraform_locks" { 
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
