#!/bin/bash

# This builds the binary that updates the kubeconfig on S3:

CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' ./update_kubeconfig.go
