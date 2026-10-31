"""Stay running on a host without reading the queue."""

import time

from worker.health import health


def main() -> None:
    while True:
        health()
        time.sleep(60)


if __name__ == "__main__":
    main()
