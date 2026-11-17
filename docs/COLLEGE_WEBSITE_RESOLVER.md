# College Website Resolver

Admin-only college-level website enrichment. Course family is ignored.

Flow: seed existing reference mappings -> verify candidate URL -> Gemini + Google Search only for unresolved selections -> verify again -> permanently store URL, source, status and timestamps.

Set `GEMINI_API_KEY` only on the admin backend. Optional `GEMINI_RESOLVER_MODEL` defaults to `gemini-2.5-flash`. A resolver request is capped at 25 colleges.

## Local Docker setup

The local Compose override loads `.env.docker-local` into the backend container. The resolver worker is started as a child process of that backend, so it inherits the same environment variables.

1. If `.env.docker-local` does not exist, copy `.env.docker-local.example` to `.env.docker-local`.
2. Set `GEMINI_API_KEY` in `.env.docker-local` to a newly generated Gemini API key. Do not put the key in frontend files, source code, GitHub, or screenshots.
3. Recreate the backend so Docker injects the updated environment:

   ```powershell
   docker compose --env-file .env.docker-local -f compose.yaml -f compose.local.yaml up -d --build --force-recreate backend
   ```

4. Check that the backend is running, then retry Website Resolver from the admin page. The key is read server-side by `backend.admin.resolver`; it is never sent to the browser.

If the key was exposed, revoke it in Google AI Studio and use a replacement. The example file contains only a placeholder; the real `.env.docker-local` must remain untracked.
