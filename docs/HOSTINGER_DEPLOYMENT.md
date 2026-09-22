# Despliegue en un subdominio de Hostinger

Este proyecto necesita un VPS o el Docker Manager de Hostinger. El hosting compartido no puede ejecutar esta arquitectura de PostgreSQL, Redis, API, worker y web.

## Preparar el DNS

En Hostinger hPanel, abre Domains → tu dominio → DNS / Nameservers. Crea un registro A cuyo nombre sea solo el prefijo del subdominio, por ejemplo scanner, y cuyo destino sea la IP pública del VPS. Si los nameservers se gestionan en Cloudflare u otro proveedor, crea el registro allí. No elimines registros existentes sin verificar que no se usen para correo u otros servicios.

## Servidor

Instala Docker Engine y Compose en el VPS. Clona el repositorio y prepara la configuración:

    git clone https://github.com/natgrowthlab/ai-trading-scanner.git
    cd ai-trading-scanner
    cp .env.example .env

Antes de iniciar, cambia POSTGRES_PASSWORD y DATABASE_URL, JWT_SECRET y ENCRYPTION_KEY en .env por valores largos, únicos y secretos. No publiques el archivo .env.

Inicia la aplicación:

    docker compose -f docker-compose.yml -f docker-compose.production.yml up -d --build

Comprueba desde el VPS:

    curl http://127.0.0.1/health

## HTTPS

El proxy Nginx incluido publica HTTP en el puerto 80. Termina TLS mediante el reverse proxy/SSL administrado de Hostinger, o añade un proxy TLS separado que emita certificados Let's Encrypt. No expongas los puertos de PostgreSQL, Redis o FastAPI al internet público.

Hostinger confirma que un A record para el nombre del subdominio debe apuntar a la IP del VPS y que puede tardar hasta 24 horas en propagarse. Consulta su guía para [subdominios](https://www.hostinger.com/support/1583405-how-to-create-and-delete-subdomains-in-hostinger/) y la guía de [A records](https://www.hostinger.com/support/4468886-how-to-manage-a-records-at-hostinger/).
