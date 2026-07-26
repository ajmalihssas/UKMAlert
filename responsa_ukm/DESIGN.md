# Design System Documentation: Emergency Response & Safety

## 1. Overview & Creative North Star
**Creative North Star: "The Vigilant Guardian"**

The objective of this design system is to move beyond the clunky, utilitarian aesthetic of traditional emergency software. We are creating a "Vigilant Guardian"—an interface that is hyper-legible and urgent, yet carries the sophisticated, editorial weight of a premium safety service. 

By utilizing intentional asymmetry and high-contrast typography, we break away from the "template" look. This system prioritizes speed of thought through tonal depth rather than structural noise. We are moving away from the "grid of boxes" toward a fluid, layered experience that feels as much like a high-end news editorial as it does a life-saving tool.

---

## 2. Colors
Our palette takes the heritage colors of Universiti Kebangsaan Malaysia (UKM) and evolves them into a high-performance functional system.

### Color Roles
- **Primary (`#9e0000`)**: Reserved for high-urgency actions (SOS, Active Alerts). Use `primary_container` for secondary emphasis within an emergency context.
- **Secondary (`#3a5f94`)**: Represents stability and authority. Used for navigation, map interfaces, and professional communication.
- **Tertiary (`#745b00`)**: Used for cautionary states, status tracking, and "Member Safe" confirmations.
- **Neutral Surface Palette**: A range of greys from `surface_container_lowest` to `surface_dim` provides the canvas for our "No-Line" philosophy.

### Design Principles for Color
- **The "No-Line" Rule**: You are strictly prohibited from using 1px solid borders to section off content. Definition must be achieved through background color shifts. For example, a `surface_container_low` card sits on a `surface` background.
- **Surface Hierarchy & Nesting**: Treat the UI as a series of physical layers. A notification might live on `surface_container_highest`, nested within a sidebar of `surface_container`, sitting atop a `surface` map.
- **The "Glass & Gradient" Rule**: To avoid a flat, "free-tier" app feel, use Glassmorphism for floating UI elements (e.g., a floating bottom bar). Use a `surface` color at 80% opacity with a `20px` backdrop blur. 
- **Signature Textures**: CTAs should utilize a subtle linear gradient from `primary` to `primary_container` (top-to-bottom) to give the button a "pressed" physical presence that flat red cannot achieve.

---

## 3. Typography
The typography scale is designed for instant recognition under stress.

- **Display (Manrope)**: High-end, geometric, and authoritative. Used for critical status headers (e.g., "EMERGENCY ACTIVE").
- **Headline (Manrope)**: Used for section headings to provide an editorial, organized feel.
- **Body & Label (Inter)**: We use Inter for all functional data because of its tall x-height and exceptional legibility at small sizes.

**Editorial Hierarchy**: 
Always pair a `display-sm` headline with a `label-md` uppercase sub-header. The contrast in scale creates a "designed" look that guides the eye to the most important information first.

---

## 4. Elevation & Depth
In this system, depth is a functional tool, not a decoration.

- **The Layering Principle**: Avoid shadows where background shifts can do the work. Stack `surface_container` tiers to create natural lift.
- **Ambient Shadows**: When an element must float (like an SOS button), use a "Long Shadow": `0px 12px 32px rgba(26, 28, 30, 0.08)`. The shadow must be tinted with the `on_surface` color to feel natural.
- **The "Ghost Border" Fallback**: If an element lacks contrast against its background, use a 1px border using `outline_variant` at **15% opacity**. It should be felt, not seen.
- **Glassmorphism**: Use for overlays to maintain the user's "mental map" of the screen underneath. This reduces the feeling of being "lost" in sub-menus during an emergency.

---

## 5. Components

### Buttons
- **Primary (Urgent)**: Gradient fill (`primary` to `primary_container`), `xl` roundedness, `body-lg` bold text.
- **Secondary (Action)**: `secondary_container` background with `on_secondary_container` text. No border.
- **Tertiary (Ghost)**: Transparent background, `on_surface` text, no border.

### Cards & Lists
- **The "No-Divider" Rule**: Forbid the use of horizontal lines between list items. Use `1.5rem` (spacing scale `6`) of vertical white space or a subtle shift to `surface_container_low` for every other item (zebra striping) to separate content.
- **Emergency Cards**: Use a `surface_container_lowest` base with a 4px left-accent bar in `primary` red to denote urgency.

### Input Fields
- **Sophisticated Inputs**: Use a `surface_container_high` fill with a `none` border. On focus, transition the background to `surface_container_highest` and add a `2px` "Ghost Border" in the `primary` color.

### Critical Components (Specific to UKMAlert)
- **The Pulse Indicator**: A tertiary-colored (Gold) glowing ring around user avatars to indicate "Live Tracking" is active.
- **Status Chips**: Use `xl` roundedness (pill shape). `error_container` for "Danger," `tertiary_fixed` for "Caution," and `secondary_fixed` for "Safe."

---

## 6. Do’s and Don’ts

### Do
- **Do** use `surface_bright` in Dark Mode to highlight critical alerts; don't just use pure black.
- **Do** use the Spacing Scale religiously. Consistent gaps of `1rem` or `1.5rem` create the "minimalist" feel more than the colors do.
- **Do** use `manrope` for numbers. Its geometric nature makes coordinates and phone numbers easier to read at a glance.

### Don’t
- **Don't** use 100% opaque black shadows. They look "cheap" and muddy the professional aesthetic.
- **Don't** use "Alert" red for everything. If everything is red, nothing is urgent. Use `primary` only for the most critical life-safety functions.
- **Don't** use icons without labels for primary navigation. In an emergency, cognitive load is high; don't make the user guess.

---

## 7. Interaction Patterns
- **Haptic Feedback**: Every `primary` action must be accompanied by a heavy haptic tap.
- **Micro-animations**: Use a "Spring" transition (Damping 0.8, Stiffness 100) for all container expansions. Avoid linear "sliding" animations which feel like a standard OS. Elements should feel like they have physical weight.