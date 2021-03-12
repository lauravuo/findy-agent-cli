AGENT_PATH=github.com/findy-network/findy-agent
LEDGER_NAME:=FINDY_FILE_LEDGER

AGENT_BRANCH=$(shell ./branch.sh ../findy-agent/)
API_BRANCH=$(shell ./branch.sh ../findy-agent-api/)
AUTH_BRANCH=$(shell ./branch.sh ../findy-agent-auth/)
GRPC_BRANCH=$(shell ./branch.sh ../findy-common-go/)
WRAP_BRANCH=$(shell ./branch.sh ../findy-wrapper-go/)

drop_wrap:
	go mod edit -dropreplace github.com/findy-network/findy-wrapper-go

drop_comm:
	go mod edit -dropreplace github.com/findy-network/findy-common-go

drop_auth:
	go mod edit -dropreplace github.com/findy-network/findy-agent-auth

drop_api:
	go mod edit -dropreplace github.com/findy-network/findy-agent-api

drop_agent:
	go mod edit -dropreplace github.com/findy-network/findy-agent

drop_all: drop_api drop_comm drop_wrap drop_wrap drop_auth

repl_wrap:
	go mod edit -replace github.com/findy-network/findy-wrapper-go=../findy-wrapper-go

repl_comm:
	go mod edit -replace github.com/findy-network/findy-common-go=../findy-common-go

repl_api:
	go mod edit -replace github.com/findy-network/findy-agent-api=../findy-agent-api

repl_auth:
	go mod edit -replace github.com/findy-network/findy-agent-auth=../findy-agent-auth

repl_agent:
	go mod edit -replace github.com/findy-network/findy-agent=../findy-agent

repl_all: repl_api repl_comm repl_wrap repl_agent repl_auth

modules:
	@echo Syncing modules for work brances ...
	go get github.com/findy-network/findy-agent-api@$(API_BRANCH)
	go get github.com/findy-network/findy-agent-auth@$(AUTH_BRANCH)
	go get github.com/findy-network/findy-wrapper-go@$(WRAP_BRANCH)
	go get github.com/findy-network/findy-common-go@$(GRPC_BRANCH)
	go get github.com/findy-network/findy-agent@$(AGENT_BRANCH)

deps:
	go get -t ./...

build:
	go build ./...

cli:
	go build -o $(GOPATH)/bin/cli

vet:
	go vet ./...

shadow:
	@echo Running govet
	go vet -vettool=$(GOPATH)/bin/shadow ./...
	@echo Govet success

check_fmt:
	$(eval GOFILES = $(shell find . -name '*.go'))
	@gofmt -l $(GOFILES)

lint:
	@golangci-lint run

lint_e:
	@$(GOPATH)/bin/golint ./... | grep -v export | cat

test:
	go test -v -p 1 -failfast ./...

test_cov:
	go test -v -p 1 -failfast -coverprofile=c.out ./... && go tool cover -html=c.out

e2e: install
	./scripts/dev/e2e-test.sh init_ledger
	./scripts/dev/e2e-test.sh e2e
	./scripts/dev/e2e-test.sh clean

e2e_ci: install
	./scripts/dev/e2e-test.sh e2e

check: check_fmt vet shadow

install:
	$(eval VERSION = $(shell cat ./VERSION))
	@echo "Installing version $(VERSION)"
	go install \
		-ldflags "-X '$(AGENT_PATH)-cli/utils.Version=$(VERSION)' -X '$(AGENT_PATH)/agent/utils.Version=$(VERSION)'" \
		./...

image:
	# https prefix for go build process to be able to clone private modules
	@[ "${HTTPS_PREFIX}" ] || ( echo "ERROR: HTTPS_PREFIX <{githubUser}:{githubToken}@> is not set"; exit 1 )
	$(eval VERSION = $(shell cat ./VERSION))
	docker build --build-arg HTTPS_PREFIX=$(HTTPS_PREFIX) -t findy-agent-cli .
	docker tag findy-agent-cli:latest findy-agent-cli:$(VERSION)

agency: image
	$(eval VERSION = $(shell cat ./VERSION))
	docker build -t findy-agency --build-arg CLI_VERSION=$(VERSION) ./agency
	docker tag findy-agency:latest findy-agency:$(VERSION)

# Test for agency-image start script:
#run-agency: agency
#	echo "{}" > findy.json && \
#	docker run -it --rm -v $(PWD)/agency/infra/.secrets/steward.exported:/steward.exported \
#		-e FCLI_AGENCY_SALT="this is only example" \
#		-p 8080:8080 \
#		-v $(PWD)/agency/infra/.secrets/aps.p12:/aps.p12 \
#		-v $(PWD)/scripts/dev/genesis_transactions:/genesis_transactions \
#		-v $(PWD)/findy.json:/root/findy.json findy-agency

# **** scripts for local agency development:
# WARNING: this will erase all your local indy wallets
scratch:
	./scripts/dev/dev.sh scratch $(LEDGER_NAME)

run:
	./scripts/dev/dev.sh install_run $(LEDGER_NAME)
# ****
