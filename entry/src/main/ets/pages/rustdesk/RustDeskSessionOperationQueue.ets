export class RustDeskSessionOperationQueue {
  private tail: Promise<void> = Promise.resolve();

  enqueue(operation: () => Promise<void>): Promise<void> {
    const queued = this.tail.then(
      (): Promise<void> => operation(),
      (): Promise<void> => operation(),
    );
    this.tail = queued.catch((): void => {});
    return queued;
  }
}
