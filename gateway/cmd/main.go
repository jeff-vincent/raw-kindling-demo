package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	_ "github.com/lib/pq"
)

var db *sql.DB

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://postgres:postgres@localhost:5432/gateway?sslmode=disable"
	}

	var err error
	db, err = sql.Open("postgres", dsn)
	if err != nil {
		log.Fatalf("failed to connect to database: %v", err)
	}
	defer db.Close()

	if err := db.Ping(); err != nil {
		log.Printf("warning: database not reachable: %v", err)
	}

	r := mux.NewRouter()
	r.HandleFunc("/health", healthHandler).Methods("GET")
	r.HandleFunc("/api/catalog", proxyHandler("CATALOG_URL", "/products")).Methods("GET")
	r.HandleFunc("/api/orders", proxyHandler("ORDERS_URL", "/orders")).Methods("GET", "POST")
	r.HandleFunc("/api/search", proxyHandler("SEARCH_URL", "/search")).Methods("GET")

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	log.Printf("Gateway listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(map[string]string{"status": "ok", "service": "gateway"})
}

func proxyHandler(envVar, path string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		upstream := os.Getenv(envVar)
		if upstream == "" {
			http.Error(w, envVar+" not configured", http.StatusServiceUnavailable)
			return
		}
		resp, err := http.Get(upstream + path)
		if err != nil {
			http.Error(w, "upstream error: "+err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(resp.StatusCode)
		json.NewEncoder(w).Encode(map[string]string{"proxied_to": upstream + path})
	}
}
