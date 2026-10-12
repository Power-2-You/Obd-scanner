// In-memory rate limiting. Suitable for a single instance; use a shared store
// (e.g. Redis) when running more than one replica.

export class TokenBucketLimiter {
  /**
   * @param {object} opts
   * @param {number} opts.capacity  burst size per key
   * @param {number} opts.refillPerMinute tokens added per minute per key
   * @param {number} opts.dailyCap  total requests per UTC day across all keys (cost guard)
   * @param {() => number} [opts.now]
   */
  constructor({ capacity = 5, refillPerMinute = 6, dailyCap = 2000, now = Date.now } = {}) {
    this.capacity = capacity;
    this.refillPerMs = refillPerMinute / 60000;
    this.dailyCap = dailyCap;
    this.now = now;
    this.buckets = new Map();
    this.day = this.#dayKey();
    this.dayCount = 0;
  }

  #dayKey() {
    return new Date(this.now()).toISOString().slice(0, 10);
  }

  /** @returns {{ok: true} | {ok: false, retryAfterSeconds: number, reason: string}} */
  take(key) {
    const t = this.now();
    const day = this.#dayKey();
    if (day !== this.day) {
      this.day = day;
      this.dayCount = 0;
    }
    if (this.dayCount >= this.dailyCap) {
      return { ok: false, retryAfterSeconds: 3600, reason: 'daily cap reached' };
    }
    let b = this.buckets.get(key);
    if (!b) {
      b = { tokens: this.capacity, at: t };
      this.buckets.set(key, b);
    }
    b.tokens = Math.min(this.capacity, b.tokens + (t - b.at) * this.refillPerMs);
    b.at = t;
    if (b.tokens < 1) {
      const wait = Math.ceil((1 - b.tokens) / this.refillPerMs / 1000);
      return { ok: false, retryAfterSeconds: wait, reason: 'per-client limit' };
    }
    b.tokens -= 1;
    this.dayCount += 1;
    if (this.buckets.size > 50000) this.#sweep(t);
    return { ok: true };
  }

  #sweep(t) {
    for (const [k, b] of this.buckets) {
      if (t - b.at > 10 * 60000) this.buckets.delete(k);
    }
  }
}
