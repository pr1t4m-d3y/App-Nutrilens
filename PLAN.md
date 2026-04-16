# NutriLens Execution Plan

## Phase 1: Architecture & Setup
- [ ] Initialize project scaffolding (Flutter 3.27+ with Impeller + Firebase).
- [ ] Implement Secure API Key Vault: Store 4x Google Gemini Keys, 1x OpenAI Key, and 1x OpenRouter/DeepSeek Key as encrypted environment variables.
- [ ] Set up Firebase configuration.
- [ ] Define core design tokens (`theme.dart`) based on Stitch design context.

## Phase 2: Design Token & Asset Extraction
- [x] Fetch project context from Stitch (NutriLensAPP ID: 958594904590699117).
- [ ] Analyze reference screens (including 12783950995075839785) to extract exact colors, typography (Plus Jakarta Sans/iOS style), and border radiuses (24px).
- [ ] Create Liquid Glass navigation bar components.

## Phase 3: Core UI Flow Implementation
- [ ] View 1: Login (Minimal, Google/Phone/User ID)
- [ ] View 2: Home (Horizontal date, Last Scan Hero, Recent Scans)
- [ ] View 3: Scan (Camera interface)
- [ ] View 4: Processing (Animated loaders - liquid droplets).
- [ ] View 5: Progress (Weight, Streak, Calories ring, BMI spring slider)
- [ ] View 6: Profile (Bento-style account/support cards)
- [ ] View 7: Health Profile (Allergies, Chronic conditions, etc. with accordions)
- [ ] View 8: Medicine Reminder (List, toggles, iOS wheel picker)
- [ ] View 9: Results / Insights Screen.

## Phase 4: Functional Logic & Integrations (CRITICAL UPDATES)
- [ ] Implement "Cloud-Start" Parallelism & Dual-Phase Feedback Loop:
  - Network Trigger (Immediate): Fire `http.post` request to the backend Smart Scan instantly once the OCR text is ready. Do not wait for local processing.
  - Local Logic (Parallel): Concurrently execute the Dart-ported `medical_scanner.js` RegEx logic on-device while the cloud request is awaiting a response.
  - UI Priority (Instant Alert) / *Emergency Mode*: If LocalScan finds a match, immediately trigger "Emergency Signal" (pulsing red banner/haptic buzz) and display optimistic results while "Deep Scan in Progress..." is shown.
  - Data Merging: Once Cloud results arrive (via the 4+1+1 fallback), smoothly merge the personalized 'Why' reasoning, Indian Weighted score, and insights into the existing view, transitioning from the 'Emergency' alert to the 'Full Insights' accordion.
- [ ] Smart Scan Payload: Transmit full user metadata (BMI, Goals, Chronic Conditions, Medications) to the backend for hyper-personalized reasoning.
- [ ] Implement "Indian Weighted" Algorithm (FSSAI Compliance):
  - 1-10 scoring system based on descending weight.
  - 3x negative multiplier for Top 3 ingredients, 2x for Middle, 1x for Bottom.
- [ ] Marketing Reality Check: Check Marketing Title vs. Ingredient List. Display "NOTE" badge if front-of-pack claims are misleading.
- [ ] Personalization ("The Health Bridge" Layman Engine):
  - Translate technical data based on Health Profile (e.g., Diabetes -> blood glucose mgmt; Shred -> empty calories/fats).
  - Additive Decoder: Identify INS/E numbers, flag if banned in other regions or linked to specific health issues.
- [ ] Implement Smart Fallback Mechanism (4+1+1 Resilience Strategy):
  - Primary: Google Gemini 3.0 Flash
  - Failover 1: OpenAI (GPT-4o/o1-mini)
  - Failover 2: OpenRouter (DeepSeek V3)
  - Failover 3: Google Gemini 1.5 Flash (the remaining 3 Google keys)

## Phase 5: High-FPS Motion & Polish
- [ ] Implement "Liquid Mercury" Spring Physics for the BMI slider (0.7 damping ratio) ensuring premium iOS feel.
- [ ] Haptic Feedback Integration: Add a light "taptic" buzz when a "Bad Ingredient" is detected or when the BMI slider snaps into a new category.
- [ ] Build the "Bad Ingredient Insight" Accordion in View 9: Smooth vertical fluid expansion when an ingredient is tapped to reveal the personalized "Why" reasoning.
- [ ] Add physics-based spring animations for scroll and slider interactions.
- [ ] Morphing shared-element transitions between Home and Results.
- [ ] Final visual QA matching the "Ethereal Clinical" / "Luminous Health Editorial" aesthetic.
