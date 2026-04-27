SHELL := powershell.exe
.SHELLFLAGS := -NoProfile -ExecutionPolicy Bypass -Command

.PHONY: help check ci ci-fast lint guard build test coverage analyze \
        setup verify-env install-tools clean

help:
	@& ./scripts/help.ps1

check: lint guard build test
	@Write-Host 'OK  make check passed' -ForegroundColor Green

ci: lint guard build test coverage analyze
	@Write-Host 'OK  full CI passed' -ForegroundColor Green

ci-fast: lint guard
	@Write-Host 'OK  fast checks passed' -ForegroundColor Green

lint:
	@& ./scripts/lint.ps1

guard:
	@& ./scripts/guard.ps1

build:
	@& ./scripts/build-all.ps1

test:
	@& ./scripts/test.ps1

coverage:
	@& ./scripts/test.ps1 -Coverage

analyze:
	@& ./scripts/analyze.ps1

setup:
	@& ./scripts/setup.ps1

verify-env:
	@& ./scripts/verify-env.ps1

install-tools:
	@& ./scripts/install-tools.ps1

clean:
	@& ./scripts/clean.ps1
