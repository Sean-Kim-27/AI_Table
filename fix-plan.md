# AI Table Fix Plan

## Branch Strategy

Create a dedicated fix branch before editing code:

```bash
git checkout -b fix/security-and-architecture-hardening
```

If the branch already exists locally, reuse it:

```bash
git checkout fix/security-and-architecture-hardening
```

If the branch already exists on the remote, track it:

```bash
git fetch origin
git checkout -t origin/fix/security-and-architecture-hardening
```

---

## Goals

Focus on the highest-risk issues first:

1. Harden secret storage
2. Remove secret leakage in request URLs
3. Stop storing conversation history in plain UserDefaults
4. Normalize provider prompt handling
5. Reduce duplicate provider/network logic
6. Improve lifecycle/state ownership

---

## Step-by-step Fix Plan

### Step 1 — Create the fix branch
- Ensure the working tree is clean or note the current changes.
- Create `fix/security-and-architecture-hardening` from `main`.
- Push the branch if remote collaboration is needed.

### Step 2 — Harden Gemini request auth
- Move Gemini API key handling out of the URL query string if the API permits.
- If query auth is unavoidable, isolate it and mark it as a special-case path.
- Add a guard against accidental logging of the final URL.

### Step 3 — Strengthen Keychain usage
- Centralize all key reads/writes through one path.
- Add explicit Keychain accessibility settings.
- Consider biometry-gated access for key retrieval.
- Avoid mixing provider keys into a single weakly scoped blob if possible.

### Step 4 — Move chat history out of plain UserDefaults
- Replace direct `UserDefaults` persistence for chat history.
- Use encrypted local storage or an opt-in persistence mode.
- Keep only non-sensitive UI state in `UserDefaults`.

### Step 5 — Normalize system prompt handling
- Keep `system_prompt` separate from user content.
- Encapsulate provider-specific prompt quirks inside provider adapters.
- Remove ad-hoc prompt merging from shared flow paths.

### Step 6 — Reduce provider duplication
- Introduce a shared provider interface or request builder.
- Standardize error mapping, timeout handling, and streaming parsing.
- Keep provider-specific decoding only where necessary.

### Step 7 — Clean up lifecycle/state ownership
- Introduce a clearer window coordinator or controller.
- Make observer registration/removal explicit.
- Reduce reliance on timing hacks where possible.

### Step 8 — Add verification
- Add tests for:
  - stream parsing
  - malformed SSE chunks
  - provider auth failures
  - history persistence behavior
- Verify no secrets appear in logs or debug output.

---

## Suggested Implementation Order

Recommended order for safe execution:

1. Branch creation
2. Gemini auth hardening
3. Keychain hardening
4. Chat history storage fix
5. Prompt handling cleanup
6. Shared provider abstraction
7. Lifecycle cleanup
8. Tests and verification

---

## Commit Plan

Suggested commit sequence:

- `fix: harden Gemini auth path`
- `fix: strengthen keychain storage`
- `fix: move chat history out of UserDefaults`
- `refactor: normalize prompt handling`
- `refactor: reduce provider duplication`
- `fix: clean up window lifecycle`
- `test: add stream and auth coverage`

---

## Notes

- Keep changes small and reviewable.
- Avoid mixing security fixes with UI redesigns.
- Push early if collaboration or remote review is expected.
- Re-check the app after each major step.
