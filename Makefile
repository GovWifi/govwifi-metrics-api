.PHONY: build up down test lint migrate shell seed

build:
	docker compose build

up:
	docker compose up -d
	docker compose exec -T api bundle exec rake db:create || true
	docker compose exec -T api bundle exec rake db:migrate

down:
	docker compose down -v

test: up
	mkdir -p coverage && chmod 777 coverage
	docker compose exec -T api bundle exec rake db:test:prepare
	docker compose exec -T api bundle exec rspec

lint: build up
	docker compose exec -T api bundle exec rubocop --cache false

lint-fix: build up
	docker compose exec -T api bundle exec rubocop -A --cache false

shell:
	docker compose exec api bash

seed: up
	docker compose exec -T api bundle exec rake db:seed_metrics
