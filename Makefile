DC  = docker compose
WEB = web

.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo ""
	@echo "  make start    — build + db:setup + db:seed + up (full start)"
	@echo "  make build    — build images"
	@echo "  make db-setup — create and migrate database"
	@echo "  make db-seed  — seed the database"
	@echo "  make up       — start containers"
	@echo ""

.PHONY: build
build:
	$(DC) build

.PHONY: db-setup
db-setup:
	$(DC) run --rm $(WEB) bin/rails db:setup

.PHONY: db-seed
db-seed:
	$(DC) run --rm $(WEB) bin/rails db:seed

.PHONY: up
up:
	$(DC) up

.PHONY: start
start: build db-setup db-seed up
