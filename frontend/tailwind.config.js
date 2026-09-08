const token = (name) => `rgb(var(--${name}) / <alpha-value>)`;

/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          50: token("brand-50"),
          100: token("brand-100"),
          200: token("brand-200"),
          300: token("brand-300"),
          400: token("brand-400"),
          500: token("brand-500"),
          600: token("brand-600"),
          700: token("brand-700"),
          800: token("brand-800"),
          900: token("brand-900"),
          950: token("brand-950"),
        },
        ink: {
          50: token("ink-50"),
          100: token("ink-100"),
          200: token("ink-200"),
          300: token("ink-300"),
          400: token("ink-400"),
          500: token("ink-500"),
          600: token("ink-600"),
          700: token("ink-700"),
          800: token("ink-800"),
          900: token("ink-900"),
          950: token("ink-950"),
        },
        surface: {
          canvas: token("surface-canvas"),
          base: token("surface-base"),
          raised: token("surface-raised"),
          muted: token("surface-muted"),
          inset: token("surface-inset"),
          inverse: token("surface-inverse"),
          "inverse-raised": token("surface-inverse-raised"),
        },
        border: {
          subtle: token("border-subtle"),
          strong: token("border-strong"),
        },
        status: {
          success: token("state-success"),
          warning: token("state-warning"),
          danger: token("state-danger"),
          info: token("state-info"),
        },
      },
      fontFamily: {
        sans: ["var(--font-primary)", "sans-serif"],
        display: ["var(--font-display)", "sans-serif"],
        reading: ["var(--font-reading)", "sans-serif"],
        latin: ["var(--font-latin)", "sans-serif"],
      },
      fontSize: {
        display: ["clamp(2.75rem, 6vw, 4.75rem)", { lineHeight: "1.02", letterSpacing: "-0.055em", fontWeight: "650" }],
        "page-title": ["clamp(2rem, 4vw, 3rem)", { lineHeight: "1.08", letterSpacing: "-0.04em", fontWeight: "650" }],
        "section-title": ["clamp(1.5rem, 3vw, 2rem)", { lineHeight: "1.18", letterSpacing: "-0.03em", fontWeight: "650" }],
      },
      boxShadow: {
        control: "var(--shadow-control)",
        card: "var(--shadow-card)",
        lift: "var(--shadow-raised)",
        floating: "var(--shadow-floating)",
        glow: "var(--shadow-glow)",
        focus: "var(--shadow-focus)",
        dark: "0 28px 84px -32px rgb(2 12 28 / 0.72)",
      },
      borderRadius: {
        control: "var(--radius-control)",
        card: "var(--radius-card)",
        panel: "var(--radius-panel)",
        pill: "var(--radius-pill)",
        xl: "var(--radius-control)",
        "2xl": "var(--radius-card)",
        "3xl": "var(--radius-panel)",
      },
      transitionDuration: {
        fast: "var(--motion-fast)",
        base: "var(--motion-base)",
        slow: "var(--motion-slow)",
      },
      transitionTimingFunction: {
        standard: "var(--ease-standard)",
        emphasized: "var(--ease-emphasized)",
      },
      backgroundImage: {
        "infra-grid": "linear-gradient(rgb(var(--brand-700) / 0.035) 1px, transparent 1px), linear-gradient(90deg, rgb(var(--brand-700) / 0.035) 1px, transparent 1px)",
        "surface-sheen": "linear-gradient(145deg, rgb(255 255 255 / 0.96), rgb(var(--brand-50) / 0.5))",
      },
    },
  },
  plugins: [],
};
