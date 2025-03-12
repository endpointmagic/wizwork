variable "name" {
 description = "The name to use for all resources created by this module"
 type        = string
}

variable "image" {
 description = "The docker image to run"
 type        = string
}

variable "container_port" {
 description = "The port the Docker image listens on"
 type        = number
}

variable "replicas" {
 description = "How many replicas to run"
 type        = number
}

variable "environment_variables" {
 description = "Environment variables to set for the app"
 type        = map(string)
 default     = {
    MONGODB_URI = "mongodb://3.80.67.46:27017"
 }
}
