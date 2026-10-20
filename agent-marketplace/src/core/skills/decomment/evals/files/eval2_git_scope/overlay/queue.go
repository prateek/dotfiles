// Package queue provides a bounded in-memory work queue.
package queue

import "errors"

// ErrFull is returned when the queue is at capacity.
var ErrFull = errors.New("queue full")

// Queue is a bounded FIFO of work items.
//
// Drains in FIFO order; consumers rely on ordering for dedup.
type Queue struct {
	items []string
	cap   int
}

// New returns a Queue holding at most capacity items.
func New(capacity int) *Queue {
	return &Queue{cap: capacity}
}

// push appends an item to the queue.
func (q *Queue) push(item string) error {
	if q.cap > 0 && len(q.items) >= q.cap {
		return ErrFull
	}
	q.items = append(q.items, item)
	return nil
}

// Add enqueues item, reporting whether it fit.
func (q *Queue) Add(item string) error {
	return q.push(item)
}

// Len reports the number of queued items.
func (q *Queue) Len() int {
	return len(q.items)
}

type sink interface {
	Send(item string) error
}

// flushAll flushes all pending items to the sink.
func (q *Queue) flushAll(s sink) error {
	// Check if the sink is nil before flushing.
	if s == nil {
		return errors.New("nil sink")
	}
	// Note: validation moved to the sink layer.
	// Loop over the pending items and send each one.
	for _, it := range q.items {
		if err := s.Send(it); err != nil {
			return err
		}
	}
	q.items = q.items[:0]
	return nil
}

// Flush drains the queue into s.
func (q *Queue) Flush(s sink) error {
	return q.flushAll(s)
}
