# ClickHouse Setup Guide

This guide provides step-by-step instructions for setting up ClickHouse using Docker and native Linux installation.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Method 1: Docker Setup](#method-1-docker-setup)
- [Method 2: Linux Installation](#method-2-linux-installation)
- [Configuration](#configuration)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- **CPU**: x86_64 architecture
- **RAM**: Minimum 4GB, Recommended 8GB+
- **Storage**: At least 10GB free space
- **OS**: Ubuntu 18.04+, CentOS 7+, or Docker-compatible system

### Software Requirements
- **For Docker**: Docker Engine 20.10+ and Docker Compose 1.27+
- **For Linux**: Package manager (apt/yum/dnf)

---

## Method 1: Docker Setup

### Step 1: Install Docker and Docker Compose

#### Ubuntu/Debian:
```bash
# Update package index
sudo apt update

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### CentOS/RHEL:
```bash
# Install required packages
sudo yum install -y yum-utils

# Add Docker repository
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install Docker Engine
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Step 2: Create Project Directory
```bash
# Create project directory
mkdir -p ~/clickhouse-lab
cd ~/clickhouse-lab

# Create required directories
mkdir -p clickhouse_data clickhouse_logs clickhouse_backups grafana_data config
```

### Step 3: Create Configuration Files

#### Create users.xml configuration:
```bash
cat > config/users.xml << 'EOF'
<?xml version="1.0"?>
<clickhouse>
    <users>
        <default>
            <password></password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </default>
        <admin>
            <password>admin123</password>
            <networks>
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
            <access_management>1</access_management>
        </admin>
    </users>
</clickhouse>
EOF
```

#### Create backup disk configuration:
```bash
cat > backup_disk.xml << 'EOF'
<?xml version="1.0"?>
<clickhouse>
    <storage_configuration>
        <disks>
            <backup_disk>
                <type>local</type>
                <path>/backups/</path>
            </backup_disk>
        </disks>
    </storage_configuration>
    <backups>
        <allowed_disk>backup_disk</allowed_disk>
    </backups>
</clickhouse>
EOF
```

#### Create environment file:
```bash
cat > .env << 'EOF'
CLICKHOUSE_PORT=8123
CLICKHOUSE_TCP_PORT=9000
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=
EOF
```

### Step 4: Start ClickHouse with Docker Compose
```bash
# Start services
docker compose up -d

# Check if containers are running
docker compose ps

# View logs
docker compose logs -f clickhouse
```

### Step 5: Access ClickHouse
```bash
# Access ClickHouse client
docker exec -it clickhouse clickhouse-client

# Or access via HTTP
curl 'http://localhost:8123/' --data-binary "SELECT version()"
```

---

## Method 2: Linux Installation

### Ubuntu/Debian Installation

#### Step 1: Add ClickHouse Repository
```bash
# Add ClickHouse GPG key
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 8919F6BD2B48D754

# Add repository
echo "deb https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list

# Update package list
sudo apt update
```

#### Step 2: Install ClickHouse
```bash
# Install ClickHouse server and client
sudo apt install -y clickhouse-server clickhouse-client

# During installation, you'll be prompted to set a password for the default user
# Leave empty for no password or set a secure password
```

#### Step 3: Start ClickHouse Service
```bash
# Start ClickHouse service
sudo systemctl start clickhouse-server

# Enable auto-start on boot
sudo systemctl enable clickhouse-server

# Check service status
sudo systemctl status clickhouse-server
```

### CentOS/RHEL Installation

#### Step 1: Add ClickHouse Repository
```bash
# Add ClickHouse repository
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo

# Or for newer versions using dnf
sudo dnf config-manager --add-repo https://packages.clickhouse.com/rpm/clickhouse.repo
```

#### Step 2: Install ClickHouse
```bash
# Install ClickHouse server and client
sudo yum install -y clickhouse-server clickhouse-client

# Or for newer versions
sudo dnf install -y clickhouse-server clickhouse-client
```

#### Step 3: Start ClickHouse Service
```bash
# Start ClickHouse service
sudo systemctl start clickhouse-server

# Enable auto-start on boot
sudo systemctl enable clickhouse-server

# Check service status
sudo systemctl status clickhouse-server
```

### Alternative: Binary Installation

#### Step 1: Download ClickHouse Binaries
```bash
# Create installation directory
mkdir -p ~/clickhouse-install
cd ~/clickhouse-install

# Download ClickHouse binaries
curl -O 'https://builds.clickhouse.com/master/amd64/clickhouse'
chmod +x clickhouse

# Create symbolic links
sudo ln -sf ~/clickhouse-install/clickhouse /usr/local/bin/clickhouse-server
sudo ln -sf ~/clickhouse-install/clickhouse /usr/local/bin/clickhouse-client
```

#### Step 2: Create ClickHouse User and Directories
```bash
# Create clickhouse user
sudo useradd -r -s /bin/false -d /nonexistent clickhouse

# Create directories
sudo mkdir -p /etc/clickhouse-server
sudo mkdir -p /var/lib/clickhouse
sudo mkdir -p /var/log/clickhouse-server

# Set permissions
sudo chown clickhouse:clickhouse /var/lib/clickhouse
sudo chown clickhouse:clickhouse /var/log/clickhouse-server
```

#### Step 3: Create Configuration Files
```bash
# Download default configuration
sudo curl -o /etc/clickhouse-server/config.xml https://raw.githubusercontent.com/ClickHouse/ClickHouse/master/programs/server/config.xml
sudo curl -o /etc/clickhouse-server/users.xml https://raw.githubusercontent.com/ClickHouse/ClickHouse/master/programs/server/users.xml

# Set permissions
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server
```

#### Step 4: Create Systemd Service
```bash
# Create systemd service file
sudo tee /etc/systemd/system/clickhouse-server.service > /dev/null <<EOF
[Unit]
Description=ClickHouse Server (analytic DBMS for big data)
Requires=network.target
After=network.target

[Service]
Type=notify
User=clickhouse
Group=clickhouse
ExecStart=/usr/local/bin/clickhouse-server --config=/etc/clickhouse-server/config.xml
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal
SyslogIdentifier=clickhouse-server

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start service
sudo systemctl daemon-reload
sudo systemctl start clickhouse-server
sudo systemctl enable clickhouse-server
```

---

## Configuration

### Basic Configuration Files

#### 1. Main Configuration (/etc/clickhouse-server/config.xml)
Key settings to modify:
```xml
<!-- Listen on all interfaces -->
<listen_host>0.0.0.0</listen_host>

<!-- HTTP port -->
<http_port>8123</http_port>

<!-- Native TCP port -->
<tcp_port>9000</tcp_port>

<!-- Data directory -->
<path>/var/lib/clickhouse/</path>

<!-- Log directory -->
<logger>
    <log>/var/log/clickhouse-server/clickhouse-server.log</log>
    <errorlog>/var/log/clickhouse-server/clickhouse-server.err.log</errorlog>
</logger>
```

#### 2. Users Configuration (/etc/clickhouse-server/users.xml)
```xml
<users>
    <default>
        <password></password>
        <networks>
            <ip>::/0</ip>
        </networks>
        <profile>default</profile>
        <quota>default</quota>
    </default>
    
    <!-- Add custom users -->
    <admin>
        <password_sha256_hex>PASSWORD_HASH_HERE</password_sha256_hex>
        <networks>
            <ip>::/0</ip>
        </networks>
        <profile>default</profile>
        <quota>default</quota>
        <access_management>1</access_management>
    </admin>
</users>
```

### Security Configuration

#### Generate Password Hash:
```bash
# Generate SHA256 hash for password
echo -n "your_password" | sha256sum | cut -d' ' -f1
```

#### Firewall Configuration:
```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 8123/tcp  # HTTP port
sudo ufw allow 9000/tcp  # Native TCP port

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=8123/tcp
sudo firewall-cmd --permanent --add-port=9000/tcp
sudo firewall-cmd --reload
```

---

## Verification

### Step 1: Check Service Status
```bash
# Check if ClickHouse is running
sudo systemctl status clickhouse-server

# Check listening ports
sudo netstat -tulpn | grep clickhouse
# Or use ss command
sudo ss -tulpn | grep clickhouse
```

### Step 2: Test Database Connection
```bash
# Connect using clickhouse-client
clickhouse-client

# Test query
SELECT version();
SELECT now();
SHOW DATABASES;
```

### Step 3: Test HTTP Interface
```bash
# Simple query via HTTP
curl 'http://localhost:8123/' --data-binary "SELECT 'Hello, ClickHouse!'"

# Check system information
curl 'http://localhost:8123/' --data-binary "SELECT * FROM system.build_options"
```

### Step 4: Create Test Database and Table
```sql
-- Connect to ClickHouse
clickhouse-client

-- Create test database
CREATE DATABASE test_db;

-- Use the database
USE test_db;

-- Create test table
CREATE TABLE test_table (
    id UInt32,
    name String,
    timestamp DateTime
) ENGINE = MergeTree()
ORDER BY id;

-- Insert test data
INSERT INTO test_table VALUES (1, 'Test', now());

-- Query test data
SELECT * FROM test_table;
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. ClickHouse Won't Start
```bash
# Check logs
sudo journalctl -u clickhouse-server -f

# Check configuration syntax
clickhouse-server --config-file=/etc/clickhouse-server/config.xml --check-config

# Check permissions
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse
sudo chown -R clickhouse:clickhouse /var/log/clickhouse-server
```

#### 2. Connection Refused
```bash
# Check if service is running
sudo systemctl status clickhouse-server

# Check if ports are open
sudo netstat -tulpn | grep -E "(8123|9000)"

# Check firewall rules
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # CentOS
```

#### 3. Permission Denied
```bash
# Fix data directory permissions
sudo chown -R clickhouse:clickhouse /var/lib/clickhouse

# Fix log directory permissions
sudo chown -R clickhouse:clickhouse /var/log/clickhouse-server

# Fix configuration permissions
sudo chown -R clickhouse:clickhouse /etc/clickhouse-server
```

#### 4. Docker Issues
```bash
# Check Docker logs
docker compose logs clickhouse

# Check container status
docker compose ps

# Restart services
docker compose restart

# Reset everything
docker compose down
docker compose up -d
```

#### 5. Memory Issues
```bash
# Check available memory
free -h

# Adjust ClickHouse memory settings in config.xml
<max_memory_usage>4000000000</max_memory_usage>  <!-- 4GB -->
<max_memory_usage_for_user>8000000000</max_memory_usage_for_user>  <!-- 8GB -->
```

### Performance Tuning

#### 1. Optimize for Life Insurance Workloads
```xml
<!-- In config.xml -->
<max_concurrent_queries>100</max_concurrent_queries>
<max_memory_usage>8000000000</max_memory_usage>
<max_bytes_before_external_group_by>2000000000</max_bytes_before_external_group_by>
<max_bytes_before_external_sort>2000000000</max_bytes_before_external_sort>
```

#### 2. Disk Configuration
```xml
<!-- Configure multiple disks for better performance -->
<storage_configuration>
    <disks>
        <default>
            <path>/var/lib/clickhouse/</path>
        </default>
        <fast_ssd>
            <path>/var/lib/clickhouse_fast/</path>
        </fast_ssd>
    </disks>
</storage_configuration>
```

---

## Next Steps

1. **Install Grafana** (if using Docker setup):
   ```bash
   # Grafana will be available at http://localhost:3000
   # Username: admin, Password: admin
   ```

2. **Load Sample Data**:
   - Navigate to the labs directory
   - Run the schema creation scripts
   - Load sample life insurance data

3. **Configure Monitoring**:
   - Set up Grafana dashboards
   - Configure alerts for system metrics
   - Monitor query performance

4. **Security Hardening**:
   - Set up proper user authentication
   - Configure SSL/TLS
   - Implement row-level security
   - Set up audit logging

5. **Backup Configuration**:
   - Configure automated backups
   - Test restore procedures
   - Set up backup retention policies

---

## Useful Commands

### Service Management
```bash
# Start/Stop/Restart ClickHouse
sudo systemctl start clickhouse-server
sudo systemctl stop clickhouse-server
sudo systemctl restart clickhouse-server

# View logs
sudo journalctl -u clickhouse-server -f
tail -f /var/log/clickhouse-server/clickhouse-server.log
```

### Client Operations
```bash
# Connect with specific user
clickhouse-client --user admin --password

# Execute query from command line
clickhouse-client --query "SELECT version()"

# Execute query from file
clickhouse-client --queries-file script.sql

# Import data from CSV
clickhouse-client --query "INSERT INTO table FORMAT CSV" < data.csv
```

### Docker Operations
```bash
# View all containers
docker compose ps

# View logs
docker compose logs -f clickhouse

# Execute commands in container
docker compose exec clickhouse clickhouse-client

# Backup data
docker compose exec clickhouse clickhouse-client --query "BACKUP DATABASE life_insurance TO Disk('backup_disk', 'backup_name')"
```

For more advanced configurations and specific use cases, refer to the official ClickHouse documentation at https://clickhouse.com/docs/
