"use client";

import { useState } from "react";

import { ApiError, deleteAccount, downloadExport, exportAccount } from "@/lib/api";

export function AccountActions({ token, onDeleted }: { token: string; onDeleted: () => void }) {
  const [confirm, setConfirm] = useState(false);
  const [pending, setPending] = useState<"export" | "delete" | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [problem, setProblem] = useState(false);

  async function onExport() {
    setPending("export");
    setMessage(null);
    try {
      const created = await exportAccount(token);
      const blob = await downloadExport(token, created.id);
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = "softxu-export.json";
      document.body.append(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
      setProblem(false);
      setMessage("Your export downloaded.");
    } catch (error) {
      setProblem(true);
      setMessage(error instanceof ApiError ? error.problem.title : "Could not export your data");
    } finally {
      setPending(null);
    }
  }

  async function onDelete() {
    if (!confirm) {
      setProblem(true);
      setMessage("Confirm that you want to delete this account.");
      return;
    }
    setPending("delete");
    setMessage(null);
    try {
      await deleteAccount(token);
      setProblem(false);
      setMessage("This account is scheduled for deletion.");
      onDeleted();
    } catch (error) {
      setProblem(true);
      setMessage(error instanceof ApiError ? error.problem.title : "Could not delete this account");
    } finally {
      setPending(null);
    }
  }

  return (
    <section>
      <h2>Account</h2>
      <div className="row">
        <button type="button" onClick={() => void onExport()} disabled={pending !== null}>
          Export my data
        </button>
      </div>
      <label className="choice">
        <input
          type="checkbox"
          name="confirmDelete"
          checked={confirm}
          onChange={(event) => setConfirm(event.target.checked)}
        />
        I understand this schedules deletion and signs me out.
      </label>
      <div className="row">
        <button
          type="button"
          className="secondary"
          onClick={() => void onDelete()}
          disabled={pending !== null}
        >
          Delete account
        </button>
      </div>
      {message ? <p role={problem ? "alert" : "status"}>{message}</p> : null}
    </section>
  );
}
