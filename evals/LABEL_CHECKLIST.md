# Label photo checklist

The evals need **at least 50** photos of ingredient labels. This repo has none yet. Put them in `evals/labels/` named `lbl_001.jpg`, `lbl_002.jpg`, and so on. Do not edit or crop them beyond what the camera did.

## How to photograph

- Photograph the **ingredients panel**, as a user would with the app. Not a studio shot.
- One photo per product. Optionally add a second photo of the front of the pack if it has marketing claims.
- Keep the original JPEG. Remove EXIF location data before sharing the repo publicly.
- Do not include faces, receipts, names or addresses in the frame.

## Mix to cover (tick as you go)

| Group | Target count | Done |
|---|---|---|
| Biscuits, cookies, rusks | 5 | [ ] |
| Namkeen, chips, snacks | 5 | [ ] |
| Instant noodles, pasta, soups | 4 | [ ] |
| Packaged beverages, juices, soft drinks | 5 | [ ] |
| Sauces, ketchup, spreads, peanut butter | 5 | [ ] |
| Chocolates, candies, sweets | 4 | [ ] |
| Dairy, flavoured milk, yoghurt, ice cream | 4 | [ ] |
| Bread, bakery, cereals, oats | 4 | [ ] |
| Protein bars, health foods, "sugar free" / "no added sugar" claims | 4 | [ ] |
| Ready-to-eat, frozen, pickles | 3 | [ ] |
| Products with clear E-number / INS additive lists | 5 | [ ] |
| Products with "may contain" allergen statements | 4 | [ ] |
| **Total (groups can overlap; 50 or more distinct photos are needed)** | **52** | |

## Hard cases (at least 15 of the 52 should be one of these)

| Case | Count | Done |
|---|---|---|
| Curved bottle or tin | 3 | [ ] |
| Glare or shiny foil | 3 | [ ] |
| Very small print | 3 | [ ] |
| Dark or coloured background | 2 | [ ] |
| Text in Hindi or another Indian script alongside English | 2 | [ ] |
| Slightly blurred or at an angle | 2 | [ ] |

## Medicine strips (separate, for the medicine lookup)

At least 15 photos of medicine strips or boxes, brand name visible. Prefer brands that are in `assets/medicine_db.json`, and include at least 3 that are **not** in it, so "no match" is tested too.

## After adding photos

Each photo needs a `evals/labels/<id>.json` ground-truth file, and a person reviews every file before any number is reported.
