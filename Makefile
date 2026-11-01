.PHONY: build test lint spike-image spike clean

build:
	go build -o bin/pipeshift ./cmd/pipeshift

test:
	go test ./...

lint:
	golangci-lint run

# Milestone 1: build the pinned Jenkins parser image.
spike-image:
	docker build -t pipeshift-jenkins:spike internal/jenkins/image

# Milestone 1: run every spike fixture through the sandboxed converter.
# Results are written to docs/spike/results/.
spike: spike-image
	docs/spike/run.sh

clean:
	rm -rf bin
