// Runnable self-check for route ordering.
// No framework - run with: npx ts-node src/routes/app-routing.test.ts
import assert from "node:assert/strict";

type RouteLayer = {
  route?: {
    path: string;
    methods: Record<string, boolean>;
  };
  name: string;
};

type RouterLayer = {
  handle: {
    stack?: RouteLayer[];
  };
  match(path: string): boolean;
  name: string;
};

type AppWithRouter = {
  router: {
    stack: RouterLayer[];
  };
};

function routerHasRoute(layer: RouterLayer, method: string, path: string): boolean {
  return layer.handle.stack?.some((routeLayer) => {
    return routeLayer.route?.path === path && routeLayer.route.methods[method] === true;
  }) ?? false;
}

function findRouterIndex(app: AppWithRouter, requestPath: string, routePath: string, method: string): number {
  return app.router.stack.findIndex((layer) => {
    return layer.name === "router" && layer.match(requestPath) && routerHasRoute(layer, method, routePath);
  });
}

async function main(): Promise<void> {
  process.env.DATABASE_URL = "postgres://user:password@localhost:5432/doselatch_route_test";
  const { default: rawApp } = await import("../app");
  const app = rawApp as unknown as AppWithRouter;

  const deviceRouterIndex = findRouterIndex(app, "/devices/register", "/register", "post");
  const userRouterIndex = findRouterIndex(app, "/devices/register", "/me", "get");

  assert.notEqual(deviceRouterIndex, -1);
  assert.notEqual(userRouterIndex, -1);
  assert.ok(deviceRouterIndex < userRouterIndex);

  console.log("app-routing self-check passed");
}

main().catch((error: unknown) => {
  console.error(error);
  process.exit(1);
});
