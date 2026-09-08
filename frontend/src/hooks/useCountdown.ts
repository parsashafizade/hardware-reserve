import { useEffect, useState } from "react";

export function useCountdown(initialSeconds = 0) {
  const [seconds, setSeconds] = useState(() => Math.max(0, initialSeconds));

  useEffect(() => {
    if (seconds <= 0) {
      return undefined;
    }

    const timer = window.setTimeout(() => {
      setSeconds((current) => Math.max(0, current - 1));
    }, 1000);

    return () => window.clearTimeout(timer);
  }, [seconds]);

  const restart = (nextSeconds: number) => {
    setSeconds(Math.max(0, nextSeconds));
  };

  return { seconds, restart };
}
