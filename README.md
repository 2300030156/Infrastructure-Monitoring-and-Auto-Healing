# Auto-Healing Infrastructure on GCP

Production-style demo project for auto-healing workloads on Google Cloud using:
- Terraform (infrastructure)
- Python Flask (backend)
- HTML/CSS/JS dashboard (frontend)
- Chaos testing script

## Architecture
- Custom VPC and subnet (`us-central1`)
- Firewall rule for TCP `5000`
- HTTP health check on `/health`
- Regional Managed Instance Group (MIG)
- Auto-healing policy attached to health check
- External HTTP Load Balancer

## Project Structure
- `main.tf`: GCP infrastructure (networking, MIG, health checks, load balancer)
- `startup_script.sh`: bootstraps VM app runtime and service
- `app.py`: Flask API/server
- `templates/index.html`: live dashboard UI with crash simulation
- `chaos_test.py`: continuous crash/recovery test loop

## Prerequisites
- Google Cloud SDK (`gcloud`)
- Terraform >= 1.5
- Python 3.10+

## Deploy
```powershell
terraform init
terraform apply -var="project_id=YOUR_GCP_PROJECT_ID"
```

Get load balancer IP:
```powershell
terraform output -raw load_balancer_ip
```

## Test
Open in browser:
```text
http://<LOAD_BALANCER_IP>
```

Run chaos test:
```powershell
pip install requests
python .\chaos_test.py <LOAD_BALANCER_IP>
```

## Cleanup
```powershell
terraform destroy -var="project_id=YOUR_GCP_PROJECT_ID"
```

## Notes
- Auto-healing speed depends on health-check settings and VM startup/service restart behavior.
- Terraform state files are intentionally excluded from Git.
