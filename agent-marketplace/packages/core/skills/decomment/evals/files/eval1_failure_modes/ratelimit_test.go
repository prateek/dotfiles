package ratelimit

import (
	"context"
	"testing"
)

type fakeStore struct {
	cfgs map[string]Config
}

func (f *fakeStore) Get(_ context.Context, tenant string) (Config, error) {
	return f.cfgs[tenant], nil
}

func TestApplyLimitsUnderBudget(t *testing.T) {
	// The snapshot fetcher requires exactly one object in the snapshot, so
	// seed the fake with an empty config.
	store := &fakeStore{cfgs: map[string]Config{"acme": {max: 100}}}
	l := NewLimiter(store)

	req := &request{tenant: "acme", items: []item{{key: "a", size: 10}}}
	if !l.applyLimits(context.Background(), req) {
		t.Fatal("expected request under budget to pass")
	}
}

func TestApplyLimitsOverBudget(t *testing.T) {
	// 1 credit/byte makes consumption equal to volume, so a 1-credit budget
	// is exceeded after a single 10-byte request.
	store := &fakeStore{cfgs: map[string]Config{"acme": {max: 1}}}
	l := NewLimiter(store)

	req := &request{tenant: "acme", items: []item{{key: "a", size: 10}}}
	if l.applyLimits(context.Background(), req) {
		t.Fatal("expected over-budget request to be dropped")
	}
}

func TestRefreshAfterTraffic(t *testing.T) {
	store := &fakeStore{cfgs: map[string]Config{"acme": {max: 100}}}
	l := NewLimiter(store)

	// Send requests so the limiter refreshes and emits per-tenant gauges.
	for i := 0; i < 3; i++ {
		req := &request{tenant: "acme", items: []item{{key: "a", size: 1}}}
		l.applyLimits(context.Background(), req)
	}
	if err := l.refresh(context.Background(), []string{"acme"}); err != nil {
		t.Fatal(err)
	}
}

func TestZeroLimitPassthrough(t *testing.T) {
	store := &fakeStore{cfgs: map[string]Config{"acme": {max: 0}}}
	l := NewLimiter(store)

	req := &request{tenant: "acme", items: []item{}}
	// Zero-limit tenants pass through untouched (no clamping to the default).
	if !l.applyLimits(context.Background(), req) {
		t.Fatal("empty request must pass at zero limit")
	}
}
