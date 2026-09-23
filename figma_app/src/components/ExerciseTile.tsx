// Flutter: ListTile — exercise item for library and plan lists

import { useState } from 'react'
import { colors, fontSize, fontWeight, radius } from '../tokens'

interface Props {
  iconChar: string
  name: string
  subtitle: string   // e.g. "胸部 · 杠铃" or "4 组 · 60 kg"
  trailing?: string  // right-side label (e.g. set count or "›")
  onTap?: () => void
  animationDelay?: number // stagger delay in ms
}

export default function ExerciseTile({ iconChar, name, subtitle, trailing, onTap, animationDelay = 0 }: Props) {
  const [pressed, setPressed] = useState(false)   // Flutter: setState
  const [hovered, setHovered] = useState(false)   // Flutter: MouseRegion

  // Flutter: ListTile with leading=icon, title, subtitle, trailing
  return (
    <div
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => { setPressed(false); setHovered(false) }}
      onMouseEnter={() => setHovered(true)}
      onClick={onTap}
      className="screen-tab"  // fade-up entrance per tile
      style={{
        display: 'flex',       // Flutter: Row
        alignItems: 'center',  // crossAxis: center
        gap: 12,
        padding: '10px 12px',
        background: colors.white,
        border: `1px solid ${hovered && onTap ? colors.coralBorder : colors.border}`,
        borderRadius: radius.md,
        cursor: onTap ? 'pointer' : 'default',
        marginBottom: 6,
        animationDelay: `${animationDelay}ms`,
        // Animation: scale 0.98 on press, hover shadow lift
        // Flutter: GestureDetector + AnimatedScale
        transform: pressed && onTap ? 'scale(0.98)' : 'scale(1)',
        boxShadow: hovered && onTap && !pressed
          ? '0 2px 12px rgba(25,52,76,0.10)'
          : '0 0 0 rgba(0,0,0,0)',
        transition: 'transform 100ms ease-out, box-shadow 180ms ease, border-color 150ms ease',
      }}
    >
      {/* Flutter: Container (icon box) */}
      <div style={{
        width: 36,
        height: 36,
        background: colors.mintSurface,
        borderRadius: radius.sm,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        color: colors.mintText,
        fontSize: fontSize.sm,
        fontWeight: fontWeight.heavy,
        flexShrink: 0,
      }}>
        {iconChar}
      </div>

      {/* Flutter: Column (Expanded) */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: fontSize.base,
          fontWeight: fontWeight.semibold,
          color: colors.text,
          lineHeight: 1.3,
          overflow: 'hidden',
          textOverflow: 'ellipsis',
          whiteSpace: 'nowrap',
        }}>
          {name}
        </div>
        {/* Spacer: 2px → SizedBox(height: 2) */}
        <div style={{ height: 2 }} />
        <div style={{
          fontSize: fontSize.xxs,
          color: colors.textMuted,
        }}>
          {subtitle}
        </div>
      </div>

      {/* Flutter: Text (trailing) */}
      {trailing && (
        <span style={{
          fontSize: fontSize.xs,
          color: colors.textMuted,
          fontWeight: fontWeight.medium,
          flexShrink: 0,
        }}>
          {trailing}
        </span>
      )}
    </div>
  )
}
