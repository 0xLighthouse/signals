#!/usr/bin/env python3
"""
Development setup script for maintainable architecture.

This script helps set up the development environment with:
- Code formatting tools
- Linting configuration
- Pre-commit hooks
- Testing utilities
- Documentation generation
"""

import os
import subprocess
import sys
from pathlib import Path


def run_command(command: str, description: str) -> bool:
    """Run a shell command and return success status."""
    print(f"🔧 {description}...")
    try:
        result = subprocess.run(command, shell=True, check=True, capture_output=True, text=True)
        print(f"✅ {description} completed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ {description} failed: {e.stderr}")
        return False


def setup_code_formatting():
    """Set up code formatting tools."""
    print("\n📝 Setting up code formatting tools...")

    # Install formatting tools
    tools = [
        ("black", "Code formatter"),
        ("isort", "Import sorter"),
        ("flake8", "Linter"),
        ("mypy", "Type checker"),
    ]

    for tool, description in tools:
        run_command(f"poetry add --group dev {tool}", f"Installing {description}")

    # Create configuration files
    create_black_config()
    create_isort_config()
    create_flake8_config()
    create_mypy_config()


def create_black_config():
    """Create Black configuration."""
    config = '''[tool.black]
line-length = 100
target-version = ['py39', 'py310', 'py311', 'py312']
include = '\\.pyi?$'
extend-exclude = """
/(
  # directories
  \\.eggs
  | \\.git
  | \\.hg
  | \\.mypy_cache
  | \\.tox
  | \\.venv
  | build
  | dist
)/
"""
'''

    with open("pyproject.toml", "a") as f:
        f.write(config)
    print("✅ Black configuration added to pyproject.toml")


def create_isort_config():
    """Create isort configuration."""
    config = """
[tool.isort]
profile = "black"
line_length = 100
multi_line_output = 3
include_trailing_comma = true
force_grid_wrap = 0
use_parentheses = true
ensure_newline_before_comments = true
"""

    with open("pyproject.toml", "a") as f:
        f.write(config)
    print("✅ isort configuration added to pyproject.toml")


def create_flake8_config():
    """Create flake8 configuration."""
    config = """[flake8]
max-line-length = 100
extend-ignore = E203, W503
exclude =
    .git,
    __pycache__,
    .venv,
    build,
    dist,
    *.egg-info
"""

    with open(".flake8", "w") as f:
        f.write(config)
    print("✅ flake8 configuration created")


def create_mypy_config():
    """Create mypy configuration."""
    config = """[tool.mypy]
python_version = "3.9"
warn_return_any = true
warn_unused_configs = true
disallow_untyped_defs = true
disallow_incomplete_defs = true
check_untyped_defs = true
disallow_untyped_decorators = true
no_implicit_optional = true
warn_redundant_casts = true
warn_unused_ignores = true
warn_no_return = true
warn_unreachable = true
strict_equality = true

[[tool.mypy.overrides]]
module = [
    "cadCAD.*",
    "matplotlib.*",
    "seaborn.*",
    "pandas.*",
    "numpy.*"
]
ignore_missing_imports = true
"""

    with open("pyproject.toml", "a") as f:
        f.write(config)
    print("✅ mypy configuration added to pyproject.toml")


def setup_pre_commit_hooks():
    """Set up pre-commit hooks."""
    print("\n🪝 Setting up pre-commit hooks...")

    # Install pre-commit
    run_command("poetry add --group dev pre-commit", "Installing pre-commit")

    # Create pre-commit configuration
    config = """repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: debug-statements
      - id: check-docstring-first

  - repo: https://github.com/psf/black
    rev: 23.3.0
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort

  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.3.0
    hooks:
      - id: mypy
        additional_dependencies: [types-all]
"""

    with open(".pre-commit-config.yaml", "w") as f:
        f.write(config)
    print("✅ Pre-commit configuration created")

    # Install the hooks
    run_command("poetry run pre-commit install", "Installing pre-commit hooks")


