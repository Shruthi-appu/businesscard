export function LoadingState({ label }: { label: string }) {
  return (
    <p className="status" role="status">
      {label}
    </p>
  );
}

export function NetworkState({ onRetry }: { onRetry?: () => void }) {
  return (
    <div className="alert" role="alert">
      <p>We couldn&apos;t reach Softxu. Check your connection and try again.</p>
      {onRetry ? (
        <button type="button" onClick={onRetry}>
          Retry
        </button>
      ) : null}
    </div>
  );
}

export function DeniedState({ message }: { message: string }) {
  return (
    <div className="alert" role="alert">
      <p>{message}</p>
    </div>
  );
}

export function ValidationState({ message }: { message: string }) {
  return (
    <div className="alert" role="alert">
      <p>{message}</p>
    </div>
  );
}
