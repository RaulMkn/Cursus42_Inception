# Variables
DATA_PATH = /home/rmakende/data
COMPOSE_FILE = ./srcs/docker-compose.yaml

# Regla por defecto que levanta todo
all: build

# 1. Crear directorios y levantar contenedores
build:
	@echo "Creando directorios para volúmenes host..."
	@mkdir -p $(DATA_PATH)/mariadb
	@mkdir -p $(DATA_PATH)/wordpress
	@echo "Construyendo y levantando la infraestructura..."
	@docker compose -f $(COMPOSE_FILE) up -d --build

# 2. Detener y reanudar contenedores sin destruirlos (prueba de persistencia)
stop:
	@echo "Deteniendo contenedores..."
	@docker compose -f $(COMPOSE_FILE) stop

start:
	@echo "Reanudando contenedores..."
	@docker compose -f $(COMPOSE_FILE) start

# 3. Apagar la infraestructura sin borrar datos
down:
	@echo "Apagando contenedores y eliminando redes..."
	@docker compose -f $(COMPOSE_FILE) down

# 4. Limpieza de imágenes y contenedores huérfanos del proyecto
clean: down
	@echo "Borrando imágenes y contenedores huérfanos del proyecto..."
	@docker compose -f $(COMPOSE_FILE) down --rmi all --remove-orphans

# 5. Destrucción total (volúmenes y datos persistentes en el host)
fclean: clean
	@echo "Destruyendo volúmenes del proyecto y datos físicos del host..."
	@docker compose -f $(COMPOSE_FILE) down -v
	@sudo rm -rf $(DATA_PATH)/mariadb
	@sudo rm -rf $(DATA_PATH)/wordpress

# 6. Reinicio completo desde cero
re: fclean all

.PHONY: all build stop start down clean fclean re
