# Spider Turret Asset List

## Recommended Resolution Guidelines
- **Base Resolution**: Use 2x the in-game pixel dimensions for crisp rendering
- **Format**: PNG with transparency
- **Power of 2**: Recommended for texture efficiency (though not required)
- **Padding**: Add 10-20% padding around sprites for rotation/transformation

## Asset List

### 1. Main Body (Cephalothorax)
- **Dimensions**: 128x128px (recommended)
  - Base size: 60px diameter (30px radius)
  - Inner circle: 42px diameter (21px radius)
  - With padding: 128x128px provides room for rotation
- **File**: `assets/spider/body.png`
- **Notes**: 
  - Should be circular
  - Needs to support rotation
  - Has a darker inner circle (0.7x radius)

### 2. Abdomen
- **Dimensions**: 84x64px (recommended)
  - Base size: 42px width × 32px height (ellipse)
  - Can scale down to ~25px × 19px (when leaning)
  - With padding: 84x64px
- **File**: `assets/spider/abdomen.png`
- **Notes**:
  - Elliptical/oval shape
  - Positioned 38px behind body center
  - Needs to support scaling (0.6x to 1.0x)

### 3. Barrels (Upper & Lower)
- **Dimensions**: 70x16px each (recommended)
  - Base size: 35px length × 8px height
  - Can shorten to 10px length (when leaning)
  - With padding: 70x16px
- **Files**: 
  - `assets/spider/barrel_upper.png`
  - `assets/spider/barrel_lower.png`
- **Notes**:
  - Two identical barrels (one above, one below)
  - Positioned 10px forward from body center
  - Vertical positions: -12px and +4px
  - Red color (0.7, 0.2, 0.2)

### 4. Legs (8 total - 4 per side)
- **Dimensions**: 140x140px per leg segment (recommended)
  - Upper segment (L1): 45-65px length
  - Lower segment (L2): 50-70px length
  - Line width: 4px
  - With padding: 140x140px allows for full rotation
- **Files**:
  - `assets/spider/leg_upper.png` (upper segment)
  - `assets/spider/leg_lower.png` (lower segment)
  - `assets/spider/leg_knee.png` (4px radius joint)
  - `assets/spider/leg_foot.png` (5px radius foot)
- **Notes**:
  - 8 legs total (4 left, 4 right)
  - Legs have different lengths:
    - Long legs: L1=65px, L2=70px
    - Short legs: L1=45px, L2=50px
  - Legs are drawn as lines with joints
  - Consider creating separate sprites for each leg type if they differ visually

### 5. Charging Glow (Abdomen)
- **Dimensions**: 110x84px (recommended)
  - Base: 42px × 32px abdomen
  - Glow extends 30% beyond (1.3x scale)
  - Maximum glow: ~55px × 42px
  - With padding: 110x84px
- **Files**:
  - `assets/spider/abdomen_glow_red.png`
  - `assets/spider/abdomen_glow_blue.png`
- **Notes**:
  - Pulsing glow effect
  - Red glow for red charge
  - Blue glow for blue charge
  - Uses additive blending
  - Multiple layers for smooth effect

### 6. Web Platform (Optional - currently procedural)
- **Dimensions**: 640x640px (recommended)
  - Base size: 320px diameter (160px radius, doubled)
  - With padding: 640x640px
- **File**: `assets/spider/web_platform.png`
- **Notes**:
  - Currently drawn procedurally
  - Could be replaced with sprite for consistency
  - Includes radial lines, spiral pattern, and border

## Summary Table

| Asset | Dimensions | Base Size | Notes |
|-------|-----------|-----------|-------|
| Body | 128×128px | 60px diameter | Circular, rotatable |
| Abdomen | 84×64px | 42×32px ellipse | Scales 0.6x-1.0x |
| Barrel (each) | 70×16px | 35×8px | Two barrels, can shorten |
| Leg Upper | 140×140px | 45-65px | 8 legs, different lengths |
| Leg Lower | 140×140px | 50-70px | 8 legs, different lengths |
| Knee Joint | 16×16px | 4px radius | 8 joints |
| Foot | 20×20px | 5px radius | 8 feet |
| Abdomen Glow Red | 110×84px | ~55×42px | Pulsing effect |
| Abdomen Glow Blue | 110×84px | ~55×42px | Pulsing effect |
| Web Platform | 640×640px | 320px diameter | Optional replacement |

