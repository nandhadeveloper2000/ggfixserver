# AWS EC2 Deployment

This deploys the Spring Boot backend services to one EC2 host with:

- Java 21
- AWS RDS PostgreSQL (managed outside this host - no local database container)
- systemd services named `repair-shop-saas@<service>`
- GitHub Actions SSH deployment

## One-time EC2 setup

SSH into the EC2 instance, clone the repository, then run:

```bash
cd epair-shop-saas
bash deploy/aws/install-ec2.sh
```

The deploy script writes `/opt/repair-shop-saas/.env` on every deploy, pointing the
services at the RDS database (`DB_HOST`/`DB_NAME`/`DB_USER`/`DB_PASSWORD` defaults baked
into `deploy-from-artifact.sh`). The JWT secret and Cloudinary values are preserved
across deploys. Edit the file if you need different services or Cloudinary credentials:

```bash
sudo nano /opt/repair-shop-saas/.env
```

For a t3.micro, keep `SERVICES` small. A full 12-service backend usually needs a larger instance.

## GitHub secrets

Add these repository secrets:

- `AWS_EC2_HOST`: EC2 public IP or DNS
- `AWS_EC2_USER`: usually `ec2-user` on Amazon Linux
- `AWS_EC2_SSH_KEY`: private SSH key that can log in to the EC2 instance
- `AWS_EC2_PORT`: optional, defaults to `22`

Then run the `Deploy Backend to AWS EC2` workflow manually, or push to `main`.

## Check status

```bash
sudo systemctl status repair-shop-saas@auth-service
sudo journalctl -u repair-shop-saas@auth-service -f
```

