import { beforeUserCreated, beforeUserSignedIn } from "firebase-functions/v2/identity";

/**
 * Automatically injects the Supabase PostgreSQL role claim upon account creation.
 * Guarantees zero-trust identity mapping between Firebase Auth and Supabase RLS.
 */
export const beforecreated = beforeUserCreated((_event) => {
  return {
    customClaims: {
      role: "authenticated",
    },
  };
});

/**
 * Ensures the role claim is always present on token refresh and sign-in.
 */
export const beforesignedin = beforeUserSignedIn((_event) => {
  return {
    customClaims: {
      role: "authenticated",
    },
  };
});
