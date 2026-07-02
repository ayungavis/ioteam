import { OpenAPIV3 } from "openapi-types";

const swaggerDocument: OpenAPIV3.Document = {
  openapi: "3.0.0",
  info: {
    title: "DoseLatch API",
    version: "1.0.0",
    description: "Backend API for the DoseLatch IoT medication tracker",
  },
  servers: [
    { url: "http://localhost:3000", description: "Local development" },
    {
      url: "https://resourceful-generosity-staging.up.railway.app",
      description: "Staging environment",
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: "http",
        scheme: "bearer",
        bearerFormat: "JWT",
      },
    },
    schemas: {
      Error: {
        type: "object",
        properties: {
          success: { type: "boolean", example: false },
          error: { type: "string", example: "Error message" },
        },
      },
      User: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          email: {
            type: "string",
            format: "email",
            example: "user@example.com",
          },
          fullName: { type: "string", example: "John Doe" },
          dateOfBirth: {
            type: "string",
            format: "date",
            example: "1995-08-21",
            nullable: true,
          },
          avatarUrl: {
            type: "string",
            example: "https://example.com/avatar.jpg",
            nullable: true,
          },
          onboardingCompleted: { type: "boolean", example: false },
        },
      },
      AuthResponse: {
        type: "object",
        properties: {
          success: { type: "boolean", example: true },
          data: {
            type: "object",
            properties: {
              accessToken: {
                type: "string",
                example: "eyJhbGciOiJIUzI1NiJ9...",
              },
              user: { $ref: "#/components/schemas/User" },
            },
          },
        },
      },
      FamilyMember: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          role: {
            type: "string",
            enum: ["owner", "admin", "member"],
            example: "member",
          },
          joinedAt: { type: "string", format: "date-time" },
          user: {
            type: "object",
            properties: {
              id: { type: "string", format: "uuid" },
              fullName: { type: "string", example: "John Doe" },
              email: {
                type: "string",
                format: "email",
                example: "user@example.com",
              },
              avatarUrl: { type: "string", nullable: true },
            },
          },
        },
      },
      Family: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          name: { type: "string", example: "The Doe Family" },
          inviteCode: { type: "string", example: "A3X9K2", nullable: true },
          memberCount: { type: "integer", example: 3 },
          role: {
            type: "string",
            enum: ["owner", "admin", "member"],
            example: "owner",
          },
          members: {
            type: "array",
            items: { $ref: "#/components/schemas/FamilyMember" },
          },
        },
      },
      Device: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          familyId: { type: "string", format: "uuid" },
          name: { type: "string", example: "Kitchen Pill Box" },
          hardwareId: { type: "string", example: "ESP32-A1B2C3" },
          connectionType: {
            type: "string",
            enum: ["bluetooth", "matter", "homekit"],
            example: "bluetooth",
          },
          status: {
            type: "string",
            enum: ["active", "disabled", "deleted"],
            example: "active",
          },
          firmwareVersion: { type: "string", example: "1.0.3", nullable: true },
          lastSeenAt: { type: "string", format: "date-time", nullable: true },
        },
      },
      ScheduleInput: {
        type: "object",
        required: ["frequencyType", "scheduleConfig", "timezone", "startAt"],
        description:
          "Schedule definition. scheduleConfig shape depends on frequencyType.",
        properties: {
          frequencyType: {
            type: "string",
            enum: ["daily", "weekly", "hourly"],
            example: "daily",
          },
          scheduleConfig: {
            type: "object",
            description:
              "daily: { timesOfDay: [\"08:00\",\"20:00\"] } | weekly: { weekdays: [1,3,5], timesOfDay: [\"09:00\"] } (0=Sun..6=Sat) | hourly: { intervalHours: 8 }",
            example: { timesOfDay: ["08:00", "20:00"] },
          },
          timezone: {
            type: "string",
            description:
              "IANA timezone the times-of-day are interpreted in. Ignored for hourly (interval) schedules.",
            example: "Asia/Singapore",
          },
          graceBeforeMinutes: { type: "integer", example: 15, default: 0 },
          graceAfterMinutes: { type: "integer", example: 30, default: 30 },
          startAt: { type: "string", format: "date-time" },
          endAt: { type: "string", format: "date-time", nullable: true },
        },
      },
      Schedule: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          frequencyType: {
            type: "string",
            enum: ["daily", "weekly", "hourly"],
          },
          scheduleConfig: { type: "object" },
          timezone: { type: "string", example: "Asia/Singapore" },
          graceBeforeMinutes: { type: "integer", example: 15 },
          graceAfterMinutes: { type: "integer", example: 30 },
          startAt: { type: "string", format: "date-time" },
          endAt: { type: "string", format: "date-time", nullable: true },
          status: { type: "string", enum: ["active", "superseded"] },
        },
      },
      GeneratedDose: {
        type: "object",
        properties: {
          scheduledAt: { type: "string", format: "date-time" },
          windowStartAt: { type: "string", format: "date-time" },
          windowEndAt: { type: "string", format: "date-time" },
          doseAmount: { type: "integer", example: 1 },
        },
      },
      DoseSummary: {
        type: "object",
        properties: {
          totalDoses: { type: "integer", example: 30 },
          firstDoseAt: {
            type: "string",
            format: "date-time",
            nullable: true,
          },
          lastDoseAt: { type: "string", format: "date-time", nullable: true },
          pillsUsed: { type: "integer", example: 30 },
        },
      },
      Medicine: {
        type: "object",
        properties: {
          id: { type: "string", format: "uuid" },
          name: { type: "string", example: "Metformin" },
          status: {
            type: "string",
            enum: ["active", "disabled", "deleted"],
            example: "active",
          },
          totalQuantity: { type: "integer", example: 60 },
          remainingQuantity: { type: "integer", example: 42 },
          pillPerDose: { type: "integer", example: 1 },
          device: {
            type: "object",
            nullable: true,
            properties: {
              id: { type: "string", format: "uuid" },
              name: { type: "string", example: "Kitchen Pill Box" },
              status: { type: "string", example: "active" },
            },
          },
          nextDoseAt: { type: "string", format: "date-time", nullable: true },
        },
      },
    },
  },
  paths: {
    // ─── Authentication ───────────────────────────────────────────────────────
    "/auth/apple": {
      post: {
        tags: ["Authentication"],
        summary: "Sign in with Apple",
        description:
          "Verifies an Apple identity token, creates or retrieves the user, and returns a JWT access token.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["identityToken"],
                properties: {
                  identityToken: {
                    type: "string",
                    description:
                      "JWT identity token from ASAuthorizationAppleIDCredential",
                  },
                  fullName: {
                    type: "string",
                    description:
                      "User full name — only sent by Apple on first sign-in",
                    example: "John Doe",
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Existing user signed in",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
          "201": {
            description: "New user created",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
          "400": {
            description: "Missing or invalid identity token",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/auth/dev-login": {
      post: {
        tags: ["Authentication"],
        summary: "Dev login (non-production only)",
        description:
          "Bypasses Apple verification. Available only when NODE_ENV is not production.",
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["email"],
                properties: {
                  email: {
                    type: "string",
                    format: "email",
                    example: "dev@example.com",
                  },
                  fullName: { type: "string", example: "Dev User" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Existing dev user signed in",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
          "201": {
            description: "New dev user created",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/AuthResponse" },
              },
            },
          },
          "400": {
            description: "Missing email",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/auth/logout": {
      post: {
        tags: ["Authentication"],
        summary: "Logout",
        description:
          "Signals logout. The frontend is responsible for deleting the access token.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Logged out successfully",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { success: { type: "boolean", example: true } },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/auth/sessions": {
      get: {
        tags: ["Authentication"],
        summary: "List active sessions",
        description:
          "Returns all active login sessions for the authenticated user.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": { description: "Session list" },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/auth/sessions/{id}": {
      delete: {
        tags: ["Authentication"],
        summary: "Revoke a session",
        description: "Revokes a specific login session by ID.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": { description: "Session revoked" },
          "404": {
            description: "Session not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    // ─── User ─────────────────────────────────────────────────────────────────
    "/me": {
      get: {
        tags: ["User"],
        summary: "Get current user profile",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "User profile",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: { $ref: "#/components/schemas/User" },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "User not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      patch: {
        tags: ["User"],
        summary: "Update current user profile",
        description:
          "Updates fullName, dateOfBirth, or avatarUrl. Only provided fields are updated.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  fullName: { type: "string", example: "Jane Doe" },
                  dateOfBirth: {
                    type: "string",
                    format: "date",
                    example: "1995-08-21",
                  },
                  avatarUrl: {
                    type: "string",
                    example: "https://example.com/avatar.jpg",
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Updated user profile",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: { $ref: "#/components/schemas/User" },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "User not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      delete: {
        tags: ["User"],
        summary: "Delete account",
        description:
          "Permanently deletes the authenticated user and all associated data.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Account deleted",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { success: { type: "boolean", example: true } },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "User not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/onboarding/complete": {
      post: {
        tags: ["User"],
        summary: "Complete onboarding",
        description:
          "Marks the user's onboarding as completed. Call this after the user finishes the onboarding flow.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Onboarding marked complete",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        id: { type: "string", format: "uuid" },
                        onboardingCompleted: { type: "boolean", example: true },
                      },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "User not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    // ─── Family ───────────────────────────────────────────────────────────────
    "/families": {
      post: {
        tags: ["Family"],
        summary: "Create a family",
        description:
          "Creates a new family and assigns the authenticated user as owner. Generates a 6-character invite code.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name"],
                properties: {
                  name: { type: "string", example: "The Doe Family" },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Family created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        id: { type: "string", format: "uuid" },
                        name: { type: "string", example: "The Doe Family" },
                        inviteCode: { type: "string", example: "A3X9K2" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Missing family name",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/join": {
      post: {
        tags: ["Family"],
        summary: "Join a family",
        description:
          "Joins a family using a 6-character invite code. Case-insensitive.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["inviteCode"],
                properties: {
                  inviteCode: { type: "string", example: "A3X9K2" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Joined family successfully",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        id: { type: "string", format: "uuid" },
                        name: { type: "string", example: "The Doe Family" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Invalid invite code",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "409": {
            description: "Already a member of this family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/current": {
      get: {
        tags: ["Family"],
        summary: "Get current family",
        description:
          "Returns the authenticated user's family with all members and their profiles.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Family detail",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: { $ref: "#/components/schemas/Family" },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "User is not a member of any family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/{id}": {
      patch: {
        tags: ["Family"],
        summary: "Rename family",
        description:
          "Renames the family. Only owner or admin can perform this action.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name"],
                properties: {
                  name: { type: "string", example: "The Doe Family" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Family renamed",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        id: { type: "string", format: "uuid" },
                        name: { type: "string", example: "The Doe Family" },
                      },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Requester is not owner or admin",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Family not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/{id}/invite-code": {
      post: {
        tags: ["Family"],
        summary: "Refresh invite code",
        description:
          "Generates a new 6-character invite code, replacing the previous one. Only owner or admin can perform this action.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "New invite code generated",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        inviteCode: { type: "string", example: "Z7TQ1R" },
                      },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Requester is not owner or admin",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/{id}/members": {
      get: {
        tags: ["Family"],
        summary: "List family members",
        description:
          "Returns all members of the family with their user profiles. Requester must be a member.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "Member list",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "array",
                      items: { $ref: "#/components/schemas/FamilyMember" },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Requester is not a member of this family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/families/{id}/members/{memberId}": {
      delete: {
        tags: ["Family"],
        summary: "Remove a member",
        description:
          "Removes a member from the family. Only owner or admin can perform this. Cannot remove the last owner.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
          {
            name: "memberId",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "Member removed",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { success: { type: "boolean", example: true } },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Forbidden — not owner/admin, or removing last owner",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Member not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    // ─── Device ───────────────────────────────────────────────────────────────
    "/devices": {
      get: {
        tags: ["Device"],
        summary: "List family devices",
        description: "Returns all non-deleted devices for the caller's family.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Device list",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "array",
                      items: { $ref: "#/components/schemas/Device" },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Not a member of any family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/devices/pairing-token": {
      post: {
        tags: ["Device"],
        summary: "Create pairing token",
        description:
          "Issues a short-lived (10 min) JWT scoped to the caller's family, used by the ESP32 during onboarding.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Pairing token issued",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        token: { type: "string", example: "eyJhbGciOiJIUzI1NiJ9..." },
                        expiresInSeconds: { type: "integer", example: 600 },
                      },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Not a member of any family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/devices/register": {
      post: {
        tags: ["Device"],
        summary: "Register a device",
        description:
          "Registers an ESP32 device to the caller's family after provisioning. hardwareId must be globally unique.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["hardwareId", "name"],
                properties: {
                  hardwareId: { type: "string", example: "ESP32-A1B2C3" },
                  name: { type: "string", example: "Kitchen Pill Box" },
                  firmwareVersion: { type: "string", example: "1.0.3" },
                  connectionType: {
                    type: "string",
                    enum: ["bluetooth", "matter", "homekit"],
                    example: "bluetooth",
                  },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Device registered",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: { $ref: "#/components/schemas/Device" },
                  },
                },
              },
            },
          },
          "400": {
            description: "Missing hardwareId or name",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "409": {
            description: "hardwareId already registered",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/devices/{id}": {
      patch: {
        tags: ["Device"],
        summary: "Rename or enable/disable a device",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  name: { type: "string", example: "Bedroom Pill Box" },
                  status: {
                    type: "string",
                    enum: ["active", "disabled"],
                    example: "disabled",
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Device updated",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: { $ref: "#/components/schemas/Device" },
                  },
                },
              },
            },
          },
          "400": {
            description: "Nothing to update, or invalid status",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Device does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Device not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      delete: {
        tags: ["Device"],
        summary: "Delete a device",
        description: "Soft-deletes the device (status set to deleted).",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "Device deleted",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: { success: { type: "boolean", example: true } },
                },
              },
            },
          },
          "403": {
            description: "Device does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Device not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    // ─── Medicine ─────────────────────────────────────────────────────────────
    "/medicines": {
      get: {
        tags: ["Medicine"],
        summary: "List medicines",
        description:
          "Lists the family's medicines with linked device and next upcoming dose time.",
        security: [{ bearerAuth: [] }],
        responses: {
          "200": {
            description: "Medicine list",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "array",
                      items: { $ref: "#/components/schemas/Medicine" },
                    },
                  },
                },
              },
            },
          },
          "401": {
            description: "Unauthorized",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      post: {
        tags: ["Medicine"],
        summary: "Create a medicine",
        description:
          "Creates a medicine with a schedule and materializes its doses in one transaction. deviceId must belong to the caller's family.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["name", "deviceId", "quantity", "schedule"],
                properties: {
                  name: { type: "string", example: "Metformin" },
                  deviceId: { type: "string", format: "uuid" },
                  quantity: { type: "integer", example: 60 },
                  pillPerDose: { type: "integer", example: 1, default: 1 },
                  schedule: { $ref: "#/components/schemas/ScheduleInput" },
                },
              },
            },
          },
        },
        responses: {
          "201": {
            description: "Medicine created",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        medicine: { $ref: "#/components/schemas/Medicine" },
                        schedule: { $ref: "#/components/schemas/Schedule" },
                        doses: {
                          type: "array",
                          items: { $ref: "#/components/schemas/GeneratedDose" },
                        },
                        summary: { $ref: "#/components/schemas/DoseSummary" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Validation error (missing fields, invalid schedule)",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Device does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/medicines/preview-doses": {
      post: {
        tags: ["Medicine"],
        summary: "Preview generated doses",
        description:
          "Runs the dose generator for a proposed quantity and schedule without persisting anything. Used by the review screen.",
        security: [{ bearerAuth: [] }],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["quantity", "schedule"],
                properties: {
                  quantity: { type: "integer", example: 60 },
                  pillPerDose: { type: "integer", example: 1, default: 1 },
                  schedule: { $ref: "#/components/schemas/ScheduleInput" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Generated dose preview",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        doses: {
                          type: "array",
                          items: { $ref: "#/components/schemas/GeneratedDose" },
                        },
                        summary: { $ref: "#/components/schemas/DoseSummary" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Validation error",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/medicines/{id}": {
      get: {
        tags: ["Medicine"],
        summary: "Get medicine detail",
        description:
          "Returns the medicine with linked device, active schedule, dose counts by status, and next dose time.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "Medicine detail",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      allOf: [
                        { $ref: "#/components/schemas/Medicine" },
                        {
                          type: "object",
                          properties: {
                            schedule: {
                              allOf: [{ $ref: "#/components/schemas/Schedule" }],
                              nullable: true,
                            },
                            doseCounts: {
                              type: "object",
                              additionalProperties: { type: "integer" },
                              example: { pending: 28, taken: 12, missed: 2 },
                            },
                          },
                        },
                      ],
                    },
                  },
                },
              },
            },
          },
          "403": {
            description: "Medicine does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Medicine not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      patch: {
        tags: ["Medicine"],
        summary: "Update medicine / adjust quantity",
        description:
          "Updates name, status, or linked device, and/or adjusts quantity by a signed delta. Positive adjustQuantity (refill) appends doses; negative (correction) trims pending future doses from the tail. Does not change the schedule structure — use /reschedule for that.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                properties: {
                  name: { type: "string", example: "Metformin XR" },
                  status: {
                    type: "string",
                    enum: ["active", "disabled"],
                  },
                  deviceId: { type: "string", format: "uuid" },
                  adjustQuantity: {
                    type: "integer",
                    description:
                      "Signed delta. Positive = refill (append doses), negative = correction (trim tail).",
                    example: 30,
                  },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Medicine updated",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        medicine: { $ref: "#/components/schemas/Medicine" },
                        dosesAdded: { type: "integer", example: 30 },
                        dosesRemoved: { type: "integer", example: 0 },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Nothing to update, or invalid field",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "403": {
            description: "Medicine does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Medicine not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
      delete: {
        tags: ["Medicine"],
        summary: "Delete a medicine",
        description:
          "Soft-deletes the medicine, supersedes its active schedule, and drops future pending doses. Historical doses are preserved.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        responses: {
          "200": {
            description: "Medicine deleted",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        dosesRemoved: { type: "integer", example: 28 },
                      },
                    },
                  },
                },
              },
            },
          },
          "403": {
            description: "Medicine does not belong to your family",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Medicine not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/medicines/{id}/reschedule-preview": {
      post: {
        tags: ["Medicine"],
        summary: "Preview a reschedule",
        description:
          "Returns the future doses a schedule change would produce, using remaining quantity as the pill budget. Writes nothing.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["schedule"],
                properties: {
                  schedule: { $ref: "#/components/schemas/ScheduleInput" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Future dose preview",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        doses: {
                          type: "array",
                          items: { $ref: "#/components/schemas/GeneratedDose" },
                        },
                        summary: { $ref: "#/components/schemas/DoseSummary" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Validation error",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Medicine not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },

    "/medicines/{id}/reschedule": {
      post: {
        tags: ["Medicine"],
        summary: "Apply a reschedule",
        description:
          "Supersedes the active schedule, deletes future pending doses, and regenerates future doses under a new schedule. Historical doses are preserved.",
        security: [{ bearerAuth: [] }],
        parameters: [
          {
            name: "id",
            in: "path",
            required: true,
            schema: { type: "string", format: "uuid" },
          },
        ],
        requestBody: {
          required: true,
          content: {
            "application/json": {
              schema: {
                type: "object",
                required: ["schedule"],
                properties: {
                  schedule: { $ref: "#/components/schemas/ScheduleInput" },
                },
              },
            },
          },
        },
        responses: {
          "200": {
            description: "Rescheduled",
            content: {
              "application/json": {
                schema: {
                  type: "object",
                  properties: {
                    success: { type: "boolean", example: true },
                    data: {
                      type: "object",
                      properties: {
                        schedule: { $ref: "#/components/schemas/Schedule" },
                        doses: {
                          type: "array",
                          items: { $ref: "#/components/schemas/GeneratedDose" },
                        },
                        dosesRemoved: { type: "integer", example: 15 },
                        dosesCreated: { type: "integer", example: 20 },
                        summary: { $ref: "#/components/schemas/DoseSummary" },
                      },
                    },
                  },
                },
              },
            },
          },
          "400": {
            description: "Validation error",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
          "404": {
            description: "Medicine not found",
            content: {
              "application/json": {
                schema: { $ref: "#/components/schemas/Error" },
              },
            },
          },
        },
      },
    },
  },
};

export default swaggerDocument;
