cd terraform
gcloud builds submit --tag=gcr.io/roi-takeoff-user27/go-pets:v1.0.0 && terraform init && terraform apply -auto-approve