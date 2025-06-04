# WebDNA Server Docker Container

This Docker setup provides a containerized WebDNA Server v8.6.5 running on Ubuntu 22.04 LTS with Apache 2.4.

## Quick Start

### 1. Build and Run with Docker Compose (Recommended)

```bash
# Build and start the container
docker-compose up --build

# Or run in detached mode
docker-compose up --build -d
```

### 2. Build and Run with Docker directly

```bash
# Build the image
docker build -t webdna-server .

# Run the container
docker run -p 8080:80 --name webdna-server webdna-server
```

## Access WebDNA

Once the container is running, you can access WebDNA at:

- **URL:** http://localhost:8080/WebCatalog
- **Username:** admin
- **Password:** admin

## Features

- **WebDNA Server v8.6.5** - Latest stable version
- **Apache 2.4** - Web server with WebDNA module
- **Ubuntu 22.04 LTS** - Stable base system
- **Port 8080** - Mapped to container port 80
- **Volume Mounts** - For persistent data and logs
- **Health Checks** - Automatic container health monitoring

## Directory Structure

```
.
├── Dockerfile              # Container definition
├── docker-compose.yml      # Docker Compose configuration
├── README.md              # This file
├── webdna-files/          # Your WebDNA files (created on first run)
└── logs/                  # Apache logs (created on first run)
```

## Container Management

```bash
# Start the container
docker-compose up -d

# Stop the container
docker-compose down

# View logs
docker-compose logs -f

# Restart the container
docker-compose restart

# Access container shell
docker-compose exec webdna-server bash
```

## Development

The `webdna-files` directory is mounted to `/var/www/html/webdna-files` in the container, allowing you to:

1. Create WebDNA templates and files locally
2. Access them from within the WebDNA environment
3. Persist data between container restarts

## Troubleshooting

### Container won't start
- Check if port 8080 is already in use: `netstat -an | grep 8080`
- View container logs: `docker-compose logs webdna-server`

### Can't access WebDNA
- Ensure the container is running: `docker-compose ps`
- Check health status: `docker-compose ps` (should show "healthy")
- Try accessing directly: `curl http://localhost:8080/WebCatalog`

### Permission issues
- The container runs Apache as `www-data` user
- Ensure mounted volumes have appropriate permissions:
  ```bash
  chmod -R 755 webdna-files/
  chmod -R 755 logs/
  ```

## License

WebDNA can be used for free after installation, but a license is required for continuous operation in production environments.

For support, contact: support@webdna.us

## WebDNA Resources

- [Official Documentation](https://docs.webdna.us/)
- [Installation Guide](https://docs.webdna.us/installers)
- [WebDNA Software Corporation](https://webdna.us/) 