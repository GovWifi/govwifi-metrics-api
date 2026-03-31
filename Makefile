.PHONY: build up down test lint migrate shell

build:
	docker-compose build

up:
	docker-compose up -d
	docker-compose exec -T api bundle exec rake db:create || true
	docker-compose exec -T api bundle exec rake db:migrate

down:
	docker-compose down -v

test: up
	docker-compose exec -T api bundle exec rake db:test:prepare
	docker-compose exec -T api bundle exec rspec

lint: build up
	docker-compose exec -T api bundle exec rubocop -A

shell:
	docker-compose exec api bash
