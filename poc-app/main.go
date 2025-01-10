package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/redis/go-redis/v9"
)

var rdb *redis.Client

func getHitCount(ctx context.Context) (int64, error) {
	var retries = 5
	for {
		count, err := rdb.Incr(ctx, "hits").Result()
		if err == nil {
			return count, nil
		}
		if retries == 0 {
			return 0, err
		}
		retries--
		time.Sleep(500 * time.Millisecond)
	}
}

func hello(w http.ResponseWriter, r *http.Request) {
	log.Println("hello")
	count, err := getHitCount(r.Context())
	if err != nil {
		http.Error(w, "Could not increment hit count", http.StatusInternalServerError)
		return
	}
	fmt.Fprintf(w, "Hello World! I have been seen %d times.\n", count)
}

func main() {
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	log.Println("Using redis at", redisAddr)

	rdb = redis.NewClient(&redis.Options{
		Addr:        redisAddr,
		DialTimeout: 5 * time.Second,
	})

	http.HandleFunc("/", hello)

	listenAddr := os.Getenv("LISTEN_ADDRR")
	if listenAddr == "" {
		listenAddr = ":5000"
	}
	log.Printf("Listening on %s", listenAddr)
	log.Fatal(http.ListenAndServe(listenAddr, nil))
}
