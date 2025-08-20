/**
 * Time-slice scheduler for non-blocking execution
 */

export type TaskFn = () => Promise<void> | void;
export type TaskPriority = 'high' | 'normal' | 'low';

interface Task {
  id: string;
  fn: TaskFn;
  priority: TaskPriority;
  enqueueTime: number;
}

export interface SchedulerOptions {
  sliceMs?: number;
  yieldMs?: number;
  maxMemoryMB?: number;
  onMemoryPressure?: () => void;
}

export class TimeSliceScheduler {
  private highQueue: Task[] = [];
  private normalQueue: Task[] = [];
  private lowQueue: Task[] = [];
  private running = false;
  private paused = false;
  private sliceMs: number;
  private yieldMs: number;
  private maxMemoryMB?: number;
  private onMemoryPressure?: () => void;
  private taskCount = 0;
  private metrics = {
    tasksCompleted: 0,
    totalSliceTime: 0,
    sliceCount: 0,
    gcPauses: 0
  };

  constructor(options: SchedulerOptions = {}) {
    this.sliceMs = options.sliceMs ?? 12;
    this.yieldMs = options.yieldMs ?? 0;
    this.maxMemoryMB = options.maxMemoryMB;
    this.onMemoryPressure = options.onMemoryPressure;
  }

  enqueue(fn: TaskFn, priority: TaskPriority = 'normal'): string {
    const id = `task-${++this.taskCount}`;
    const task: Task = { id, fn, priority, enqueueTime: Date.now() };

    switch (priority) {
      case 'high':
        this.highQueue.push(task);
        break;
      case 'low':
        this.lowQueue.push(task);
        break;
      default:
        this.normalQueue.push(task);
    }

    this.kick();
    return id;
  }

  pause(): void {
    this.paused = true;
  }

  resume(): void {
    this.paused = false;
    this.kick();
  }

  getMetrics() {
    return {
      ...this.metrics,
      avgSliceTime: this.metrics.sliceCount > 0 
        ? this.metrics.totalSliceTime / this.metrics.sliceCount 
        : 0,
      queueLengths: {
        high: this.highQueue.length,
        normal: this.normalQueue.length,
        low: this.lowQueue.length
      }
    };
  }

  private async kick(): Promise<void> {
    if (this.running || this.paused) return;
    
    this.running = true;
    try {
      while (!this.paused && this.hasWork()) {
        const sliceStart = performance.now();
        let tasksInSlice = 0;

        // Check memory pressure
        if (this.shouldCheckMemory()) {
          this.checkMemoryPressure();
        }

        // Execute tasks for this time slice
        while (this.hasWork() && !this.paused) {
          const task = this.dequeue();
          if (!task) break;

          const taskStart = performance.now();
          
          try {
            await task.fn();
            this.metrics.tasksCompleted++;
            tasksInSlice++;
          } catch (error) {
            console.error(`Task ${task.id} failed:`, error);
          }

          const taskTime = performance.now() - taskStart;
          
          // Check if we've exceeded the time slice
          if (performance.now() - sliceStart >= this.sliceMs) {
            break;
          }

          // Detect long GC pauses
          if (taskTime > 80) {
            this.metrics.gcPauses++;
          }
        }

        const sliceTime = performance.now() - sliceStart;
        this.metrics.totalSliceTime += sliceTime;
        this.metrics.sliceCount++;

        // Yield to browser
        await new Promise(resolve => setTimeout(resolve, this.yieldMs));
      }
    } finally {
      this.running = false;
    }
  }

  private hasWork(): boolean {
    return this.highQueue.length > 0 || 
           this.normalQueue.length > 0 || 
           this.lowQueue.length > 0;
  }

  private dequeue(): Task | null {
    if (this.highQueue.length > 0) {
      return this.highQueue.shift()!;
    }
    if (this.normalQueue.length > 0) {
      return this.normalQueue.shift()!;
    }
    if (this.lowQueue.length > 0) {
      return this.lowQueue.shift()!;
    }
    return null;
  }

  private shouldCheckMemory(): boolean {
    return this.maxMemoryMB !== undefined && 
           'memory' in performance && 
           this.metrics.sliceCount % 10 === 0;
  }

  private checkMemoryPressure(): void {
    if (!this.maxMemoryMB || !('memory' in performance)) return;

    const memory = (performance as any).memory;
    const usedMB = memory.usedJSHeapSize / (1024 * 1024);

    if (usedMB > this.maxMemoryMB) {
      this.onMemoryPressure?.();
      // Force a small pause to allow GC
      this.yieldMs = Math.min(this.yieldMs + 10, 100);
    } else if (usedMB < this.maxMemoryMB * 0.7) {
      // Gradually reduce yield time when memory is comfortable
      this.yieldMs = Math.max(0, this.yieldMs - 5);
    }
  }
}

// Specialized scheduler for background reconciliation
export class ReconcileScheduler extends TimeSliceScheduler {
  private reconcileInterval: number;
  private lastReconcile = 0;
  private reconcileTimer?: number;

  constructor(
    options: SchedulerOptions & { reconcileIntervalMinutes?: number } = {}
  ) {
    super(options);
    this.reconcileInterval = (options.reconcileIntervalMinutes ?? 10) * 60 * 1000;
  }

  scheduleReconcile(fn: TaskFn): void {
    const now = Date.now();
    if (now - this.lastReconcile >= this.reconcileInterval) {
      this.lastReconcile = now;
      this.enqueue(fn, 'low');
    }

    // Schedule next check
    if (this.reconcileTimer) {
      clearTimeout(this.reconcileTimer);
    }
    this.reconcileTimer = window.setTimeout(() => {
      this.scheduleReconcile(fn);
    }, this.reconcileInterval);
  }

  stop(): void {
    if (this.reconcileTimer) {
      clearTimeout(this.reconcileTimer);
      this.reconcileTimer = undefined;
    }
    this.pause();
  }
}