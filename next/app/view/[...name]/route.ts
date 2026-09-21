import { NextRequest, NextResponse } from "next/server";
import { API_BASE } from "@/lib/config";

export function GET(request: NextRequest) {
  const rawPath = new URL(request.url).pathname;
  const key = rawPath.replace(/^\/view\//, "");
  if (!key) return new NextResponse(null, { status: 404 });
  return NextResponse.redirect(`${API_BASE}/api/view/${key}`, 302);
}