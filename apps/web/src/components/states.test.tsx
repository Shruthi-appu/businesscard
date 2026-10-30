import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { RegisterForm } from "./auth-forms";
import { DeniedState, NetworkState, ValidationState } from "./states";
import { WalletView } from "./wallet-view";

describe("phase 1 screens", () => {
  it("shows a validation error on the register form", () => {
    render(
      <RegisterForm
        pending={false}
        fieldErrors={{ email: "Invalid email" }}
        formError="Validation failed"
        onSubmit={vi.fn()}
      />,
    );
    expect(screen.getByText("Validation failed")).toBeInTheDocument();
    expect(screen.getByText("Invalid email")).toBeInTheDocument();
  });

  it("shows the empty wallet after sign-in", () => {
    render(<WalletView state="empty" displayName="Ada Lovelace" />);
    expect(screen.getByRole("status")).toHaveTextContent("Signed in as Ada Lovelace");
    expect(screen.getByRole("heading", { name: "No cards yet" })).toBeInTheDocument();
  });

  it("shows loading, permission denied, and network failure", async () => {
    const { rerender } = render(<WalletView state="loading" />);
    expect(screen.getByText("Loading your wallet…")).toBeInTheDocument();

    rerender(<WalletView state="denied" />);
    expect(screen.getByText("You do not have access to this wallet.")).toBeInTheDocument();

    const onRetry = vi.fn();
    rerender(<NetworkState onRetry={onRetry} />);
    await userEvent.click(screen.getByRole("button", { name: "Retry" }));
    expect(onRetry).toHaveBeenCalledOnce();
  });

  it("renders a permission denied message", () => {
    render(<DeniedState message="You do not have access to admin tools." />);
    expect(screen.getByText("You do not have access to admin tools.")).toBeInTheDocument();
  });

  it("renders a validation message", () => {
    render(<ValidationState message="An account with that email already exists" />);
    expect(screen.getByText("An account with that email already exists")).toBeInTheDocument();
  });
});
