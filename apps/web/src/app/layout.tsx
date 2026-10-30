import type { Metadata } from "next";
import type { ReactNode } from "react";

import { SiteHeader } from "@/components/site-header";
import { AuthProvider } from "@/lib/auth-context";

import "./globals.css";

export const metadata: Metadata = {
  title: "Softxu",
  description: "Business card wallet for Softxu Technologies",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <AuthProvider>
          <div className="shell">
            <SiteHeader />
            <main>{children}</main>
          </div>
        </AuthProvider>
      </body>
    </html>
  );
}
