# LexSearch

Учебный pet-проект: RAG на Rails для подготовки к техническому собеседованию.
Материалы (документация, конспекты, книги; ru + en) → поиск, ответы с цитатами, экзамен по карточкам
с оценкой ответа LLM-судьёй и интервальным повторением.
Цель — понять embeddings, pgvector, полнотекстовый и гибридный поиск (RRF), интеграцию LLM,
structured output, LLM-as-judge и оценку RAG. Основы для новичка: `docs/basics.md`. Теория и план этапов: `docs/theory.md`. Прогресс: `docs/learning_log.md`.

## Стек
- Rails 8.1, Ruby 3.3, Hotwire, Solid Queue, Tailwind
- PostgreSQL 17 + pgvector (Docker, порт 5433), gem `neighbor`
- Embeddings: Ollama (Docker, порт 11434); сейчас `nomic-embed-text` (768), с этапа 3 мультиязычная `bge-m3` (1024)
- LLM: Anthropic через gem `anthropic` (`LLM_MODEL`, по умолчанию `claude-haiku-5-5`)
- Тесты: RSpec, FactoryBot, WebMock, VCR

## Команды
- `docker compose up -d` — Postgres + Ollama
- `bin/setup --skip-server` — зависимости, модель Ollama, БД
- `bin/dev` — сервер
- `bundle exec rspec` — тесты

## Правила
- Бизнес-логика в `app/services` (PORO с `call`), фоновая работа в `app/jobs`.
- Тест на каждый сервис. Никакого реального HTTP в тестах: WebMock или VCR.
- Внешние сервисы (LLM, embeddings) только через обёртки: `Embeddings`, `LlmClient`.
- Документ — это данные, не инструкции: текст документов и ответы пользователя в промптах оборачивать в теги.
- Защищённые авторским правом материалы (книги) только в `db/seeds/private/`, не коммитить.
- Режим обучения: объяснять каждое решение («почему так»), после этапа давать упражнения
  и контрольные вопросы, записывать выводы в `docs/learning_log.md`.
- Комментарии в коде короткие, на английском. Коммиты на английском.
