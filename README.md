# WebDNA Docker Server

A production-ready, containerized WebDNA Server v8.6.5 with Apache 2.4 on Ubuntu 22.04.

## 🏗️ Architecture

This project follows modern container best practices with a clean, organized structure:

```
├── build/                      # Build-related files
│   └── docker/                 # Docker configuration
│       ├── Dockerfile          # Multi-stage production Dockerfile
│       └── scripts/            # Container scripts
├── config/                     # Configuration management
│   ├── apache/                 # Apache configurations
│   ├── webdna/                 # WebDNA module configurations
│   └── env/                    # Environment templates
├── deploy/                     # Deployment files
│   └── docker-compose.yml      # Container orchestration
├── docs/                       # Documentation
├── scripts/                    # Utility scripts
├── tests/                      # Comprehensive test suite
│   ├── integration_tests.sh    # Full integration tests
│   ├── smoke_tests.sh          # Quick functionality tests
│   └── run_tests.sh            # Test runner
├── webdna-files/              # Sample WebDNA files
└── Makefile                   # Build automation
```

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Git
- Access to legacy server data (html/, WebCatalogEngine/, apache2/)

### Setup
1. **Clone and setup:**
   ```bash
   git clone <repository>
   cd theprogram5
   make setup
   ```

2. **Configure legacy data:**
   - Place your legacy `html/` folder in project root
   - Place your legacy `WebCatalogEngine/` folder in project root
   
3. **Start the application:**
   ```bash
   make dev    # Build, start, and test
   ```

4. **Access the application:**
   - **Main Application**: http://10.10.0.118:8080/ (redirects to /theprogram/)
   - **WebCatalog Admin**: http://10.10.0.118:8080/WebCatalog/
   - **Client Area**: http://10.10.0.118:8080/client/

## 🛠️ Development Commands

The project includes a comprehensive Makefile for common tasks:

```bash
make help          # Show all available commands
make build         # Build Docker image
make up            # Start services
make down          # Stop services
make restart       # Restart services
make logs          # View container logs
make test          # Run full test suite
make smoke-test    # Run quick tests
make health        # Check service health
make clean         # Clean up Docker resources
make fix-permissions # Fix file permissions
```

## 🧪 Testing

The project includes a comprehensive testing framework:

- **Smoke Tests**: Quick functionality verification
- **Integration Tests**: Comprehensive system testing  
- **Automated Testing**: Run via `make test`

Tests verify:
- Container startup and health
- WebDNA functionality
- Apache configuration
- All application URLs
- File permissions
- Module loading

## 🔧 Configuration

### Environment Configuration
Copy `config/env/.env.example` to `.env` and customize:

```bash
# Server Configuration
SERVER_NAME=localhost
HTTP_PORT=8080

# Development settings
DEVELOPMENT_MODE=false
HOST_UID=1000
HOST_GID=1000
```

### Adding Custom Configurations
- **Apache configs**: Add to `config/apache/`
- **WebDNA configs**: Add to `config/webdna/`
- **Environment configs**: Add to `config/env/`

## 📊 Monitoring & Health Checks

- **Built-in health checks**: Container includes automatic health monitoring
- **Logs**: Structured logging with colored output
- **Status checking**: `make health` for quick status verification

## 🐳 Docker Features

- **Multi-stage build**: Optimized for production
- **Security hardened**: Non-root processes, minimal attack surface
- **Health checks**: Automatic container health monitoring
- **Proper logging**: Structured logs with error handling
- **Clean shutdown**: Graceful process termination

## 🔒 Security

- Database files (.db, .hdr) blocked from web access
- WebCatalog admin directories protected
- WebMerchant sensitive directories secured
- Proper file permissions and ownership
- Minimal container attack surface

## 📝 Logging

Logs are available in multiple locations:
- **Container logs**: `make logs`
- **Apache logs**: `logs/` directory (mounted)
- **WebDNA startup logs**: `/var/log/apache2/webdna-startup.log`

## 🚢 Production Deployment

For production deployment:
1. Set `DEVELOPMENT_MODE=false` in environment
2. Use production-specific docker-compose file
3. Configure proper SSL certificates
4. Set up external log aggregation
5. Configure backup strategies for mounted volumes

## 🤝 Contributing

1. Make changes
2. Run tests: `make test`
3. Commit changes
4. Submit pull request

## 📞 Support

- Check logs: `make logs`
- Run health check: `make health`
- Run tests: `make test`

## 📜 License

See LICENSE file for details.

---

🤖 Generated with [Claude Code](https://claude.ai/code)