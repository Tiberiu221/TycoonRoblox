export const meta = {
  name: 'verify-work',
  description: 'Independent check of a finished piece of Driftycoon work: logic, look and project rules, each finding challenged by a skeptic',
  whenToUse: 'After every finished piece of work, before commit (args.base = HEAD) or on a pushed range (args.base = older commit).',
  phases: [
    { title: 'Review', detail: 'three reviewers: game logic, look, project rules' },
    { title: 'Challenge', detail: 'a skeptic tries to refute every finding' },
  ],
}

// [owner, 2026-09-24] verificatorii (logica, aspect, reguli, scepticii) ruleaza pe Opus 5.5, nu pe Sonnet.
// args: { what: "ce s-a lucrat, pe scurt", base: "HEAD" (lucru necomis) sau un commit mai vechi (interval deja comis) }
const ROOT = '/Users/tiberiubojan/Desktop/Driftwood'
const what = (args && args.what) || 'the latest change'
const base = (args && args.base) || 'HEAD'

const COMMON = `Project: Driftycoon, a 2D Roblox river tycoon in ${ROOT} (you already have its CLAUDE.md).
The work to check: ${what}
See it with \`git -C ${ROOT} diff ${base}\` (plus \`git -C ${ROOT} status --short\` for new files; read new files whole).
Read the surrounding code too, not only the diff: a change is wrong if it breaks a caller or a reader elsewhere.
The owner cares most about the LOGIC and the LOOK of the game.

Hard rules for you: READ-ONLY on the repo (no edits, no git commands that change anything). Never run scripts/probe.py,
probe_server.py, upload_assets.py, publish_staging.py, create_monetization.py, ci_publish.sh; never read ~/.driftwood_* files.
You may run the gate commands from CLAUDE.md, the simulator, and scripts/art/preview_*.py (PNGs go to the session scratchpad;
open them with Read and look at them).
Every finding needs file:line evidence and what the PLAYER would experience (Romanian, as steps in the game). No style nits.`

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          title: { type: 'string' },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          player_sees: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['id', 'title', 'severity', 'player_sees', 'evidence', 'fix'],
      },
    },
    checked_ok: { type: 'array', items: { type: 'string' } },
  },
  required: ['findings', 'checked_ok'],
}

const VERDICTS = {
  type: 'object',
  properties: {
    verdicts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          id: { type: 'string' },
          verdict: { type: 'string', enum: ['confirmed', 'refuted', 'uncertain'] },
          severity: { type: 'string', enum: ['high', 'medium', 'low'] },
          reason: { type: 'string' },
          fix: { type: 'string' },
        },
        required: ['id', 'verdict', 'severity', 'reason', 'fix'],
      },
    },
  },
  required: ['verdicts'],
}

const LENSES = [
  {
    key: 'logic',
    prompt: `LENS: game logic. Numbers (prices only from scripts/economy/sim_tycoon.py; Era 1 and the Mill unchanged bit for bit),
the flow of goods, server state and validation, quests and the guide, what the text claims versus what really happens (text never
lies [D40], nothing happens silently [D43], no purchase lowers income, a zero-gain purchase says why). Trace the changed behavior
end to end as a player would trigger it.`,
  },
  {
    key: 'look',
    prompt: `LENS: the look. Placement and overlaps on the map (TycoonConfig geometry, render scripts/art/preview_works_map.py or
preview_mill_map.py if the map changed), sprites wired with the right size and a real id in Assets.luau, depth/ZIndex, text that can
overflow its box (pixel font 0.56 em per letter; changing text through Theme.fitSize / Theme.textHeight), kid-friendly English [D63],
consistency with how the rest of the village looks.`,
  },
  {
    key: 'rules',
    prompt: `LENS: project rules and traps from CLAUDE.md: --!strict and task.* only; pure modules in Shared/Modules take \`now\`;
remotes are RemoteEvents with type, math.isfinite, ownership and rate-limit checks; fields sent by the server copied explicitly on the
client and every reader updated when a field changes; BindableEvent copies tables; stylua paren trap; selene warnings fail CI;
Romanian comments / English in-game text; a new profile field comes with a migration and tests; tests exist for new pure logic.`,
  },
]

phase('Review')
const results = await pipeline(
  LENSES,
  (lens) => agent(`${COMMON}\n\n${lens.prompt}\n\nReturn the real findings (zero is fine) and what you checked and found ok.`,
    { label: `review:${lens.key}`, phase: 'Review', schema: FINDINGS, model: 'opus' }),
  (found, lens) => {
    // un recenzent cazut NU e o lentila curata: se raporteaza ca neverificata, ca lucrul sa nu treaca de poarta in tacere
    if (!found) return { lens: lens.key, failed: true, findings: [], checked_ok: [] }
    if (!found.findings.length) return { lens: lens.key, findings: [], checked_ok: found.checked_ok }
    return agent(`${COMMON}\n\nYou are a SKEPTIC. Another reviewer (${lens.key}) reported the findings below about this work. For each,
try to REFUTE it by reading the code yourself and rerunning anything it relied on. 'confirmed' only if you reproduced it; 'refuted'
if it does not hold (say what the code really does); 'uncertain' only if it needs a live Studio Play. Give the fix you would make.

FINDINGS:
${JSON.stringify(found.findings, null, 1)}`,
      { label: `challenge:${lens.key}`, phase: 'Challenge', schema: VERDICTS, model: 'opus' })
      .catch(() => null) // un sceptic cazut nu ia cu el constatarile lentilei: raman, marcate „necontestate"
      .then((v) => ({
        lens: lens.key,
        checked_ok: found.checked_ok,
        findings: found.findings.map((f) => ({ ...f, check: ((v && v.verdicts) || []).find((x) => x.id === f.id) || null })),
      }))
  },
)
const all = results.filter(Boolean)
const failedLenses = LENSES.map((l) => l.key).filter((k) => !all.some((r) => r.lens === k && !r.failed))
if (failedLenses.length) log(`lens(es) that did NOT run: ${failedLenses.join(', ')} -- rerun before commit`)
// o constatare fara verdict (scepticul a cazut sau a sarit-o) RAMANE, marcata `unchallenged`: altfel un defect real ar
// fi disparut din raport in tacere
const confirmed = all.flatMap((r) => r.findings
  .filter((f) => !f.check || f.check.verdict !== 'refuted')
  .map((f) => ({ lens: r.lens, unchallenged: !f.check, ...f })))
const unchallenged = confirmed.filter((f) => f.unchallenged).length
log(`${confirmed.length} finding(s) survived the challenge${unchallenged ? ` (${unchallenged} without a verdict)` : ''}`)
return { confirmed, failedLenses, lenses: all }