def setup_testing_utilities():
    """Set up enhanced testing utilities."""
    print("\n🧪 Setting up testing utilities...")

    # Install testing tools
    tools = [
        ("pytest-xdist", "Parallel test execution"),
        ("pytest-mock", "Mocking utilities"),
        ("pytest-benchmark", "Performance testing"),
        ("coverage[toml]", "Coverage reporting"),
    ]

    for tool, description in tools:
        run_command(f"poetry add --group dev {tool}", f"Installing {description}")

    # Create pytest configuration
    create_pytest_config()
    create_coverage_config()


def create_pytest_config():
    """Create pytest configuration."""
    config = """[tool.pytest.ini_options]
minversion = "6.0"
addopts = [
    "-ra",
    "--strict-markers",
    "--strict-config",
    "--cov=src",
    "--cov-report=term-missing",
    "--cov-report=html",
    "--cov-report=xml",
]
testpaths = ["tests"]
markers = [
    "unit: Unit tests",
    "integration: Integration tests",
    "slow: Slow tests",
    "performance: Performance tests",
]
filterwarnings = [
    "ignore::DeprecationWarning",
    "ignore::PendingDeprecationWarning",
]
"""

    with open("pyproject.toml", "a") as f:
        f.write(config)
    print("✅ pytest configuration added to pyproject.toml")


def create_coverage_config():
    """Create coverage configuration."""
    config = """
[tool.coverage.run]
source = ["src"]
omit = [
    "*/tests/*",
    "*/test_*",
    "*/__pycache__/*",
    "*/examples/*",
    "*/scripts/*",
]

[tool.coverage.report]
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "if self.debug:",
    "if settings.DEBUG",
    "raise AssertionError",
    "raise NotImplementedError",
    "if 0:",
    "if __name__ == .__main__.:",
    "class .*\\bProtocol\\):",
    "@(abc\\.)?abstractmethod",
]
"""

    with open("pyproject.toml", "a") as f:
        f.write(config)
    print("✅ Coverage configuration added to pyproject.toml")


def create_makefile():
    """Create Makefile for common development tasks."""
    print("\n📋 Creating development Makefile...")

    makefile_content = """# Development Makefile for cadCAD Simulation

.PHONY: help install test lint format type-check clean docs run-sim run-viz

help:  ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \\033[36m%-15s\\033[0m %s\\n", $$1, $$2}'

install:  ## Install dependencies
	poetry install

test:  ## Run tests
	poetry run pytest

test-fast:  ## Run tests in parallel
	poetry run pytest -n auto

test-cov:  ## Run tests with coverage
	poetry run pytest --cov=src --cov-report=html

lint:  ## Run linting
	poetry run flake8 src tests
	poetry run mypy src

format:  ## Format code
	poetry run black src tests examples scripts
	poetry run isort src tests examples scripts

format-check:  ## Check code formatting
	poetry run black --check src tests examples scripts
	poetry run isort --check-only src tests examples scripts

type-check:  ## Run type checking
	poetry run mypy src

clean:  ## Clean up generated files
	rm -rf .coverage htmlcov/ .pytest_cache/ .mypy_cache/
	find . -type d -name __pycache__ -delete
	find . -type f -name "*.pyc" -delete

docs:  ## Generate documentation
	@echo "Documentation generation not yet implemented"

run-sim:  ## Run simulation
	poetry run python src/main.py

run-viz:  ## Run visualization
	poetry run python src/visualize.py

run-example:  ## Run maintainable architecture example
	poetry run python examples/maintainable_example.py

pre-commit:  ## Run pre-commit on all files
	poetry run pre-commit run --all-files

setup-dev:  ## Set up development environment
	poetry run python scripts/setup_maintainable_dev.py

# CI/CD targets
ci-test:  ## Run tests for CI
	poetry run pytest --cov=src --cov-report=xml

ci-lint:  ## Run linting for CI
	poetry run flake8 src tests
	poetry run mypy src
	poetry run black --check src tests
	poetry run isort --check-only src tests
"""

    with open("Makefile", "w") as f:
        f.write(makefile_content)
    print("✅ Makefile created with development commands")


