// SPDX-FileCopyrightText: 2025 Margo
//
// SPDX-License-Identifier: MIT
//
// SPDX-FileContributor: Michael Adler <michael.adler@siemens.com>

package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"syscall"
	"time"
)

var ctx, cancel = context.WithCancel(context.Background())

func main() {
	deployDir := flag.String("deployDir", "./deploy", "Directory to deploy")
	ociRegistry := flag.String("ociRegistry", "ghcr.io/silvanoc/poc-deploy:desired", "OCI registry URL")
	flag.Parse()

	defer cancel()
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	running := true
	for running {
		select {
		case <-ticker.C:
			if err := syncDeployments(*ociRegistry, *deployDir); err != nil {
				log.Println("ERROR:", err)
			}
		case <-sigChan:
			log.Println("Exiting gracefully...")
			cancel()
			running = false
		}
	}
	log.Println("Bye")
}
