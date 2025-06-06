# GitHub Secrets Configuration

## Required Secrets

### Database Secrets
- `DEV_DB_PASSWORD`: Development database password
- `PROD_DB_PASSWORD`: Production database password

### WebDNA Admin Secrets
- `DEV_WEBDNA_ADMIN_PASSWORD`: Development WebDNA admin password
- `PROD_WEBDNA_ADMIN_PASSWORD`: Production WebDNA admin password

### Deployment Secrets
- `DEPLOY_USER`: SSH user for deployment (usually 'runner')
- `DEPLOY_SSH_KEY`: Private SSH key for server access

### Optional Secrets

#### Docker Registry (if using container deployment)
- `DOCKER_REGISTRY_URL`: Docker registry URL
- `DOCKER_REGISTRY_USERNAME`: Registry username
- `DOCKER_REGISTRY_PASSWORD`: Registry password

#### Notification Services
- `SLACK_WEBHOOK_URL`: Slack webhook for deployment notifications
- `DISCORD_WEBHOOK_URL`: Discord webhook for deployment notifications

## Adding Secrets

1. Go to your repository on GitHub
2. Navigate to Settings > Secrets and variables > Actions
3. Click "New repository secret"
4. Add each secret with the name and value
5. Secrets are encrypted and only exposed to GitHub Actions workflows

## Using Secrets in Workflows

```yaml
env:
  DB_PASSWORD: ${{ secrets.PROD_DB_PASSWORD }}
  ADMIN_PASSWORD: ${{ secrets.PROD_WEBDNA_ADMIN_PASSWORD }}
```

## Security Best Practices

1. Never commit secrets to your repository
2. Use strong, unique passwords for each environment
3. Rotate secrets regularly
4. Limit access to production secrets
5. Use GitHub's environment protection rules for production deployments
