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
	if len(q.items) >= q.cap {
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
