import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

import { AccountActions } from "./account-actions";

describe("account actions", () => {
  it("asks for confirmation before scheduling deletion", async () => {
    const onDeleted = vi.fn();
    render(<AccountActions token="token" onDeleted={onDeleted} />);
    await userEvent.click(screen.getByRole("button", { name: "Delete account" }));
    expect(screen.getByRole("alert")).toHaveTextContent(
      "Confirm that you want to delete this account.",
    );
    expect(onDeleted).not.toHaveBeenCalled();
  });
});
