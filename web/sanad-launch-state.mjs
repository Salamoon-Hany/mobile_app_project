// Presentation state never grants account access; Firebase AuthGate remains authoritative.
export class LaunchState {
  constructor(seen = false) {
    this.step = 0;
    this.minElapsed = false;
    this.ready = false;
    this.complete = seen;
    this.failed = false;
  }
  get canOpen() { return this.minElapsed && this.complete && this.ready && !this.failed; }
  next() { this.step = Math.min(this.step + 1, 2); }
  back() { this.step = Math.max(this.step - 1, 0); }
  finish() { this.complete = true; }
  engineReady() { this.ready = true; this.failed = false; }
  engineError() { this.failed = true; this.ready = false; }
}
