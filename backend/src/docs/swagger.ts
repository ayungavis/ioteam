import { OpenAPIV3 } from "openapi-types";

const successUserResponse: OpenAPIV3.SchemaObject = {
  type: "object",
  properties: {
    success: { type: "boolean", example: true },
    data: {
      type: "object",
      properties: {
        accessToken: { type: "string", example: "eyJhbGciOiJIUzI1NiJ9..." },
        user: {
          type: "object",
          properties: {
            id: { type: "string", format: "uuid" },
            email: {
              type: "string",
              format: "email",
              example: "user@example.com",
            },
            fullName: { type: "string", example: "John Doe" },
            onboardingCompleted: { type: "boolean", example: false },
          },
        },
      },
    },
  },
};

const errorResponse: OpenAPIV3.SchemaObject = {
  type: "object",
  properties: {
    success: { type: "boolean", example: false },
    error: { type: "string", example: "Error message" },
  },
};

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
  },
  paths: {
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
            content: { "application/json": { schema: successUserResponse } },
          },
          "201": {
            description: "New user created",
            content: { "application/json": { schema: successUserResponse } },
          },
          "400": {
            description: "Missing or invalid identity token",
            content: { "application/json": { schema: errorResponse } },
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
            content: { "application/json": { schema: successUserResponse } },
          },
          "201": {
            description: "New dev user created",
            content: { "application/json": { schema: successUserResponse } },
          },
          "400": {
            description: "Missing email",
            content: { "application/json": { schema: errorResponse } },
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
            description: "Missing or invalid token",
            content: { "application/json": { schema: errorResponse } },
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
            content: { "application/json": { schema: errorResponse } },
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
            content: { "application/json": { schema: errorResponse } },
          },
          "401": {
            description: "Unauthorized",
            content: { "application/json": { schema: errorResponse } },
          },
        },
      },
    },
  },
};

export default swaggerDocument;