## Implementation Notes

1. **Coordinate System**: 
   - Body center is at (0, 0) in sprite space
   - Abdomen offset: -38px (behind body)
   - Barrels: +10px forward, -12px and +4px vertically

2. **Transformations**:
   - Body rotates around center
   - Abdomen scales with lean (0.6x to 1.0x)
   - Barrels shorten with lean (35px to 10px)
   - Legs use IK (inverse kinematics) for positioning

3. **Color Scheme**:
   - Body: Dark gray/blue (0.3, 0.3, 0.4)
   - Inner body: Lighter (0.4, 0.4, 0.5)
   - Abdomen: Darker gray/blue (0.25, 0.25, 0.35)
   - Barrels: Red (0.7, 0.2, 0.2)
   - Legs: Gray (0.4 base, 0.55 when stepping)

4. **Animation Requirements**:
   - Body can rotate 360°
   - Abdomen can scale dynamically
   - Barrels can recoil (12px backward)
   - Legs animate with IK stepping
   - Charging glow pulses

## Single Canvas Size for Complete Spider

If you want to paint the entire spider in one document, use this layout:

### Recommended Canvas Size: **2048×2048px** (at 2x resolution)

**Breakdown:**
- **Body center**: Place at (1024, 1024) - center of canvas
- **Maximum horizontal extent** (at 2x): 
  - Left: -280px (legs at 140px × 2) from center = 744px from left edge
  - Right: +280px (legs) from center = 1304px from left edge
  - Total width needed: ~560px at 1x, ~1120px at 2x
- **Maximum vertical extent** (at 2x):
  - Top: -280px (legs) from center = 744px from top edge
  - Bottom: +280px (legs) from center = 1304px from top edge
  - Total height needed: ~560px at 1x, ~1120px at 2x
- **With padding**: 2048×2048px provides comfortable working space and room for leg animation

### Layout Guide (at 2x resolution, body center at 1024, 1024):

```
Canvas: 2048×2048px
Body center: (1024, 1024)

Parts relative to body center (all measurements at 2x):
- Body: 120px diameter circle (60px × 2) at (1024, 1024)
- Abdomen: 84×64px ellipse at (1024-76, 1024) [38px offset × 2]
- Barrels: 70×16px rectangles at (1024+20, 1024-24) and (1024+20, 1024+8)
- Legs: Extend up to 280px from center in all directions
  - Longest leg reach: 140px × 2 = 280px from center
  - Leg angles: -157.5°, -122.5°, -70.5°, -18.5°, 18.5°, 70.5°, 124.5°, 157.5°
  - Leg segments: Upper 90-130px, Lower 100-140px (at 2x)
```

### Alternative Sizes:

**Option 1: 1024×1024px** (at 2x resolution) - *Tighter fit*
- Body center at (512, 512)
- Legs may extend close to edges
- Good if you want a more compact layout
- May need to crop leg tips slightly

**Option 2: 512×512px** (at 1x resolution) - *Pixel art style*
- Smaller canvas, tighter fit
- Body center at (256, 256)
- All parts at 1x dimensions
- Good for pixel art style
- Legs will be closer to edges

**Option 3: 2048×2048px** (at 2x resolution) - *RECOMMENDED*
- Most comfortable working space
- Body center at (1024, 1024)
- Plenty of room for all parts and leg animation
- Better for detailed artwork
- Can export individual parts at 2x for crisp rendering

## Recommended Workflow

1. Create sprites at 2x resolution for crisp rendering
2. Export with transparency
3. Consider creating sprite sheets for animation frames if needed
4. Test with current procedural drawing to ensure dimensions match
5. Replace procedural drawing with sprite drawing incrementally

