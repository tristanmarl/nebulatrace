package main

import (
	"encoding/json"
	"log"
	"math/rand"
	"net/http"
	"os"
	"time"
)

func writeJSON(w http.ResponseWriter, status int, body map[string]any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(body)
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "service": "credits-api"})
	})
	mux.HandleFunc("/authorize", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Query().Get("force_error") == "true" || os.Getenv("ENTROPY_MODE") == "credit-errors" && rand.Intn(100) < 70 {
			writeJSON(w, http.StatusInternalServerError, map[string]any{
				"authorized": false,
				"reason":     "unstable credits core",
			})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{
			"authorized": true,
			"credits":    42,
			"cache":      os.Getenv("REDIS_URL"),
		})
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	server := &http.Server{Addr: ":" + port, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Printf("credits-api listening on %s", port)
	log.Fatal(server.ListenAndServe())
}
