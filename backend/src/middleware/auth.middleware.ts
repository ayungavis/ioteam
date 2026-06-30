import { Request, Response, NextFunction } from "express";

// Placeholder: verify session token from Authorization header.
// Replace with real session lookup against the database.
export function authenticate(
  req: Request,
  res: Response,
  next: NextFunction
): void {
  const token = req.headers.authorization?.split(" ")[1];

  if (!token) {
    res.status(401).json({ success: false, error: "Unauthorized" });
    return;
  }

  // TODO: validate token and populate req.userId from session record
  req.userId = ""; // set after session lookup
  next();
}
