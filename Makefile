# ============================================================
#  Makefile — Orders & Account Transactions
#  Default: native Ruby/Rails
#  Optional: DOCKER=1 make <target>
# ============================================================

DOCKER ?= 0
DC      = docker compose
APP     = app

ifeq ($(DOCKER), 1)
  RUN = $(DC) run --rm $(APP)
else
  RUN =
endif

.DEFAULT_GOAL := help

# ── Help ────────────────────────────────────────────────────

.PHONY: help
help:
	@echo ""
	@echo "  Usage: make <target> [DOCKER=1]"
	@echo ""
	@echo "  Setup"
	@echo "    setup          Install gems, create and migrate DB"
	@echo "    setup-docker   Build images and run full setup inside Docker"
	@echo ""
	@echo "  Development"
	@echo "    server         Start Rails server (port 3000)"
	@echo "    console        Open Rails console"
	@echo "    routes         Print all routes"
	@echo ""
	@echo "  Database"
	@echo "    db-create      Create databases"
	@echo "    db-migrate     Run pending migrations"
	@echo "    db-rollback    Rollback last migration"
	@echo "    db-seed        Seed the database"
	@echo "    db-reset       Drop, create, migrate, seed"
	@echo ""
	@echo "  Tests"
	@echo "    test           Run full RSpec suite"
	@echo "    test-models    Run model specs only"
	@echo "    test-services  Run service specs only"
	@echo "    test-requests  Run request (API) specs only"
	@echo "    coverage       Run tests and open coverage report"
	@echo ""
	@echo "  Swagger"
	@echo "    swagger        Generate swagger.yaml from specs"
	@echo ""
	@echo "  Docker"
	@echo "    up             Start all Docker services"
	@echo "    down           Stop all Docker services"
	@echo "    logs           Tail Docker logs"
	@echo "    ps             Show running containers"
	@echo ""
	@echo "  Examples"
	@echo "    make setup              # native"
	@echo "    make setup DOCKER=1     # inside Docker"
	@echo "    make test  DOCKER=1"
	@echo ""

# ── Setup ───────────────────────────────────────────────────

.PHONY: setup
setup:
ifeq ($(DOCKER), 1)
	$(DC) build
	$(DC) run --rm $(APP) bundle install
	$(DC) run --rm $(APP) bundle exec rails db:create db:migrate
else
	bundle install
	bin/rails db:prepare
endif

.PHONY: setup-docker
setup-docker:
	DOCKER=1 $(MAKE) setup

# ── Development ─────────────────────────────────────────────

.PHONY: server
server:
ifeq ($(DOCKER), 1)
	$(DC) up
else
	bundle exec rails server -p 3000
endif

.PHONY: console
console:
	$(RUN) bundle exec rails console

.PHONY: routes
routes:
	$(RUN) bundle exec rails routes

# ── Database ────────────────────────────────────────────────

.PHONY: db-create
db-create:
	$(RUN) bundle exec rails db:create

.PHONY: db-migrate
db-migrate:
	$(RUN) bundle exec rails db:migrate

.PHONY: db-rollback
db-rollback:
	$(RUN) bundle exec rails db:rollback

.PHONY: db-seed
db-seed:
	$(RUN) bundle exec rails db:seed

.PHONY: db-reset
db-reset:
	$(RUN) bundle exec rails db:drop db:create db:migrate db:seed

# ── Tests ───────────────────────────────────────────────────

.PHONY: test
test:
	$(RUN) bundle exec rspec

.PHONY: test-models
test-models:
	$(RUN) bundle exec rspec spec/models/

.PHONY: test-services
test-services:
	$(RUN) bundle exec rspec spec/services/

.PHONY: test-requests
test-requests:
	$(RUN) bundle exec rspec spec/requests/

.PHONY: coverage
coverage:
	$(RUN) bundle exec rspec
ifeq ($(DOCKER), 0)
	open coverage/index.html 2>/dev/null || xdg-open coverage/index.html
endif

# ── Swagger ─────────────────────────────────────────────────

.PHONY: swagger
swagger:
	$(RUN) bundle exec rake rswag:specs:swaggerize
	@echo "Swagger UI → http://localhost:3000/api-docs"

# ── Docker ──────────────────────────────────────────────────

.PHONY: up
up:
	$(DC) up

.PHONY: down
down:
	$(DC) down

.PHONY: logs
logs:
	$(DC) logs -f

.PHONY: ps
ps:
	$(DC) ps
