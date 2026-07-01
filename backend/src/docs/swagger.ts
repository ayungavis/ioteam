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
  },
};

export default swaggerDocument;
