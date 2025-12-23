.PHONY: build test clean

build:
	go build -o deployer main.go

test:
	go test ./... -v

clean:
	rm -f deployer

run: build
	./deployer

help:
	@echo "Available targets:"
	@echo "  make build   - Build the deployer binary"
	@echo "  make test    - Run tests"
	@echo "  make clean   - Remove build artifacts"
	@echo "  make run     - Build and run deployer"
	@echo "  make help    - Show this help message"
