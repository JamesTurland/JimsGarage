# Nextcloud Docker Setup

## Description
This project provides a Docker-based setup for Nextcloud with enhanced features including face recognition and memories. It's designed for easy deployment in home lab environments, particularly within LXC containers.

## Features
- Docker-based Nextcloud instance
- MariaDB for database
- Redis for caching
- FFmpeg and other tools for advanced features
- Supervisor for process management
- Compatibility with LXC containers

## Prerequisites
- Docker and Docker Compose installed on your system
- Basic understanding of Docker and command-line operations
- LXC container (if deploying in a containerized environment)

## Installation and Setup

1. Install Docker
   If you haven't already, install Docker on your system. You can find instructions for your operating system [here](https://docs.docker.com/get-docker/).

2. Create a user with specific UID and GID
   Run the following command to create a new user with UID and GID set to 10000:
   
   ```bash
   sudo useradd -u 10000 -g 10000 -m nextclouduser
   ```

3. Add the user to the Docker group
   This allows the user to run Docker commands without sudo:

   ```bash
   sudo usermod -aG docker nextclouduser
   ```

4. Map UID and GID of the LXC container
   If you're using an LXC container, ensure that the UID and GID of the container match those of the host user. This typically involves editing the LXC container's configuration file to add:

   ```bash
    # Map users
    lxc.idmap: u 0 100000 65536
    lxc.idmap: g 0 100000 65536
   ```

    Adjust these values according to your specific host UID/GID mappings.

5. (Optional) Change app data storage
    If you prefer to use a Docker volume instead of a local directory for app data, you can modify the `docker-compose.yml` file accordingly.

6. Build the Nextcloud app image
    Run the following command in the directory containing your Dockerfile and docker-compose.yml:

    ```bash
    docker compose build app
    ```

7. Start the Nextcloud stack
   Launch the entire Nextcloud stack with:

   ```bash
    docker compose up -d
    ```

## Configuration
- Copy the `.env.example` file to `.env` and adjust the variables as needed.
- Modify the `docker-compose.yml` file if you need to change ports or volume mappings.

## Usage
After the installation, you can access Nextcloud by navigating to `http://localhost:8080` in your web browser. Use the admin credentials specified in your `.env` file for the initial login.

## Advanced Features
This setup includes support for Nextcloud's face recognition and memories apps. These can be enabled through the Nextcloud web interface after installation.

## Troubleshooting
If you encounter issues, check the Docker logs:
```bash
 docker compose logs
```