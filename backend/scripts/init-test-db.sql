-- Cria automaticamente o banco separado para os testes automatizados.
SELECT 'CREATE DATABASE lider_test OWNER lider'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'lider_test')\gexec