def create_vscode_settings():
    """Create VS Code settings for the project."""
    print("\n💻 Creating VS Code settings...")

    os.makedirs(".vscode", exist_ok=True)

    settings = """{
    "python.defaultInterpreterPath": ".venv/bin/python",
    "python.formatting.provider": "black",
    "python.formatting.blackArgs": ["--line-length", "100"],
    "python.linting.enabled": true,
    "python.linting.flake8Enabled": true,
    "python.linting.mypyEnabled": true,
    "python.sortImports.args": ["--profile", "black"],
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "files.exclude": {
        "**/__pycache__": true,
        "**/.pytest_cache": true,
        "**/.mypy_cache": true,
        "**/htmlcov": true,
        "**/*.pyc": true
    },
    "python.testing.pytestEnabled": true,
    "python.testing.pytestArgs": ["tests"],
    "python.testing.unittestEnabled": false
}"""

    with open(".vscode/settings.json", "w") as f:
        f.write(settings)
    print("✅ VS Code settings created")


def create_github_workflows():
    """Create GitHub Actions workflows."""
    print("\n🚀 Creating GitHub Actions workflows...")

    os.makedirs(".github/workflows", exist_ok=True)

    ci_workflow = """name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: [3.9, "3.10", "3.11", "3.12"]

    steps:
    - uses: actions/checkout@v3

    - name: Set up Python ${{ matrix.python-version }}
      uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}

    - name: Install Poetry
      uses: snok/install-poetry@v1
      with:
        version: latest
        virtualenvs-create: true
        virtualenvs-in-project: true

    - name: Load cached venv
      id: cached-poetry-dependencies
      uses: actions/cache@v3
      with:
        path: .venv
        key: venv-${{ runner.os }}-${{ matrix.python-version }}-${{ hashFiles('**/poetry.lock') }}

    - name: Install dependencies
      if: steps.cached-poetry-dependencies.outputs.cache-hit != 'true'
      run: poetry install --no-interaction --no-root

    - name: Install project
      run: poetry install --no-interaction

    - name: Run linting
      run: |
        poetry run flake8 src tests
        poetry run black --check src tests
        poetry run isort --check-only src tests

    - name: Run type checking
      run: poetry run mypy src

    - name: Run tests
      run: poetry run pytest --cov=src --cov-report=xml

    - name: Upload coverage to Codecov
      uses: codecov/codecov-action@v3
      with:
        file: ./coverage.xml
        fail_ci_if_error: true
"""

    with open(".github/workflows/ci.yml", "w") as f:
        f.write(ci_workflow)
    print("✅ GitHub Actions CI workflow created")


def main():
    """Main setup function."""
    print("🎯 Setting up maintainable development environment")
    print("=" * 60)

    # Check if we're in the right directory
    if not Path("pyproject.toml").exists():
        print("❌ pyproject.toml not found. Please run this script from the project root.")
        sys.exit(1)

    # Run setup steps
    setup_code_formatting()
    setup_pre_commit_hooks()
    setup_testing_utilities()
    create_makefile()
    create_vscode_settings()
    create_github_workflows()

    print("\n🎉 Development environment setup complete!")
    print("\n📋 Next steps:")
    print("1. Run 'make install' to install all dependencies")
    print("2. Run 'make format' to format existing code")
    print("3. Run 'make test' to run the test suite")
    print("4. Run 'make pre-commit' to check all files")
    print("5. Start developing with the new maintainable architecture!")

    print("\n🔧 Available make commands:")
    print("- make help          # Show all available commands")
    print("- make test          # Run tests")
    print("- make format        # Format code")
    print("- make lint          # Run linting")
    print("- make run-sim       # Run simulation")
    print("- make run-viz       # Run visualization")
    print("- make run-example   # Run architecture example")


if __name__ == "__main__":
    main()
