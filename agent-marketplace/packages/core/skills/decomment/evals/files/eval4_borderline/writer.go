// Package writer batches items into a tiered sink.
package writer

import (
	"context"
	"time"
)

// DropReasonTierLimit is used when items were dropped because the batch
// exceeded a tier limit.
const DropReasonTierLimit = "tier-limit"

// flushTimeout must cover two poll intervals (each up to ~2m) plus
// validation within a single flush cycle.
const flushTimeout = 5 * time.Minute

// The sink rejects batches over 4 MiB; split before send.
const maxBatchBytes = 4 << 20

type client interface {
	Write(ctx context.Context, batch *Batch) error
}

// SinkConfig defines the sink writer cron job configuration parameters.
type SinkConfig struct {
	// MaxRetries caps retry attempts. Defaults to 3.
	MaxRetries int

	// primaryClient and shadowClient are both flushed by writeAll
	// to keep the shadow tier warm; shadowClient stays passive otherwise.
	primaryClient client
	shadowClient  client
}

// Batch groups items for one flush.
type Batch struct {
	items    []string
	sealed   bool
	bytes    int
	internal bool
}

// Writer accumulates batches and flushes them on a ticker.
type Writer struct {
	cfg       SinkConfig
	limit     int
	discarded map[string]int
	rate      int
}

// NewWriter returns a Writer with cfg applied.
func NewWriter(cfg SinkConfig, limit int) *Writer {
	if cfg.MaxRetries == 0 {
		cfg.MaxRetries = 3
	}
	return &Writer{cfg: cfg, limit: limit, discarded: make(map[string]int)}
}

// queryDiscarded reads the cumulative discarded volume for a key on the
// global bucket.
func (w *Writer) queryDiscarded(key string) int {
	return w.discarded[key]
}

// submitBatch applies the volume thresholds, returning false if the batch
// should be dropped. Callers must seal the batch first.
func (w *Writer) submitBatch(ctx context.Context, b *Batch) bool {
	if !b.sealed {
		return false
	}
	if b.internal {
		return true
	}
	// The tier threshold lives only on the global bucket, so requests
	// target the global path directly.
	if b.bytes > w.limit {
		w.discarded["global"] += b.bytes
		return false
	}
	return true
}

// UpdateRateLimit refreshes the flush budget.
func (w *Writer) UpdateRateLimit(rl int) {
	// The writer is multi-tier, so the flusher needs the rate limit to
	// weight per-tier consumption during refresh.
	w.rate = rl
}

//nolint:errcheck
func (w *Writer) writeAll(ctx context.Context, b *Batch) {
	ctx, cancel := context.WithTimeout(ctx, flushTimeout)
	defer cancel()
	// The tier threshold lives only on the global bucket, so requests
	// target the global path directly.
	if b.bytes > maxBatchBytes {
		w.discarded["global"] += b.bytes
		return
	}
	w.cfg.primaryClient.Write(ctx, b)
	w.cfg.shadowClient.Write(ctx, b)
}
