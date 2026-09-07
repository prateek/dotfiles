package writer

import (
	"context"
	"testing"
)

type nopClient struct{}

func (nopClient) Write(context.Context, *Batch) error { return nil }

func TestSubmitBatchOverLimit(t *testing.T) {
	w := NewWriter(SinkConfig{primaryClient: nopClient{}, shadowClient: nopClient{}}, 1)

	// A 1-byte budget with 2-byte items overflows on the first write.
	b := &Batch{items: []string{"ab"}, sealed: true, bytes: 2}
	if w.submitBatch(context.Background(), b) {
		t.Fatal("expected over-limit batch to be dropped")
	}
	// The denied batch's volume is
	// recorded as discarded against the global bucket; the caller handles
	// dropped-batch accounting.
	if got := w.queryDiscarded("global"); got != 2 {
		t.Fatalf("discarded = %d, want 2", got)
	}
}

func TestWriteAllAfterTraffic(t *testing.T) {
	w := NewWriter(SinkConfig{primaryClient: nopClient{}, shadowClient: nopClient{}}, 100)

	// Write items so the flusher refreshes and emits per-tier gauges.
	for i := 0; i < 3; i++ {
		b := &Batch{items: []string{"a"}, sealed: true, bytes: 1}
		w.submitBatch(context.Background(), b)
	}
	w.writeAll(context.Background(), &Batch{sealed: true})
}

func TestInternalBatchesSkipEnforcement(t *testing.T) {
	w := NewWriter(SinkConfig{primaryClient: nopClient{}, shadowClient: nopClient{}}, 0)

	b := &Batch{sealed: true, bytes: 9, internal: true}
	// Internal traffic bypasses tier limits so platform batches can't be
	// dropped by a tenant's quota.
	if !w.submitBatch(context.Background(), b) {
		t.Fatal("internal batch must pass even over the limit")
	}
}
