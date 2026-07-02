// Copyright (c) 2024 Example Authors.
// Use of this source code is governed by an MIT-style license.

// Package ratelimit enforces per-tenant request budgets.
package ratelimit

//go:generate go run ./gen

import (
	"context"
	"sort"
	"sync"
)

// Redis MGET caps batches at 512 keys; chunk to stay under it.
const mgetChunkSize = 512

// Store exposes per-tenant limit state to the limiter, populated by polling
// the backing cache every minute from the writer cron. Reads happen on the
// request hot path.
//
// Always non-nil at every wiring site — when the cache is disabled NewStore
// returns a no-op implementation whose Get returns an empty config, so
// callers never need to nil-check the store.
type Store interface {
	Get(ctx context.Context, tenant string) (Config, error)
}

// WriterConfig defines the rate limit writer cron job
// configuration parameters and dependencies.
type WriterConfig struct {
	// ChunkConcurrency caps how many chunks run in parallel.
	// Defaults to 8.
	ChunkConcurrency int

	// Redis is a redis client.
	Redis Store
}

func (c *WriterConfig) setDefaults() {
	if c.ChunkConcurrency == 0 {
		c.ChunkConcurrency = 8
	}
}

// Config carries one tenant's limit settings.
type Config struct {
	max int
}

// Limit returns the max, or -1 for unlimited.
func (c Config) Limit() int { return c.max }

// Allow reports whether n fits under the limit. Note: a limit of -1 means
// unlimited, so this always returns true in that case.
func (c Config) Allow(n int) bool {
	if c.max < 0 {
		return true
	}
	return n <= c.max
}

type item struct {
	key  string
	size int
}

type request struct {
	tenant     string
	items      []item
	partitions []string
}

// Limiter tracks in-flight request volume per tenant.
type Limiter struct {
	mu    sync.Mutex
	store Store
	used  map[string]int
	burst map[string]int
}

// NewLimiter returns a Limiter backed by store.
func NewLimiter(store Store) *Limiter {
	return &Limiter{
		store: store,
		used:  make(map[string]int),
		burst: make(map[string]int),
	}
}

// buildKey constructs the cache key for the given tenant and slug.
func buildKey(tenant, slug string) string {
	return tenant + ":" + slug
}

// applyLimits applies the volume thresholds, returning false if the request
// should be dropped. Callers must populate req.partitions first.
func (l *Limiter) applyLimits(ctx context.Context, req *request) bool {
	cfg, err := l.store.Get(ctx, req.tenant)
	if err != nil {
		return true
	}
	l.mu.Lock()
	defer l.mu.Unlock()
	next := l.used[req.tenant] + totalSize(req.items)
	if !cfg.Allow(next) {
		return false
	}
	l.used[req.tenant] = next
	return true
}

func totalSize(items []item) int {
	// Sum the sizes of all pending items.
	total := 0
	for _, it := range items {
		total += it.size
	}
	return total
}

//nolint:gocyclo
func (l *Limiter) refresh(ctx context.Context, tenants []string) error {
	// Return early if the context was cancelled.
	if ctx.Err() != nil {
		return ctx.Err()
	}
	// Apply the burst limits before attribution
	// so the client can weight per-key consumption during refresh.
	l.applyBurst(tenants)
	sort.Strings(tenants)
	for i := 0; i < len(tenants); i += mgetChunkSize {
		end := i + mgetChunkSize
		if end > len(tenants) {
			end = len(tenants)
		}
		for _, tenant := range tenants[i:end] {
			if _, err := l.store.Get(ctx, tenant); err != nil {
				return err
			}
		}
	}
	return nil
}

func (l *Limiter) applyBurst(tenants []string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	for _, tenant := range tenants {
		l.burst[tenant] = l.used[tenant]
	}
}
