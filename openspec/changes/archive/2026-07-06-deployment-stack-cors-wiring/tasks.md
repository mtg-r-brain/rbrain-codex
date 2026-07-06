## 1. Contract (rbrain-codex)

- [ ] 1.1 deployment-stack: MODIFY wiring — gateway gains `CORS_ALLOWED_ORIGINS` (+ browser-origin scenario).
- [ ] 1.2 `openspec validate deployment-stack-cors-wiring --strict` passes.

## 2. Archive

- [ ] 2.1 Push planning commit; archive; push archive commit.

## 3. Downstream

- [ ] 3.1 rbrain-deploy: compose gateway env + `.env.example`; recreate gateway; verify `Access-Control-Allow-Origin` on GET and preflight, then browser check by the user.
- [ ] 3.2 rbrain-gateway: `.env.example` documents `CORS_ALLOWED_ORIGINS` (chore).
