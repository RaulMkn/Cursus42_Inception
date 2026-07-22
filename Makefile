# Variables
DATA_PATH = $(HOME)/data
COMPOSE_FILE = ./docker-compose.yaml

# Regla por defecto que levanta todo
all: build

# 1. Crear directorios y levantar contenedores
build:
	@echo "Creando directorios para volúmenes host..."
	@mkdir -p $(DATA_PATH)/mariadb
	@mkdir -p $(DATA_PATH)/wordpress
	@echo "Construyendo y levantando la infraestructura..."
	@docker compose -f $(COMPOSE_FILE) up -d --build

# 2. Apagar la infraestructura sin borrar datos
down:
	@echo "Apagando contenedores..."
	@docker compose -f $(COMPOSE_FILE) down

# 3. Limpieza profunda (para la evaluación)
clean: down
	@echo "Borrando imágenes y contenedores huérfanos..."
	@docker system prune -a -f

# 4. Destrucción total (Nuclear option)
fclean: clean
	@echo "Destruyendo volúmenes de Docker..."
	@docker volume rm $$(docker volume ls -q) 2>/dev/null || true
	@echo "Borrando datos físicos del host..."
	@sudo rm -rf $(DATA_PATH)/mariadb/*
	@sudo rm -rf $(DATA_PATH)/wordpress/*

# 5. Reinicio completo
re: fclean all

.PHONY: all build down clean fclean re